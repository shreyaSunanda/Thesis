"""
Re-run generation for just the units that failed in a previous batch.

A full `run_batch.py` pass is resumable but all-or-nothing per unit: once a
unit is in results.jsonl it is never retried, even if it only landed there as
a SANY failure. This script targets exactly those rows — regenerating them
(e.g. after tightening the prompt template) and REPLACING their entry in the
log in place, so the log stays one-row-per-unit and the batch summary numbers
keep meaning what they say.

Also retries transient provider errors (429 rate-limit, 5xx) with exponential
backoff, which the plain batch runner does not: the 40-unit ch4/ch5 run lost
three units purely to Vertex quota pressure at --sleep 2.

    python retry_failures.py --out-dir models/generated/ch45
    python retry_failures.py --out-dir models/generated/ch45 --only core_4.12.1,core_4.6.7
"""
import argparse
import json
import shutil
import time
import traceback
from pathlib import Path

from src.generation.generate_tla import generate_for_unit

_TRANSIENT = ("429", "500", "502", "503", "504", "RESOURCE_EXHAUSTED",
              "UNAVAILABLE", "timed out", "Network error")


def is_transient(msg: str) -> bool:
    return any(t.lower() in msg.lower() for t in _TRANSIENT)


def read_log(path: Path) -> list:
    return [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def failed(row: dict) -> bool:
    return not (row.get("generated") and row.get("sany", {}).get("passed"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="models/generated/ch45")
    ap.add_argument("--corpus-dir", default="data/processed/core")
    ap.add_argument("--provider", default="vertex-gemini")
    ap.add_argument("--model", default="gemini-3.1-pro-preview")
    ap.add_argument("--tla-tools", default="tla2tools.jar")
    ap.add_argument("--log", default=None)
    ap.add_argument("--only", default=None, help="Comma-separated unit ids to retry instead of 'all failures'")
    ap.add_argument("--max-attempts", type=int, default=4, help="Attempts per unit on transient provider errors")
    ap.add_argument("--sleep", type=float, default=15.0, help="Seconds between units (Gemini quota needs >> 2s)")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    log_path = Path(args.log) if args.log else out_dir / "results.jsonl"
    rows = read_log(log_path)
    by_id = {r["unit_id"]: r for r in rows}

    if args.only:
        targets = [u.strip() for u in args.only.split(",") if u.strip()]
    else:
        targets = [r["unit_id"] for r in rows if failed(r)]

    if not targets:
        print("[retry] nothing to retry — every unit in the log passed SANY.")
        return

    shutil.copy(log_path, log_path.with_suffix(".jsonl.bak"))
    print(f"[retry] {len(targets)} unit(s) to retry: {', '.join(targets)}")
    print(f"[retry] previous log backed up to {log_path.with_suffix('.jsonl.bak')}")

    for i, uid in enumerate(targets, 1):
        prev = by_id.get(uid, {})
        print(f"\n[retry] ({i}/{len(targets)}) {uid}", flush=True)
        result = None
        for attempt in range(1, args.max_attempts + 1):
            try:
                result = generate_for_unit(
                    unit_id=uid,
                    provider_name=args.provider,
                    model=args.model,
                    corpus_dir=args.corpus_dir,
                    out_dir=str(out_dir / uid),
                    tla_tools_jar=args.tla_tools,
                )
            except Exception as e:
                traceback.print_exc()
                result = {"unit_id": uid, "generated": False, "error": f"{type(e).__name__}: {e}"}

            err = "" if result.get("generated") else str(result.get("error", ""))
            if result.get("generated") or not is_transient(err) or attempt == args.max_attempts:
                break
            backoff = 15 * (2 ** (attempt - 1))
            print(f"[retry] transient provider error, attempt {attempt}/{args.max_attempts}; "
                  f"sleeping {backoff}s", flush=True)
            time.sleep(backoff)

        result["final_score"] = prev.get("final_score")
        result["title"] = prev.get("title")
        result["retry_of"] = "sany_fail" if failed(prev) else "manual"
        by_id[uid] = result
        print(f"[retry] {uid}: SANY {'PASS' if result.get('sany', {}).get('passed') else 'FAIL'}", flush=True)

        # Rewrite the whole log each time, so an interrupted retry run still
        # leaves a consistent, complete log behind.
        order = [r["unit_id"] for r in rows]
        with open(log_path, "w", encoding="utf-8") as f:
            for oid in order:
                f.write(json.dumps(by_id[oid]) + "\n")

        if i < len(targets):
            time.sleep(args.sleep)

    final = read_log(log_path)
    gen = [r for r in final if r.get("generated")]
    passed = [r for r in gen if r.get("sany", {}).get("passed")]
    print(f"\n[retry] DONE  total={len(final)}  generated={len(gen)}  "
          f"sany_pass={len(passed)}  sany_fail={len(gen) - len(passed)}", flush=True)
    for r in final:
        if failed(r):
            print(f"[retry] still failing: {r['unit_id']}")


if __name__ == "__main__":
    main()
