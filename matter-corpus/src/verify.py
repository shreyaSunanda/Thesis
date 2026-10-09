"""
Verification stage of the pipeline: SANY -> TLC -> (automatic decomposition
when TLC exceeds its budget) -> findings report.

Usage:
    python -m src.verify tla_models/core_4.20.3_session/PAFTPSessionNaive.tla
    python -m src.verify Model.tla --cfg Model.cfg --max-states 200000 --timeout 300
    python -m src.verify Model.tla --decompose always      # skip the full run
    python -m src.verify Model.tla --compare               # full AND decomposed, diffed

Decision rule (--decompose auto, the default): run TLC on the whole model
first, under the budget. Only if it does not finish -- distinct states over
--max-states, wall clock over --timeout, or JVM out of memory -- is the
model decomposed (src/decomposition). Small models are checked exactly as
before; decomposition never replaces a full check that fits.

Outputs, under --out-dir (default: <model dir>/verification/<Model>/):
    report.json   machine-readable: every stage's status, plan, pieces, findings
    report.md     the same for humans
    pieces/       generated submodules (+ .cfg), when decomposition ran
    replay/       generated full-model replay modules, when decomposition ran
"""
import argparse
import json
import sys
import time
from dataclasses import asdict
from pathlib import Path
from typing import List

from src.decomposition.decompose import (
    DecompositionResult, decompose_and_check, finding_key, findings_from_full_run,
)
from src.decomposition.planner import DecompositionUnsupported, make_plan
from src.tla.cfg import parse_cfg_file
from src.tla.sany_ast import SanyError, load_model
from src.tla.tools import run_sany, run_tlc

DEFAULT_MAX_STATES = 1_000_000
DEFAULT_TIMEOUT = 600


def verify_model(
    tla_path,
    cfg_path=None,
    out_dir=None,
    *,
    max_states: int = DEFAULT_MAX_STATES,
    timeout: int = DEFAULT_TIMEOUT,
    decompose: str = "auto",          # "auto" | "always" | "never"
    compare: bool = False,
) -> dict:
    t0 = time.time()
    tla_path = Path(tla_path).resolve()
    cfg_path = Path(cfg_path).resolve() if cfg_path else tla_path.with_suffix(".cfg")
    out_dir = Path(out_dir) if out_dir else tla_path.parent / "verification" / tla_path.stem
    out_dir.mkdir(parents=True, exist_ok=True)

    report: dict = {
        "model": str(tla_path), "cfg": str(cfg_path),
        "budget": {"max_states": max_states, "timeout_seconds": timeout},
        "sany": None, "full_check": None, "decomposition": None,
        "findings": [], "notes": [], "outcome": None,
    }

    def finish(outcome: str) -> dict:
        report["outcome"] = outcome
        report["elapsed_seconds"] = round(time.time() - t0, 1)
        _write_reports(report, out_dir)
        return report

    # 1. SANY ------------------------------------------------------------
    print(f"[verify] SANY {tla_path.name} ...")
    sany = run_sany(tla_path)
    report["sany"] = {"ok": sany.ok, "output": None if sany.ok else sany.output[-4000:]}
    if not sany.ok:
        print("[verify]   -> syntax/semantic errors, stopping")
        return finish("sany_error")
    if not cfg_path.exists():
        report["notes"].append(f"no TLC config at {cfg_path}")
        return finish("missing_cfg")
    cfg = parse_cfg_file(cfg_path)

    # Findings are keyed on the plan's hub variables when the model can be
    # split (so full and decomposed runs are comparable), otherwise on its
    # control variables.
    model = None
    key_vars: List[str] = []
    plan_error = None
    try:
        model = load_model(tla_path)
        key_vars = control_variables(model, cfg)
        key_vars = make_plan(model, cfg).hubs
    except (SanyError, DecompositionUnsupported) as e:
        plan_error = str(e)

    # 2. Full TLC under budget ---------------------------------------------
    full = None
    if decompose != "always" or compare:
        print(f"[verify] TLC on the full model (budget: {max_states:,} states, {timeout}s) ...")
        full = run_tlc(tla_path, cfg_path, max_states=max_states, timeout=timeout,
                       group_by=lambda v: finding_key(v, key_vars))
        report["full_check"] = {
            "status": full.status, "distinct_states": full.distinct_states,
            "violating_states": full.violation_count, "errors": full.errors[:5],
            "elapsed_seconds": full.elapsed_seconds,
        }
        print(f"[verify]   -> {full.status}, {full.distinct_states} distinct states")
        if full.status == "error":
            return finish("tlc_error")

    need_decomp = (
        decompose == "always" or compare
        or (decompose == "auto" and full is not None and not full.completed)
    )
    if full is not None and full.completed and not compare:
        report["findings"] = [f.to_dict() for f in findings_from_full_run(full, key_vars)]
        if decompose == "auto":
            report["notes"].append("full model fit within the budget; no decomposition needed")
        return finish("checked_full")
    if not need_decomp:
        return finish(f"full_check_{full.status}")

    # 3. Decomposition --------------------------------------------------
    if model is None:
        report["notes"].append(f"cannot decompose: {plan_error}")
        return finish("state_space_too_large_not_decomposable")
    print("[verify] decomposing ...")
    dec = decompose_and_check(model, cfg, out_dir, max_states=max_states, timeout=timeout)
    report["decomposition"] = _decomp_dict(dec)
    if dec.error:
        print(f"[verify]   -> not decomposable: {dec.error}")
        report["notes"].append(f"decomposition failed: {dec.error}")
        return finish("state_space_too_large_not_decomposable")
    for p in dec.pieces:
        print(f"[verify]   {p.name}: {p.status}, {p.distinct_states} states, "
              f"{p.violations} violating, replay {p.replay_status}")
    report["findings"] = [f.to_dict() for f in dec.findings]
    if "Deadlock" not in [f.key[0] for f in dec.findings] and cfg.check_deadlock is not False:
        report["notes"].append(
            "deadlock is a whole-model property and is not checked on decomposed pieces")
    if not dec.replay_complete:
        report["notes"].append(
            "some replays exceeded the budget; affected findings are reported as "
            "'unconfirmed' (none are dropped)")
    if not dec.complete:
        report["notes"].append(
            "INCOMPLETE: at least one piece or replay exceeded the budget; findings may be "
            "missing (consider a larger budget or a finer split)")

    if compare and full is not None:
        report["comparison"] = _compare(full, dec, key_vars)
    return finish("checked_decomposed" if dec.complete else "decomposed_incomplete")


