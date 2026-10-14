"""
Turn a TLC batch log into a reviewable candidate-gap report (Markdown).

run_tlc_batch.py produces machine-readable JSONL; this renders the part a human
actually has to read. For every deadlocked unit it prints the DEADLOCK STATE -
the last state of TLC's trace, the one with no enabled transition out of it -
because that state, paired with the unit's spec text, is exactly what a B.4.3
manual review needs: "the spec says how to get here and does not say what
happens next."

Units that did not deadlock are summarised but not detailed; a module that
could not be checked at all (unbounded quantifier, TLC error, timeout) is
listed separately, since "no gap found" and "nothing was looked at" must never
be conflated in the thesis numbers.

    python make_gap_report.py --models-dir models/generated/ch45 \
        --out models/generated/ch45/gap_report.md
"""
import argparse
import collections
import json
import re
from pathlib import Path

from src.validation.run_tlc import extract_trace, trace_length
from src.validation import gap_detector as gd

_CHECKED = {"unhandled_input", "invariant_violated", "no_error"}

# Below this, a "no_error" verdict says nothing useful: a model that barely
# moves cannot deadlock, so "no gap found" would be an artifact of the model
# being empty rather than of the spec being complete. core_4.18.2 explored
# exactly 1 state at depth 1 - it has no behaviour at all.
_TRIVIAL_STATES = 20
_TRIVIAL_DEPTH = 3

_NOT_CHECKED_REASON = {
    "unbounded_quantifier": "model quantifies over an infinite set - needs explicit bounds",
    "number_too_large": "model uses a real-world-sized numeric literal - needs a small abstract bound",
    "incomplete_next_state": "an action leaves a variable neither assigned nor UNCHANGED",
    "no_shape": "model omits the mandatory pendingInput/NoInput shape, so no gap could be detected",
    "timeout": "state space too large to finish within the time budget",
    "runtime_error": "TLC evaluation error inside the model",
    "tlc_error": "TLC rejected the module or config",
    "config_error": "no Spec and no Init/Next - nothing to run",
    "harness_error": "the harness itself failed on this unit",
}


# A real TLC state header: "State 7: <ActionName line 12, col 5 ...>".
# Matching the bare word "State" instead split variable names such as
# commChannelState, slicing the trace in the middle of a conjunct.
_STATE_HEADER_RE = re.compile(r"^State \d+: .*$", re.MULTILINE)


def run_trace(run: dict) -> str:
    """The best available trace for a run.

    Re-extracts from the raw output tail when possible and falls back to the
    trace stored at check time, so a fix to the extractor takes effect on an
    existing log without paying for a full re-run - the TLC runs are by far the
    expensive part of the pipeline.
    """
    stored = run.get("trace", "")
    # Prefer re-extracting from raw_tail: the stored trace was truncated at a
    # character budget when the check ran, which can lop the value off the last
    # conjunct - and for a deadlock the LAST state is the whole point. raw_tail
    # keeps the end of TLC's output, so that state is always intact there.
    raw = run.get("raw_tail")
    if raw:
        # No character budget here: the report prints only the LAST state
        # block, so truncating the trace first would cut exactly the state we
        # care about - and would undercount the steps taken to reach it.
        fresh = extract_trace(raw, max_chars=len(raw))
        if _STATE_HEADER_RE.search(fresh):
            return fresh
    return stored


def steps_to_deadlock(r: dict) -> int:
    """Longest deadlock trace across this unit's configs (0 if none)."""
    return max((trace_length(run_trace(run)) for run in r.get("runs", [])
                if run["outcome"] == "unhandled_input"), default=0)


def deadlock_state(run: dict) -> str:
    """The last state block of the trace - the one TLC got stuck in.

    Re-extracts from the stored raw TLC output when it is available, so a fix
    to the trace extractor takes effect on existing logs without paying for a
    full re-run - the TLC runs are by far the expensive part of the pipeline.
    """
    trace = run_trace(run)
    if not trace:
        return ""
    headers = list(_STATE_HEADER_RE.finditer(trace))
    if not headers:
        return trace.strip()
    last = trace[headers[-1].start():]
    return "\n".join(l for l in last.splitlines() if l.strip()).strip()


# Words a section uses when it DOES say what happens after a teardown, close,
# timeout or failure. Deliberately crude: this triage only ever downgrades a
# candidate, so a missed phrasing leaves a gap in the review pile (safe) rather
# than dropping it (unsafe).
_RECOVERY_HINT = re.compile(
    r"re-?advertis\w*|re-?open\w*|re-?start\w*|retry|retries|re-?establish\w*|"
    r"return to idle|new session|re-?enter\w*|resume\w*|re-?attempt\w*",
    re.IGNORECASE,
)

