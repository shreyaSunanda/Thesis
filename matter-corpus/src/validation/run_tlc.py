"""
Run TLC over a generated TLA+ module and classify what it finds.

SANY answers "is this a well-formed module?". TLC answers the question the
thesis actually cares about: "does the behavior this module describes ever
reach a state the spec text does not say how to leave?"

The hand-written ArmFailSafe model encodes that question with an explicit
UndefinedTransition catch-all action plus a NeverUndefined invariant. That
works, but it only finds gaps the modeller already anticipated enough to write
a catch-all for, and the generation prompt explicitly forbids the model from
inventing such catch-alls (rule 4) precisely so they cannot be faked.

So for generated models the gap signal is TLC's own DEADLOCK check, which needs
nothing added to the module: a deadlock is, by definition, a reachable state in
which no action of Next is enabled — i.e. the model reached a situation and the
spec text supplied no transition out of it. That is the same finding
UndefinedTransition reports, detected generically. (It is a *candidate* gap,
not a proven one: a deadlock can equally mean the model is wrong, or that the
state is a legitimate terminal state. B.4.3 review is still manual; this just
finds the states worth reviewing.)

Outcomes reported per config:
    unhandled_input     THE GAP SIGNAL: an event arrived that no action handles.
                        See gap_detector.py for why this replaced deadlock.
    no_shape            the module skips the mandatory input shape, so nothing
                        can be detected on it either way
    no_error            TLC explored the whole state space, nothing flagged
    deadlock            CANDIDATE GAP - trace included
    invariant_violated  an invariant in the module failed
    incomplete_next_state  an action leaves a VARIABLE neither assigned nor
                        UNCHANGED. A model defect with a one-line fix.
    number_too_large    the model uses a real-world-sized numeric literal
                        (2^32 message-counter ranges and the like). TLC cannot
                        represent it; the model needs a small abstract bound.
    unbounded_quantifier  the model quantifies over an infinite set (Nat, Int,
                        Seq(S), SUBSET of an infinite set) so TLC cannot
                        enumerate it. A model defect SANY cannot see, not a
                        spec gap - the module needs explicit bounds.
    runtime_error       other TLC evaluation error (silly expression, type
                        mismatch, applying a non-function...)
    timeout             state space too large to finish in the time budget
    tlc_error           TLC refused the module/config (setup problem, not a gap)
"""
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from src.validation.tlc_config import (plan_configs, constant_value,
                                         extract_input_alphabet, input_alphabet_tla,
                                         extract_record_alphabet, record_alphabet_tla,
                                         extract_declared_alphabet, unhandled_everywhere,
                                         declares_operational)
from src.validation import gap_detector as gd

_STATS_RE = re.compile(
    r"([\d,]+) states generated.*?([\d,]+) distinct states found.*?([\d,]+) states left on queue",
    re.DOTALL,
)
_DEPTH_RE = re.compile(r"The depth of the complete state graph search is (\d+)")


def _int(text: str) -> int:
    return int(text.replace(",", ""))