def control_variables(model, cfg) -> List[str]:
    """
    Variables read by a majority of Next's actions: the protocol state and
    the pending event/message in house-style models, i.e. exactly what a
    finding is about ("event E is unhandled in state S"). Used to key
    findings when the model has no decomposition plan.
    """
    from collections import Counter
    from src.decomposition.footprint import FootprintAnalyzer, flatten_actions
    from src.decomposition.planner import spec_parts
    fa = FootprintAnalyzer(model)
    acts = flatten_actions(model, spec_parts(model, cfg).next, fa)
    reads = Counter(v for a in acts for v in a.footprint.reads)
    return sorted(model.variables[v] for v, n in reads.items() if n * 2 > len(acts))


def _decomp_dict(dec: DecompositionResult) -> dict:
    return {
        "plan": dec.plan.to_dict() if dec.plan else None,
        "pieces": [asdict(p) for p in dec.pieces],
        "complete": dec.complete,
        "replay_complete": dec.replay_complete,
        "largest_piece_states": dec.largest_piece_states,
        "error": dec.error,
    }


def _compare(full, dec: DecompositionResult, hubs: List[str]) -> dict:
    if not full.completed:
        return {"available": False, "reason": f"full check did not finish ({full.status})"}
    f_keys = {f.key for f in findings_from_full_run(full, hubs)}
    confirmed = {f.key for f in dec.findings if f.status == "confirmed"}
    unconfirmed = {f.key for f in dec.findings if f.status == "unconfirmed"}
    return {
        "available": True,
        "full_findings": len(f_keys),
        "decomposed_confirmed": len(confirmed),
        "decomposed_unconfirmed": len(unconfirmed),
        "missed_by_decomposition": [list(k) for k in sorted(f_keys - confirmed - unconfirmed)],
        "confirmed_but_not_in_full": [list(k) for k in sorted(confirmed - f_keys)],
        "lossless": not (f_keys - confirmed - unconfirmed) and not (confirmed - f_keys),
        "full_states": full.distinct_states,
        "largest_piece_states": dec.largest_piece_states,
    }


# ------------------------------------------------------------------ report