# Actions whose name says the model had just torn something down. Deadlocking
# right after one of these is expected in a single-section model - the spec
# describes restarting somewhere else - so these are the ones worth triaging.
_TEARDOWN_HINT = re.compile(
    r"close|terminat|teardown|expir|timeout|abort|fail|error|disconnect|reset",
    re.IGNORECASE,
)


def triage_gap(r: dict, sections: dict, graph: dict) -> dict:
    """Classifies a teardown-shaped deadlock using the corpus, not intuition.

    Most of the deadlocks land on a close/timeout/failure action, which has two
    very different explanations: the spec really is silent about what follows,
    or the model simply stopped at its section boundary while the spec covers
    recovery elsewhere. The corpus can tell those apart:

      * the section's OWN text mentions recovery -> the model ignored behaviour
        it was given, so this is a modelling defect, not a finding;
      * a section it CROSS-REFERENCES covers recovery -> the gap is in the
        single-section modelling scope, not in the spec;
      * neither -> it stays a candidate.
    """
    uid = r["unit_id"]
    # The MODEL action that set up the state, not the environment action that
    # delivered the input. Under the unhandled-input signal the final state is
    # always reached by ReceiveInput, so keying triage on the literal last
    # action silently disabled it: every unit came back "not teardown-shaped"
    # and no corpus check ever ran.
    actions = [last_model_action(run_trace(run)).get("action", "")
               for run in r.get("runs", []) if run["outcome"] == "unhandled_input"]
    if not any(_TEARDOWN_HINT.search(a or "") for a in actions):
        return {"class": "candidate",
                "why": "the input was not left unhandled after a teardown"}

    own = sections.get(uid, {}).get("full_text", "")
    hit = _RECOVERY_HINT.search(own)
    if hit:
        return {"class": "modelling_defect",
                "why": f"the section's own text describes recovery (\"{hit.group(0)}\") "
                       f"but the model has no action for it",
                "quote": sentence_around(own, hit)}

    for ref in graph.get(uid, {}).get("references", []):
        rhit = _RECOVERY_HINT.search(sections.get(ref, {}).get("full_text", ""))
        if rhit:
            return {"class": "scope_artifact",
                    "why": f"recovery is described in `{ref}`, which this section "
                           f"cross-references (\"{rhit.group(0)}\") - outside the "
                           f"single-section modelling scope",
                    "quote": sentence_around(
                        sections.get(ref, {}).get("full_text", ""), rhit)}

    return {"class": "candidate",
            "why": "neither this section nor any section it references says what "
                   "happens after the teardown"}


# Environment actions: the harness's own input-delivery step, not behaviour the
# spec describes. Triage must look past them to the action that set the state up.
_ENV_ACTIONS = {"ReceiveInput"}


def last_model_action(trace: str) -> dict:
    """The last action in a trace that is not the harness's input delivery."""
    headers = re.findall(r"^State \d+: <(\w+) line (\d+),", trace, re.MULTILINE)
    for name, line in reversed(headers):
        if name not in _ENV_ACTIONS:
            return {"action": name, "line": int(line)}
    return {}


def sentence_around(text: str, match) -> str:
    """
    The sentence a triage keyword was found in.

    Printed with every ruled-out gap because the keyword alone is not evidence:
    "restart" in core_4.19.4.8 refers to restarting the acknowledgement-received
    TIMER, not to recovering a closed session, so the rule would dismiss a
    finding on a phrase that does not actually describe recovery. Showing the
    sentence puts that judgement back in the reviewer's hands.
    """
    start = text.rfind(".", 0, match.start()) + 1
    end = text.find(".", match.end())
    end = len(text) if end == -1 else end + 1
    return " ".join(text[start:end].split())


def _trace_states(trace: str) -> list:
    """Each state of a trace as {variable: value}.

    Values can span lines (a big function literal, a multi-line record), so a
    new assignment is recognised only by a line that STARTS a "/\\ var =" item;
    everything after it belongs to that value until the next one.
    """
    states = []
    cur = None
    for line in trace.splitlines():
        if re.match(r"^State \d+: <", line) or line.startswith("State 1: <Initial"):
            cur = {}
            states.append(cur)
            continue
        if cur is None:
            continue
        m = re.match(r"^/\\ ([A-Za-z_]\w*) = (.*)$", line)
        if m:
            cur[m.group(1)] = m.group(2)
            last = m.group(1)
        elif cur and line.strip():
            cur[last] = cur.get(last, "") + " " + line.strip()
    return states


