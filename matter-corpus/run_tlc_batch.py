"""
Run TLC over every generated model that passed SANY, and rank what it found.

This is the step after run_batch.py: SANY says the modules are well-formed,
TLC says what their state spaces actually contain. The headline output is the
set of units whose models DEADLOCK - reachable states with no enabled next
action, i.e. candidate underspecified clauses worth manual B.4.3 review.

Resumable and log-shaped exactly like run_batch.py: results append to a JSONL
file, re-running skips units already recorded, and one unit blowing up never
costs the rest of the run.

    python run_tlc_batch.py --models-dir models/generated/ch45 --timeout 120
    python run_tlc_batch.py --models-dir models/generated/ch45 --only core_5.5
"""
import argparse
import json
import traceback
from pathlib import Path

from src.validation.run_tlc import check_module

# Reported worst-first: a deadlock is a candidate spec gap (the point of the
# exercise), a timeout means the model needs bounding before it can say
# anything, and tlc_error/config_error are harness problems, not findings.
_OUTCOME_ORDER = ["unhandled_input", "deadlock", "invariant_violated", "no_shape",
                  "input_alphabet_unknown",
                  "unbounded_quantifier",
                  "number_too_large", "incomplete_next_state", "runtime_error",
                  "timeout", "tlc_error",
                  "config_error", "no_error"]


def load_done(log_path: Path) -> set:
    if not log_path.exists():
        return set()
    done = set()
    for line in log_path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            try:
                done.add(json.loads(line)["unit_id"])
            except (json.JSONDecodeError, KeyError):
                continue
    return done


def collect_units(models_dir: Path, results_log: Path) -> list:
    """
    Pairs each SANY-passing unit with its .tla file.

    Reads tla_path straight out of the generation log rather than globbing,
    so a unit that was regenerated keeps pointing at the file that actually
    passed - and units that never passed SANY are skipped, since TLC cannot
    run on a module that does not parse.
    """
    units = []
    for line in results_log.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if not row.get("sany", {}).get("passed"):
            continue
        tla_path = Path(row["tla_path"])
        if not tla_path.exists():
            tla_path = models_dir / row["unit_id"] / tla_path.name
        if tla_path.exists():
            units.append({"unit_id": row["unit_id"], "title": row.get("title"),
                          "final_score": row.get("final_score"), "tla_path": tla_path})
    return units


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models-dir", default="models/generated/ch45")
    ap.add_argument("--results-log", default=None, help="Generation log (default: <models-dir>/results.jsonl)")
    ap.add_argument("--log", default=None, help="TLC result log (default: <models-dir>/tlc_results.jsonl)")
    ap.add_argument("--tla-tools", default="tla2tools.jar")
    ap.add_argument("--timeout", type=int, default=120, help="Per-TLC-run wall clock budget, seconds")
    ap.add_argument("--max-configs", type=int, default=4, help="Cap on boolean-flag combinations per module")
    ap.add_argument("--only", default=None, help="Comma-separated unit ids to run instead of all")
    ap.add_argument("--rerun", action="store_true", help="Ignore the existing log and re-check everything")
    args = ap.parse_args()

    models_dir = Path(args.models_dir)
    results_log = Path(args.results_log) if args.results_log else models_dir / "results.jsonl"
    log_path = Path(args.log) if args.log else models_dir / "tlc_results.jsonl"

    units = collect_units(models_dir, results_log)
    if args.only:
        wanted = {u.strip() for u in args.only.split(",") if u.strip()}
        units = [u for u in units if u["unit_id"] in wanted]

    done = set() if args.rerun else load_done(log_path)
    if args.rerun and log_path.exists():
        log_path.unlink()
    pending = [u for u in units if u["unit_id"] not in done]

    print(f"[tlc] sany_passing={len(units)}  already_checked={len(done)}  to_run={len(pending)}", flush=True)

    for i, unit in enumerate(pending, 1):
        uid = unit["unit_id"]
        print(f"\n[tlc] ({i}/{len(pending)}) {uid}  {unit['tla_path'].name}", flush=True)
        try:
            result = check_module(unit["tla_path"], args.tla_tools,
                                  timeout=args.timeout, max_configs=args.max_configs)
        except Exception as e:
            traceback.print_exc()
            result = {"outcome": "harness_error", "error": f"{type(e).__name__}: {e}"}
        result["unit_id"] = uid
        result["title"] = unit["title"]
        result["final_score"] = unit["final_score"]

        states = max((r.get("distinct_states", 0) for r in result.get("runs", [])), default=0)
        print(f"[tlc] {uid}: {result['outcome'].upper()}  "
              f"configs={len(result.get('runs', []))} max_distinct_states={states}", flush=True)

        with open(log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(result) + "\n")

    rows = [json.loads(l) for l in log_path.read_text(encoding="utf-8").splitlines() if l.strip()]
    counts = {}
    for r in rows:
        counts[r["outcome"]] = counts.get(r["outcome"], 0) + 1

    print("\n[tlc] ===== SUMMARY =====")
    for outcome in _OUTCOME_ORDER + sorted(set(counts) - set(_OUTCOME_ORDER)):
        if counts.get(outcome):
            print(f"[tlc]   {outcome:<19} {counts[outcome]}")

    gaps = [r for r in rows if r["outcome"] == "unhandled_input"]
    if gaps:
        print(f"\n[tlc] CANDIDATE SPEC GAPS ({len(gaps)}) - an event arrived that nothing handles:")
        for r in sorted(gaps, key=lambda x: -(x.get("final_score") or 0)):
            print(f"[tlc]   {r['unit_id']:<18} score={r.get('final_score')}  {r.get('title')}")
    print(f"\n[tlc] log: {log_path}")


if __name__ == "__main__":
    main()