def classify_output(returncode: int, output: str, timed_out: bool) -> dict:
    """Maps raw TLC output onto one of the outcome labels documented above."""
    if timed_out:
        outcome = "timeout"
    elif "Deadlock reached" in output:
        outcome = "deadlock"
    elif re.search(rf"Invariant (?:{gd.INVARIANT_NAME}|{gd.OPERATIONAL_INVARIANT})"
                   r" is violated", output):
        # The gap signal, kept separate from any other invariant the model
        # happened to define: this one the harness attached, and only it means
        # "an event arrived that nothing handles".
        outcome = "unhandled_input"
    elif re.search(r"Invariant \S+ is violated", output):
        outcome = "invariant_violated"
    elif "Model checking completed. No error has been found" in output or "No error has been found" in output:
        outcome = "no_error"
    elif "is not completely specified by action" in output:
        outcome = "incomplete_next_state"
    elif "can't handle a number this big" in output or "number is too big" in output:
        outcome = "number_too_large"
    elif ("non-enumerable quantifier bound" in output
          or "is not enumerable" in output
          # TLC words this three different ways depending on where the infinite
          # set turns up - as a quantifier bound, as a record field's value set,
          # or inside a Cardinality/SUBSET computation. All three mean the same
          # defect, so they get the same label.
          or "Attempted to compute the number of elements in the overridden value" in output
          or re.search(r"can't enumerate the value of the `\w+' field:\s*\n?\s*(?:Nat|Int)", output)):
        # Distinguished from a plain runtime error because the remedy is
        # completely different: this is always "the generated module needs an
        # explicit finite bound", and it is fixable from the prompt side.
        outcome = "unbounded_quantifier"
    elif re.search(r"Error: (?:The behavior up to this point|Attempted to|In evaluation|Encountered|TLC threw)", output):
        outcome = "runtime_error"
    elif returncode == 0:
        outcome = "no_error"
    else:
        outcome = "tlc_error"

    result = {"outcome": outcome, "returncode": returncode}

    stats = _STATS_RE.search(output)
    if stats:
        result["states_generated"] = _int(stats.group(1))
        result["distinct_states"] = _int(stats.group(2))
    depth = _DEPTH_RE.search(output)
    if depth:
        result["search_depth"] = int(depth.group(1))

    inv = re.search(r"Invariant (\S+) is violated", output)
    if inv:
        result["violated_invariant"] = inv.group(1)

    if outcome in ("deadlock", "invariant_violated", "runtime_error",
                   "unbounded_quantifier", "number_too_large",
                   "incomplete_next_state", "unhandled_input"):
        result["trace"] = extract_trace(output)
        # A length-1 trace means the deadlock IS an initial state: nothing was
        # ever enabled. That is usually an under-constrained Init (a variable
        # left free over a value no action accepts), not a spec gap, so the
        # report has to be able to tell the two apart.
        result["trace_length"] = trace_length(result["trace"])
    if outcome in ("tlc_error", "runtime_error", "unbounded_quantifier",
                   "number_too_large", "incomplete_next_state"):
        result["error_excerpt"] = extract_errors(output)
    if outcome == "unhandled_input":
        result["unhandled_value"] = gd.extract_pending_value(result.get("trace", ""))
    if outcome == "incomplete_next_state":
        miss = re.search(r"following variable is not assigned:\s*(\w+)", output)
        if miss:
            result["unassigned_variable"] = miss.group(1)
    if outcome == "unbounded_quantifier":
        bound = re.search(r"non-enumerable quantifier bound\s*\n?\s*(\S+)", output)
        if bound:
            result["unbounded_set"] = bound.group(1).rstrip(".")
    # Kept so a result can be re-classified later without re-running TLC, which
    # matters because these runs are the expensive part of the pipeline.
    if outcome != "no_error":
        result["raw_tail"] = output[-6000:]

    return result


_STATE_HEADER_RE = re.compile(r"^State (\d+): ", re.MULTILINE)


def trace_length(trace: str) -> int:
    """Number of states in a TLC trace; 1 means the very first state deadlocked."""
    nums = [int(m.group(1)) for m in _STATE_HEADER_RE.finditer(trace)]
    return max(nums) if nums else 0


def extract_trace(output: str, max_chars: int = 4000) -> str:
    """Pulls the counterexample/deadlock trace out of TLC's chatty output."""
    start = output.find("The behavior up to this point is:")
    if start == -1:
        # raw_tail keeps only the last few KB, so for a long counterexample the
        # "behavior up to this point" header can fall off the front. Anchor on
        # the first real state header instead of giving up.
        first_state = _STATE_HEADER_RE.search(output)
        start = first_state.start() if first_state else output.find("Error:")
    if start == -1:
        return ""
    # Cut at the START of the summary line, not inside it - searching for
    # "states generated" alone left its leading count ("149") glued to the
    # final state of the trace.
    tail = re.search(r"^\s*[\d,]+ states generated", output[start:], re.MULTILINE)
    end = start + tail.start() if tail else len(output)
    trace = output[start:end]
    if len(trace) > max_chars:
        # Cut on a line boundary so the trace never ends mid-conjunct
        # ("/\ server_timer =" with the value lopped off).
        trace = trace[:max_chars].rsplit("\n", 1)[0] + "\n... (trace truncated)"
    return trace.strip()