def made_progress(r: dict) -> bool:
    """
    True if the model changed something of its OWN before the input stuck.

    Determined by DIFFING the trace states, not by the name of the action.
    Naming the environment action ("ReceiveInput") only works for models that
    follow the generation prompt; the hand-written ground-truth model calls it
    ReceiveMessage and was scored as having made progress when it had not.
    A step that changes nothing but pendingInput is input delivery, whatever
    it is called.

    This ranks CONFIDENCE, not validity: the known-real ArmFailSafe gap fires
    with no model action at all, so a false result here is not grounds for
    dismissing a finding.
    """
    for run in r.get("runs", []):
        if run["outcome"] != "unhandled_input":
            continue
        states = _trace_states(run_trace(run))
        for a, b in zip(states, states[1:]):
            changed = {k for k in set(a) | set(b) if a.get(k) != b.get(k)}
            if changed - {gd.INPUT_VAR}:
                return True
    return False


# ---------------------------------------------------------------------------
# Model-asserted unspecified cases
#
# Prompt rule 2 tells the generator, when the spec text leaves a case open, to
# write a "\* TODO: unspecified - ..." comment instead of inventing behaviour.
# It does so, and until now nothing read them.
#
# This is a SECOND, INDEPENDENT signal and it is worth keeping separate from
# the TLC findings for two reasons:
#
#   * It covers units TLC cannot reach a verdict on at all - a module whose
#     input alphabet is unrecoverable, or that never compiled, can still have
#     flagged a real omission while it was being written.
#   * It is UNVERIFIED. TLC never checked these. Some are genuine spec
#     omissions; others are modelling notes ("TLA+ has no floating point"), and
#     some may be the generator misreading the text. They are leads to review,
#     never findings.
# ---------------------------------------------------------------------------

_TODO_RE = re.compile(r"^\s*\\\*\s*TODO:\s*unspecified\s*-?\s*(.*)$")
_DEFN_RE = re.compile(r"^([A-Za-z_]\w*)\s*(\([^)]*\))?\s*==")


def extract_self_reported(tla_path) -> list:
    """Every "TODO: unspecified" note in a module, with where it sits.

    `near` is the definition the note appears inside (or just above), which is
    what makes the note reviewable - "unspecified" alone does not say which
    clause. A note before any definition reports an empty `near`.
    """
    path = Path(tla_path)
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []

    notes, current = [], ""
    for i, line in enumerate(lines, 1):
        d = _DEFN_RE.match(line)
        if d:
            current = d.group(1)
        m = _TODO_RE.match(line)
        if m:
            # A note sitting directly above a definition belongs to THAT
            # definition, not the one before it.
            following = ""
            for nxt in lines[i:i + 4]:
                nd = _DEFN_RE.match(nxt)
                if nd:
                    following = nd.group(1)
                    break
                if nxt.strip() and not nxt.strip().startswith("\\*"):
                    break
            notes.append({"line": i,
                          "text": m.group(1).strip(),
                          "near": following or current})
    return notes


def collect_self_reported(models_dir: Path, rows: list) -> list:
    """Self-reported notes for every GENERATED module, checked or not.

    Reads the generation log rather than the TLC log on purpose: a module that
    failed SANY never reaches the TLC log, and those are exactly the units with
    no other signal at all.
    """
    gen_log = models_dir / "results.jsonl"
    try:
        gen = [json.loads(l) for l in gen_log.read_text(encoding="utf-8").splitlines() if l.strip()]
    except OSError:
        return []

    outcome = {r["unit_id"]: r["outcome"] for r in rows}
    found = []
    for g in gen:
        notes = extract_self_reported(g.get("tla_path", ""))
        if not notes:
            continue
        found.append({
            "unit_id": g["unit_id"],
            "title": g.get("title", ""),
            "final_score": g.get("final_score") or 0,
            "outcome": outcome.get(g["unit_id"],
                                   "did not compile" if not g.get("sany", {}).get("passed")
                                   else "not checked"),
            "notes": notes,
        })
    found.sort(key=lambda f: -f["final_score"])
    return found