def _write_reports(report: dict, out_dir: Path):
    (out_dir / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (out_dir / "report.md").write_text(_markdown(report), encoding="utf-8")


def _markdown(r: dict) -> str:
    L = [f"# Verification report: `{Path(r['model']).name}`", "",
         f"**Outcome:** `{r['outcome']}`  ", f"**Budget:** {r['budget']['max_states']:,} distinct "
         f"states / {r['budget']['timeout_seconds']}s per TLC run", ""]
    if r["sany"] and not r["sany"]["ok"]:
        L += ["## SANY errors", "", "```", r["sany"]["output"] or "", "```", ""]
    fc = r.get("full_check")
    if fc:
        L += ["## Full-model TLC", "", f"- status: `{fc['status']}`",
              f"- distinct states: {fc['distinct_states']}",
              f"- violating states: {fc['violating_states']}", ""]
    dec = r.get("decomposition")
    if dec and dec.get("plan"):
        p = dec["plan"]
        L += ["## Decomposition", "", f"Hub variables (in every piece): `{', '.join(p['hubs'])}`",
              "", "| piece | own variables | status | distinct states | violating | replay |",
              "|---|---|---|---|---|---|"]
        for piece in dec["pieces"]:
            own = sorted(set(piece["variables"]) - set(p["hubs"]))
            L.append(f"| `{piece['name']}` | {', '.join(own)} | {piece['status']} | "
                     f"{piece['distinct_states']} | {piece['violations']} | {piece['replay_status']} |")
        L.append("")
    if dec and dec.get("error"):
        L += [f"Decomposition not possible: {dec['error']}", ""]
    cmp_ = r.get("comparison")
    if cmp_ and cmp_.get("available"):
        L += ["## Full vs. decomposed", "",
              f"- full-model findings: {cmp_['full_findings']}",
              f"- decomposed, confirmed: {cmp_['decomposed_confirmed']}; unconfirmed: "
              f"{cmp_['decomposed_unconfirmed']}",
              f"- missed by decomposition: {len(cmp_['missed_by_decomposition'])}",
              f"- lossless: **{cmp_['lossless']}**",
              f"- states: full {cmp_['full_states']} vs. largest piece {cmp_['largest_piece_states']}",
              ""]
    L += [f"## Findings ({len(r['findings'])})", ""]
    if r["findings"]:
        L += ["| status | invariant | violating action | state before the step |", "|---|---|---|---|"]
        for f in r["findings"]:
            pre = ", ".join(f"{k}={v}" for k, v in f["pre_state"].items()) or "-"
            L.append(f"| {f['status']} | {f['invariant']} | {f['action']} | {pre} |")
        L += ["", "*confirmed* = reproduced on the full model (a concrete full-model trace is in "
                  "report.json); *unconfirmed* = seen only in an abstracted piece, needs review.", ""]
    if r["notes"]:
        L += ["## Notes", ""] + [f"- {n}" for n in r["notes"]] + [""]
    return "\n".join(L)


def main(argv=None):
    ap = argparse.ArgumentParser(description="SANY + TLC with automatic decomposition on "
                                             "state-space explosion.")
    ap.add_argument("tla", help="TLA+ module to check")
    ap.add_argument("--cfg", help="TLC config (default: same name, .cfg)")
    ap.add_argument("--out-dir", help="report directory (default: <model dir>/verification/<Model>/)")
    ap.add_argument("--max-states", type=int, default=DEFAULT_MAX_STATES,
                    help=f"distinct-state budget per TLC run (default {DEFAULT_MAX_STATES:,})")
    ap.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT,
                    help=f"wall-clock budget per TLC run in seconds (default {DEFAULT_TIMEOUT})")
    ap.add_argument("--decompose", choices=["auto", "always", "never"], default="auto",
                    help="auto (default): only when the full check exceeds the budget")
    ap.add_argument("--compare", action="store_true",
                    help="run both the full and the decomposed check and diff their findings")
    a = ap.parse_args(argv)
    r = verify_model(a.tla, a.cfg, a.out_dir, max_states=a.max_states, timeout=a.timeout,
                     decompose=a.decompose, compare=a.compare)
    out_dir = Path(a.out_dir) if a.out_dir else Path(a.tla).resolve().parent / "verification" / Path(a.tla).stem
    print(f"\n[verify] outcome: {r['outcome']}  ({len(r['findings'])} findings)")
    print(f"[verify] report: {out_dir / 'report.md'}")
    sys.exit(0 if r["outcome"] in ("checked_full", "checked_decomposed") else 1)


if __name__ == "__main__":
    main()