def extract_errors(output: str, max_chars: int = 2000) -> str:
    lines = [l for l in output.splitlines()
             if "Error" in l or "error" in l or l.strip().startswith("***")]
    return "\n".join(lines)[:max_chars].strip()


def run_tlc_once(tla_path: Path, cfg_path: Path, tla_tools_jar: Path,
                 timeout: int = 120, workers: str = "1",
                 extra_args: list = None) -> dict:
    """One TLC invocation. Metadata goes to a temp dir so the repo stays clean.

    SINGLE-WORKER ON PURPOSE. With parallel workers TLC reports whichever
    invariant violation a worker reaches first, so the SAME module and config
    yield different counterexamples run to run. That is not merely cosmetic:
    the report's triage reads the last model action out of the trace, so
    core_4.19.4.8 was classified `modelling_defect` on one run (trace ended on
    a teardown) and `candidate` on the next (trace ended on a receive). A
    finding that changes class between identical runs is not reportable.
    One worker makes the search deterministic; these state spaces are small
    enough that the lost parallelism costs little.
    """
    tla_tools_jar = Path(tla_tools_jar).resolve()
    if not tla_tools_jar.exists():
        return {"outcome": "tlc_error", "error_excerpt": f"tla2tools.jar not found: {tla_tools_jar}"}

    metadir = tempfile.mkdtemp(prefix="tlc-meta-")
    cmd = [
        "java", "-XX:+UseParallelGC", "-cp", str(tla_tools_jar), "tlc2.TLC",
        "-config", cfg_path.name,
        "-workers", workers,
        "-metadir", metadir,
        "-cleanup",
        *(extra_args or []),
        tla_path.name,
    ]
    timed_out = False
    try:
        proc = subprocess.run(cmd, cwd=str(tla_path.parent), capture_output=True,
                              text=True, timeout=timeout)
        output, returncode = proc.stdout + proc.stderr, proc.returncode
    except subprocess.TimeoutExpired as e:
        timed_out = True
        output = ((e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")) + \
                 ((e.stderr or b"").decode("utf-8", "replace") if isinstance(e.stderr, bytes) else (e.stderr or ""))
        returncode = -1
    except FileNotFoundError:
        shutil.rmtree(metadir, ignore_errors=True)
        return {"outcome": "tlc_error", "error_excerpt": "java not found - is a JRE installed and on PATH?"}
    finally:
        shutil.rmtree(metadir, ignore_errors=True)

    result = classify_output(returncode, output, timed_out)
    result["cfg"] = cfg_path.name
    result["timeout_s"] = timeout
    return result


def check_module(tla_path, tla_tools_jar, timeout: int = 120,
                 max_configs: int = 4, keep_cfg: bool = True) -> dict:
    """
    Plans configs for one module, runs TLC under each, and summarises.

    A unit counts as a candidate gap if ANY config deadlocks: the booleans are
    device-capability flags, so "this gap only shows up when NFC is supported"
    is still a gap, and which config exposed it is recorded.
    """
    tla_path = Path(tla_path)
    code = tla_path.read_text(encoding="utf-8")
    plan = plan_configs(code, max_configs=max_configs)

    summary = {
        "tla_path": str(tla_path),
        "module_name": plan["module_name"],
        "constants": plan["constants"],
        "constant_kinds": plan["constant_kinds"],
        "invariants_checked": plan["invariants"],
        "partial_boolean_coverage": plan["partial_boolean_coverage"],
        "runs": [],
    }

    summary["operator_constants"] = plan["operator_constants"]
    summary["indexed_constants"] = plan["indexed_constants"]

    if not plan["uses_spec"] and not (plan["has_init"] and plan["has_next"]):
        summary["outcome"] = "config_error"
        summary["error"] = ("module defines neither a Spec nor both Init and Next - "
                            "nothing for TLC to run")
        return summary

    if plan["indexed_constants"]:
        # e.g. MaxWindowSize["Server"] - the module wants a function but
        # declared a plain CONSTANT. Only the module can say what the domain
        # is, so this is reported rather than guessed at.
        summary["outcome"] = "config_error"
        summary["error"] = (
            "module applies CONSTANT(s) "
            + ", ".join(f"{n}[...]" for n in plan["indexed_constants"])
            + " as a function, but declares them as plain constants - the "
              "harness cannot infer the domain; the model should declare them "
              "as a function-valued constant or index a VARIABLE instead")
        return summary

    if plan["operator_constants"]:
        # TLC needs "Op(a, b) <- SomeDefinition" for an operator CONSTANT, and
        # there is no honest way to invent that definition here - whatever we
        # substituted would be our semantics, not the spec's. Reported rather
        # than guessed at.
        summary["outcome"] = "config_error"
        summary["error"] = (
            "module declares operator CONSTANT(s) "
            + ", ".join(f"{n}(_)" for n in plan["operator_constants"])
            + " - these need a definition override no harness can synthesize; "
              "the model should define the helper in-module instead")
        return summary

    summary["has_input_shape"] = gd.has_input_shape(plan)
    if not summary["has_input_shape"]:
        # Without pendingInput/NoInput there is nothing to detect. Reported as
        # its own outcome rather than run anyway: a module with no notion of an
        # incoming event cannot show an unhandled one, so a clean result from it
        # would mean nothing.
        summary["outcome"] = "no_shape"
        summary["error"] = gd.missing_shape_reason(plan)
        return summary

    # The alphabet the module can actually recognise. Handing it model values
    # instead makes every input unmatchable and fabricates a gap on step 1 -
    # see extract_input_alphabet's note.
    alphabet = extract_input_alphabet(code)

    # Rule 4a: the module writes its own alphabet out. Prefer it over scanning
    # guards, which can only find events some action HANDLES - an event handled
    # nowhere has no guard and would otherwise be invisible.
    declared = extract_declared_alphabet(code)
    summary["declared_alphabet"] = declared
    if declared:
        summary["input_alphabet"] = declared
        summary["unhandled_everywhere"] = unhandled_everywhere(
            declared, alphabet["literals"])
        summary["alphabet_source"] = "declared"
        alphabet_tla = input_alphabet_tla(declared)
        alphabet = {"literals": declared, "structured": False}
    else:
        summary["input_alphabet"] = alphabet["literals"]
        summary["alphabet_source"] = "recovered-from-guards"
        alphabet_tla = input_alphabet_tla(alphabet["literals"]) if alphabet["literals"] else ""

    if alphabet["structured"]:
        # Record-shaped inputs: recoverable only when every non-literal field
        # is quantifier-bound in the module, because then the bound IS the
        # domain. Otherwise the module never says what the field ranges over.
        rec = extract_record_alphabet(code)
        summary["input_alphabet_records"] = rec["sets"]
        if rec["sets"] and not rec["unresolved"]:
            rec_tla = record_alphabet_tla(rec["sets"])
            alphabet_tla = f"{alphabet_tla} \\cup {rec_tla}" if alphabet_tla else rec_tla
        else:
            summary["outcome"] = "input_alphabet_unknown"
            summary["error"] = (
                "module matches pendingInput against records, but no bound is "
                "stated for field(s) " + ", ".join(rec["unresolved"])
                + " - the module never says what they range over, and "
                  "inventing a domain would change what is checked")
            return summary

    if not alphabet_tla:
        summary["outcome"] = "input_alphabet_unknown"
        summary["error"] = (
            "module declares the input shape but no guard compares "
            "pendingInput against a literal, so its input alphabet is empty "
            "- no input alphabet can be recovered")
        return summary

    module = plan["module_name"]
    detector_path = tla_path.with_name(f"{module}_MC.tla")
    has_operational = declares_operational(code)
    summary["declares_operational"] = has_operational
    detector_path.write_text(
        gd.build_detector_module(module, alphabet_tla, has_operational),
        encoding="utf-8")

    for i, cfg in enumerate(plan["configs"]):
        # Re-render the constants for the wrapper, which EXTENDS the module and
        # so must supply the same values.
        const_lines = [f"    {c} = {constant_value(c, plan['constant_kinds'][c], cfg['bool_assignment'].get(c, True))}"
                       for c in plan["constants"]]
        # Each invariant gets its own run: TLC stops at the first violation,
        # so checking both together would let the weak one mask the strong.
        invariants = [None]
        if has_operational:
            invariants.append(gd.OPERATIONAL_INVARIANT)
        for inv in invariants:
          suffix = "" if inv is None else "_op"
          cfg_path = detector_path.with_name(f"{module}_MC__mc{i}{suffix}.cfg")
          cfg_path.write_text(
            gd.build_detector_config(plan, const_lines, bind_alphabet=True,
                                     invariant=inv),
            encoding="utf-8")
        # -deadlock DISABLES deadlock checking: a stopped protocol is not a
        # finding, and leaving it on reproduces exactly the noise this replaced.
          run = run_tlc_once(detector_path, cfg_path, tla_tools_jar,
                             timeout=timeout, extra_args=["-deadlock"])
          run["bool_assignment"] = cfg["bool_assignment"]
          run["operational_only"] = inv is not None
          summary["runs"].append(run)
          if not keep_cfg:
              cfg_path.unlink(missing_ok=True)

    outcomes = [r["outcome"] for r in summary["runs"]]
    # Worst-news-first: a gap found under any flag setting is the headline.
    for priority in ("unhandled_input", "deadlock", "invariant_violated",
                     "unbounded_quantifier",
                     "number_too_large", "incomplete_next_state",
                     "runtime_error", "tlc_error", "timeout", "no_shape",
                     "input_alphabet_unknown",
                     "no_error"):
        if priority in outcomes:
            summary["outcome"] = priority
            break
    summary["gap_candidate"] = summary["outcome"] == "unhandled_input"
    # Rule 4b ranking. A violation of the operational invariant means the event
    # arrived in a state the module says the device genuinely sits in, not in
    # setup scaffolding. This RANKS findings; it never discards one. The
    # ground-truth ArmFailSafe gap arrives in its initial state, so "weak" is
    # not the same as "wrong" - see tests/test_gap_detector.py.
    if summary["gap_candidate"]:
        if not has_operational:
            summary["gap_strength"] = "unranked"
        elif any(r["outcome"] == "unhandled_input" and r.get("operational_only")
                 for r in summary["runs"]):
            summary["gap_strength"] = "operational"
        else:
            summary["gap_strength"] = "setup_only"
    return summary


def main():
    import argparse
    ap = argparse.ArgumentParser(description="Run TLC on one generated TLA+ module.")
    ap.add_argument("tla_file")
    ap.add_argument("--tla-tools", default="tla2tools.jar")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--max-configs", type=int, default=4)
    ap.add_argument("--json", action="store_true", help="Print the full result dict as JSON")
    args = ap.parse_args()

    result = check_module(args.tla_file, args.tla_tools,
                          timeout=args.timeout, max_configs=args.max_configs)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"module  : {result['module_name']}")
        print(f"outcome : {result['outcome']}")
        if result.get("constant_kinds"):
            print("constants:", ", ".join(f"{k}={v}" for k, v in result["constant_kinds"].items()))
        for r in result.get("runs", []):
            flags = r.get("bool_assignment") or {}
            label = ", ".join(f"{k}={v}" for k, v in flags.items()) or "no boolean flags"
            print(f"  [{r['outcome']:<18}] {label}"
                  f"  states={r.get('distinct_states', '-')} depth={r.get('search_depth', '-')}")
            if r.get("trace"):
                print("    --- trace ---")
                for line in r["trace"].splitlines()[:30]:
                    print("    " + line)
            elif r.get("error_excerpt"):
                for line in r["error_excerpt"].splitlines()[:10]:
                    print("    " + line)


if __name__ == "__main__":
    main()