# ---------------------------------------------------------------------------
# Where else the spec might handle this event
#
# A finding means THIS section defines no handling. The Matter spec routinely
# defines it next door: core_4.12.2.1 looked like a gap for an acknowledgement
# arriving with nothing outstanding, and core_4.12.5.2 says what that means.
#
# Cross-references alone do NOT find that. core_4.12.2.1 references only
# core_4.3.2 - the two sections are never linked in the text. What relates them
# is position: both live under core_4.12. So the neighbourhood searched here is
# cross-referenced sections UNION siblings sharing the parent number.
#
# The result is reported as evidence with the sentence quoted, never as an
# automatic dismissal. The last keyword rule that dismissed findings silently
# matched "restart" in core_4.19.4.8, where it referred to restarting a timer,
# not recovering a session.
# ---------------------------------------------------------------------------

_GENERIC_EVENT_WORDS = {"receive", "send", "handle", "process", "on", "do",
                        "trigger", "input", "event", "msg", "message", "action"}


def event_terms(event: str) -> list:
    """Searchable words from an event name: ReceiveAck -> ['ack']."""
    event = event.strip().strip('"')
    words = re.findall(r"[A-Z]+(?![a-z])|[A-Z][a-z]+|[a-z]+|\d+", event)
    return [w.lower() for w in words
            if w.lower() not in _GENERIC_EVENT_WORDS and len(w) > 2]


def _sibling_ids(uid: str, sections: dict) -> list:
    """Sections sharing this one's parent number (core_4.12.2.1 -> core_4.12.*)."""
    body = uid.split("_", 1)[1] if "_" in uid else uid
    parts = body.split(".")
    if len(parts) < 2:
        return []
    prefix = uid.split("_", 1)[0] + "_" + ".".join(parts[:2]) + "."
    return [k for k in sections if k.startswith(prefix) and k != uid]


def neighbour_handling(uid: str, event: str, sections: dict, graph: dict,
                       max_hits: int = 3) -> list:
    """Sentences in nearby sections that may define handling for this event.

    Each hit is {"ref", "quote"}. A hit means "read this before calling it a
    gap", not "this is not a gap".
    """
    terms = event_terms(event)
    if not terms:
        return []
    neighbourhood = list(dict.fromkeys(
        list(graph.get(uid, {}).get("references", [])) + _sibling_ids(uid, sections)))

    # Sentences are SCORED, not taken in section order. Ordering by section
    # number returned three sentences merely mentioning acknowledgements and
    # stopped before core_4.12.5.2, the one that actually says what an
    # unmatched acknowledgement means.
    scored = []
    for ref in neighbourhood:
        text = sections.get(ref, {}).get("full_text", "")
        if not text:
            continue
        best = None
        for sentence in re.split(r"(?<=\.)\s+", " ".join(text.split())):
            low = sentence.lower()
            if not any(t in low for t in terms):
                continue
            # The section must say what HAPPENS, not merely mention the event.
            if not re.search(r"\b(SHALL|SHOULD|MAY|MUST|indicates|is ignored|"
                             r"drop(?:ped|s)?|discard(?:ed|s)?)\b", sentence):
                continue
            score = 1
            # What we are really looking for is the absent-case clause: the
            # sentence that says what to do when the event matches nothing.
            # "no longer" is deliberately absent: it matched "wait for a time
            # no longer than", which says nothing about an unmatched event.
            if re.search(r"\b(no match|not match|no corresponding|does not exist|"
                         r"not found|unknown|unexpected|unsolicited|duplicate)\b",
                         low):
                score += 5
            # Frequency is a weak signal and is capped: a section that merely
            # discusses the event a lot must not outrank the one sentence that
            # says what happens when it matches nothing.
            score += min(sum(low.count(t) for t in terms) - 1, 2)
            if best is None or score > best[0]:
                best = (score, {"ref": ref, "quote": sentence[:300], "score": score})
        if best:
            scored.append(best[1])
    scored.sort(key=lambda h: -h["score"])
    return scored[:max_hits]


def last_action(trace: str) -> dict:
    """The action that produced the final state of a trace.

    TLC labels each state with the action that reached it, e.g.
    "State 7: <ClientSendHandshakeRequest line 130, col 5 to line 139, col 79
    of module core_4_19_4_3>". That name is the single most useful thing for
    review: it says which clause of the spec got the model into the state it
    then had no way out of.
    """
    headers = re.findall(r"^State \d+: <(\w+) line (\d+),", trace, re.MULTILINE)
    if not headers:
        return {}
    name, line = headers[-1]
    return {"action": name, "line": int(line)}


def source_comment(tla_path: Path, action: str) -> str:
    """The \\* SOURCE: / quoted-spec comment block directly above an action.

    Anchored on the action's DEFINITION line, found by name - TLC's trace
    reports the line where the action's body starts, which is one line below
    the "Name ==" the comments sit above, so counting up from the reported line
    lands on the definition itself and finds nothing.

    The generation prompt requires every action to cite its clause this way, so
    this recovers the exact spec sentences the model was working from.
    """
    try:
        lines = tla_path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return ""
    defn = next((i for i, l in enumerate(lines)
                 if re.match(rf"^{re.escape(action)}\s*(?:\(.*?\))?\s*==", l)), None)
    if defn is None:
        return ""
    out = []
    i = defn - 1
    while i >= 0 and lines[i].lstrip().startswith("\\*"):
        out.append(lines[i].strip())
        i -= 1
    return "\n".join(reversed(out))


def explored(r: dict) -> tuple:
    """(max distinct states, max search depth) across a unit's configs."""
    states = max((run.get("distinct_states", 0) for run in r.get("runs", [])), default=0)
    depth = max((run.get("search_depth", 0) for run in r.get("runs", [])), default=0)
    return states, depth


def is_trivially_clean(r: dict) -> bool:
    states, depth = explored(r)
    return states < _TRIVIAL_STATES or depth < _TRIVIAL_DEPTH


def flag_label(run: dict) -> str:
    flags = run.get("bool_assignment") or {}
    return ", ".join(f"{k}={v}" for k, v in flags.items()) or "no capability flags"


def write_review_files(gaps: list, sections: dict, review_dir: Path) -> int:
    """One self-contained file per candidate gap, for the manual B.4.3 review.

    Everything a reviewer needs to answer "is this a real specification gap?"
    in one place: the state the model got stuck in, the action that got it
    there, that action's cited clause, and the section's full spec text. The
    spec text is why these are separate files rather than inlined - the
    fourteen sections together run to ~82k characters.
    """
    if not gaps:
        return 0
    review_dir.mkdir(parents=True, exist_ok=True)
    for r in gaps:
        uid = r["unit_id"]
        steps = steps_to_deadlock(r)
        doc = [f"# Review: `{uid}` — {r.get('title')}\n"]
        if steps <= 1:
            doc.append("> ⚠️ **Initial-state deadlock.** The model was stuck before it did "
                       "anything, which points at an under-constrained `Init` rather than a "
                       "spec gap. Low priority.\n")
        tri = r.get("triage", {})
        if tri:
            doc.append(f"Automated triage: **{tri['class']}** — {tri['why']}\n")
            if tri.get("quote"):
                # The keyword alone is not evidence; show the sentence so a
                # reviewer can see whether it really describes recovery.
                doc.append(f"> {tri['quote']}\n")
        doc.append("## Verdict to record\n")
        doc.append("- [ ] real specification gap")
        doc.append("- [ ] modelling defect (the generated model is wrong)")
        doc.append("- [ ] the spec genuinely does describe this case (model missed a handler)\n")
        doc.append("Notes:\n\n\n")
        doc.append("## Evidence\n")
        doc.append(f"- steps to the unhandled input: {steps}")
        doc.append(f"- ranker score: {r.get('final_score')}")
        doc.append(f"- module: `{r['tla_path']}`\n")
        for run in r.get("runs", []):
            if run["outcome"] != "unhandled_input":
                continue
            trace = run_trace(run)
            act = last_action(trace)
            doc.append(f"### Under {flag_label(run)}\n")
            if act:
                doc.append(f"Last action to fire: **`{act['action']}`**\n")
                cite = source_comment(Path(r["tla_path"]), act["action"])
                if cite:
                    doc.append("Clause that action cites:\n")
                    doc.append("```\n" + cite + "\n```\n")
            doc.append("State in which the input went unhandled:\n")
            doc.append("```\n" + deadlock_state(run) + "\n```\n")
            doc.append("<details><summary>Full trace</summary>\n")
            doc.append("```\n" + trace + "\n```\n")
            doc.append("</details>\n")
        spec = sections.get(uid, {}).get("full_text", "")
        doc.append("## Spec text for this section\n")
        doc.append(spec if spec else "_Not found in sections.json._")
        doc.append("")
        (review_dir / f"{uid}.md").write_text("\n".join(doc), encoding="utf-8")
    return len(gaps)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models-dir", default="models/generated/ch45")
    ap.add_argument("--log", default=None)
    ap.add_argument("--out", default=None)
    ap.add_argument("--corpus-dir", default="data/processed/core",
                    help="Where sections.json lives, for the spec text of each gap")
    ap.add_argument("--review-dir", default=None,
                    help="Directory for one self-contained review file per candidate gap "
                         "(default: <models-dir>/review)")
    args = ap.parse_args()

    models_dir = Path(args.models_dir)
    log_path = Path(args.log) if args.log else models_dir / "tlc_results.jsonl"
    out_path = Path(args.out) if args.out else models_dir / "gap_report.md"
    review_dir = Path(args.review_dir) if args.review_dir else models_dir / "review"
    try:
        sections = {sec["id"]: sec for sec in
                    json.loads((Path(args.corpus_dir) / "sections.json").read_text(encoding="utf-8"))}
    except OSError:
        sections = {}
    try:
        graph = json.loads((Path(args.corpus_dir) / "dependency_graph.json").read_text(encoding="utf-8"))
    except OSError:
        graph = {}

    rows = [json.loads(l) for l in log_path.read_text(encoding="utf-8").splitlines() if l.strip()]
    rows.sort(key=lambda r: -(r.get("final_score") or 0))

    gaps = [r for r in rows if r["outcome"] == "unhandled_input"]
    violated = [r for r in rows if r["outcome"] == "invariant_violated"]
    clean = [r for r in rows if r["outcome"] == "no_error"]
    unchecked = [r for r in rows if r["outcome"] not in _CHECKED]

    for r in gaps:
        r["triage"] = triage_gap(r, sections, graph)
    ruled_out = [r for r in gaps if r["triage"]["class"] != "candidate"]
    gaps = [r for r in gaps if r["triage"]["class"] == "candidate"]
    # Rule 4b first: an event arriving where the device genuinely sits
    # outranks one arriving in setup scaffolding. Unranked (pre-4b) modules
    # sit between the two rather than at the bottom - we do not know which
    # they are, and demoting them would hide findings for lack of a label.
    _STRENGTH_ORDER = {"operational": 0, "unranked": 1, "setup_only": 2}
    gaps.sort(key=lambda r: (_STRENGTH_ORDER.get(r.get("gap_strength"), 1),
                             -steps_to_deadlock(r),
                             -(r.get("final_score") or 0)))

    self_reported = collect_self_reported(models_dir, rows)
    n_notes = sum(len(f["notes"]) for f in self_reported)


    out = []
    out.append("# TLC candidate-gap report\n")
    out.append(f"Source log: `{log_path}`\n")
    out.append("Candidate gaps are ordered by **how many steps it took to reach the unhandled "
               "input**, "
               "not by ranker score: the further the model got before hitting one, the more "
               "confidence that the model works and the spec is what ran out.\n")
    out.append("An **unhandled input** is a reachable state in which an event is waiting and no "
               "action of `Next` can consume it: something arrived that the spec text defines no "
               "handling for. Unlike a plain deadlock this does **not** fire when a protocol "
               "simply ends — \"SHALL close the session\", \"perform no further processing\" and "
               "the like leave nothing pending, so they are vacuously fine. It is still a "
               "*candidate* gap: the generated model may have omitted a handler the spec does "
               "describe. Each one needs review against the section's own text.\n")

    out.append("## Summary\n")
    out.append("| outcome | units |")
    out.append("|---|---|")
    # "Real progress" means the model took at least one action of its OWN
    # before the input went unhandled. A 2-state trace is Init plus the
    # harness's ReceiveInput - zero model actions - so counting it by state
    # depth (> 1) overstated confidence on exactly the weakest findings.
    substantive = len([r for r in gaps if made_progress(r)])
    by_strength = collections.Counter(r.get("gap_strength") or "unranked" for r in gaps)
    out.append(f"| candidate gaps (unhandled input) | {len(gaps) + len(ruled_out)} "
               f"→ **{len(gaps)}** after triage ({substantive} of those reached after "
               f"real progress) |")
    out.append(f"| &nbsp;&nbsp;of which in an operational state | "
               f"**{by_strength.get('operational', 0)}** |")
    out.append(f"| &nbsp;&nbsp;of which setup-only (lower priority) | "
               f"{by_strength.get('setup_only', 0)} |")
    out.append(f"| &nbsp;&nbsp;of which unranked (no rule 4b) | "
               f"{by_strength.get('unranked', 0)} |")
    out.append(f"| invariant violated | {len(violated)} |")
    trivial = [r for r in clean if is_trivially_clean(r)]
    out.append(f"| checked, nothing found | {len(clean)} "
               f"(of which {len(trivial)} explored too little to mean anything) |")
    out.append(f"| **not checkable** (see below) | **{len(unchecked)}** |")
    out.append(f"| model-asserted unspecified cases (unverified) | {n_notes} note(s) "
               f"in {len(self_reported)} unit(s) |")
    out.append(f"| total | {len(rows)} |\n")
    checked_total = len(gaps) + len(violated) + len(clean)
    out.append(f"{checked_total} of {len(rows)} modules were actually model-checked. "
               "The rest produced no verdict either way.\n")

    out.append("## Candidate gaps\n")
    if not gaps:
        out.append("_None._\n")
    if ruled_out:
        out.append("### Ruled out by corpus triage\n")
        out.append("These deadlocked on a teardown/close/timeout action, and the corpus itself "
                   "explains why — so they are not candidate gaps. See `triage_gap()` for the "
                   "rule.\n")
        out.append("| unit | class | why |")
        out.append("|---|---|---|")
        for r in sorted(ruled_out, key=lambda x: x["unit_id"]):
            tri = r["triage"]
            why = tri["why"]
            if tri.get("quote"):
                why += f'<br>matched sentence: *"{tri["quote"]}"*'
            out.append(f"| `{r['unit_id']}` | {tri['class']} | {why} |")
        out.append("")
        out.append("### Remaining candidates\n")
    for r in gaps:
        steps = steps_to_deadlock(r)
        marker = "" if steps > 1 else "  ⚠️ reached immediately"
        out.append(f"### `{r['unit_id']}` — {r.get('title')}{marker}\n")
        if steps <= 1:
            out.append("> The deadlock is the **initial state itself** — no action was ever "
                       "enabled. This almost always means `Init` leaves a variable free over a "
                       "value no action accepts, i.e. a modelling defect, not a spec gap. "
                       "Treat as low priority.\n")
        out.append(f"- steps to the unhandled input: {steps}")
        out.append(f"- ranker score: {r.get('final_score')}")
        out.append(f"- module: `{Path(r['tla_path']).name}`")
        strength = r.get("gap_strength")
        if strength == "operational":
            out.append("- 🔴 **operational state** — the module says the device "
                       "genuinely sits in this state; the event did not arrive "
                       "during setup")
        elif strength == "setup_only":
            out.append("- ⬇️ setup-only — the event arrived in a state the module "
                       "marks as scaffolding (pre-initialisation). Lower priority, "
                       "but **not** dismissed: the ground-truth ArmFailSafe gap "
                       "also arrives in its initial state")
        elif strength == "unranked":
            out.append("- ❔ unranked — module predates rule 4b and declares no "
                       "`Operational`, so setup and real states cannot be told apart")
        # Where else the spec might already answer this. Evidence for the
        # reviewer, never an automatic dismissal.
        unhandled_val = ""
        for run in r.get("runs", []):
            if run["outcome"] == "unhandled_input" and run.get("unhandled_value"):
                unhandled_val = run["unhandled_value"]
                break
        nearby = neighbour_handling(r["unit_id"], unhandled_val, sections, graph) \
            if unhandled_val else []
        if nearby:
            out.append(f"- 📎 **possibly handled nearby** — read these before "
                       f"calling it a gap:")
            for h in nearby:
                out.append(f"    - `{h['ref']}`: *\"{h['quote']}\"*")
        nowhere = r.get("unhandled_everywhere") or []
        if nowhere:
            # Stronger than an ordinary finding: the module declares the spec
            # says these arrive, and then no action anywhere handles them in
            # ANY state - not just the state the trace happened to reach.
            out.append("- 🔴 **declared but handled nowhere**: "
                       + ", ".join(f"`{e}`" for e in nowhere)
                       + " — the module lists these as events this section can receive, "
                         "and no action in it handles them in any state")
        if r.get("alphabet_source") == "recovered-from-guards":
            out.append("- ⚠️ the module does not declare `Inputs`, so its alphabet was "
                       "recovered from guards; events it handles nowhere cannot be seen")
        kinds = r.get("constant_kinds") or {}
        if kinds:
            out.append("- constants (inferred kind): "
                       + ", ".join(f"`{k}`={v}" for k, v in kinds.items()))
        if r.get("partial_boolean_coverage"):
            out.append("- ⚠️ capability-flag coverage was capped — only all-TRUE and "
                       "all-FALSE were explored")
        for run in r.get("runs", []):
            if run["outcome"] != "unhandled_input":
                continue
            out.append(f"\n**Unhandled input under {flag_label(run)}** after "
                       f"{trace_length(run_trace(run))} state(s) "
                       f"({run.get('distinct_states', '?')} distinct states explored):\n")
            trace = run_trace(run)
            act = last_action(trace)
            if act:
                out.append(f"Last action to fire: **`{act['action']}`** "
                           f"(line {act['line']} of the module)\n")
                cite = source_comment(Path(r["tla_path"]), act["action"])
                if cite:
                    out.append("Spec clause that action cites:\n")
                    out.append("```")
                    out.append(cite)
                    out.append("```")
            out.append("State in which the input went unhandled:\n")
            out.append("```")
            out.append(deadlock_state(run))
            out.append("```")
        out.append("")

    if violated:
        out.append("## Invariant violations\n")
        for r in violated:
            run = next((x for x in r["runs"] if x["outcome"] == "invariant_violated"), {})
            out.append(f"- `{r['unit_id']}` — {r.get('title')} — "
                       f"invariant `{run.get('violated_invariant', '?')}` failed")
        out.append("")

    out.append("## Model-asserted unspecified cases\n")
    out.append("These are **not** TLC findings. While writing each model the generator was "
               "told (prompt rule 2) to leave a `\\* TODO: unspecified` note rather than invent "
               "behaviour wherever the spec text did not say what happens. These are those "
               "notes, verbatim.\n")
    out.append("They are a **separate, unverified signal**. TLC never checked them. Some are "
               "genuine omissions, some are modelling limitations (TLA+ has no floating "
               "point), and some may simply be the generator misreading the text. Treat each "
               "as a lead to check against the section, not as a result.\n")
    out.append("They are listed for **every generated module**, including those TLC could not "
               "reach a verdict on — a module that never compiled can still have flagged a "
               "real omission on its way past.\n")
    if not self_reported:
        out.append("_None — no module reported an unspecified case._\n")
    else:
        for f in self_reported:
            out.append(f"### `{f['unit_id']}` — {f['title']}\n")
            out.append(f"- TLC outcome: **{f['outcome']}**")
            out.append(f"- ranker score: {f['final_score']}\n")
            for n in f["notes"]:
                where = f" (near `{n['near']}`)" if n["near"] else ""
                out.append(f"> {n['text']}")
                out.append(f">")
                out.append(f"> — line {n['line']}{where}\n")
    out.append("")

    out.append("## Not checkable\n")
    if not unchecked:
        out.append("_None — every module produced a verdict._\n")
    else:
        out.append("These modules parsed (SANY passed) but TLC could not reach a verdict. "
                   "They are **not** evidence of a clean spec.\n")
        out.append("| unit | outcome | why |")
        out.append("|---|---|---|")
        for r in unchecked:
            why = _NOT_CHECKED_REASON.get(r["outcome"], "")
            if r["outcome"] == "config_error" and r.get("error"):
                why = r["error"]
            extra = f" (`{r['unbounded_set']}`)" if r.get("unbounded_set") else ""
            for run in r.get("runs", []):
                if run.get("unassigned_variable"):
                    extra = f" (`{run['unassigned_variable']}`)"
                    break
            out.append(f"| `{r['unit_id']}` | {r['outcome']} | {why}{extra} |")
        out.append("")

    out.append("## Checked, nothing found\n")
    if not clean:
        out.append("_None._")
    else:
        out.append("TLC explored these models completely and found no deadlock. How much "
                   "that is worth depends on how much the model actually does — a model "
                   "with a handful of states cannot deadlock no matter how incomplete the "
                   "spec is, so the small ones are **not** evidence of a complete spec.\n")
        out.append("| unit | states | depth | meaningful? | title |")
        out.append("|---|---|---|---|---|")
        for r in sorted(clean, key=lambda x: -explored(x)[0]):
            states, depth = explored(r)
            verdict = "⚠️ too small to conclude" if is_trivially_clean(r) else "yes"
            out.append(f"| `{r['unit_id']}` | {states} | {depth} | {verdict} | {r.get('title')} |")
    out.append("")

    out_path.write_text("\n".join(out), encoding="utf-8")
    print(f"[report] wrote {out_path}")

    written = write_review_files(gaps, sections, review_dir)
    if written:
        print(f"[report] wrote {written} per-gap review file(s) to {review_dir}/")
    print(f"[report] candidate gaps={len(gaps)}  invariant_violations={len(violated)}  "
          f"clean={len(clean)}  not_checkable={len(unchecked)}")


if __name__ == "__main__":
    main()
