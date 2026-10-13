"""
Batch-generate TLA+ models for every ranked candidate in a set of chapters.

Wraps generate_tla.generate_for_unit in a resumable loop: results are appended
to a JSONL log as each unit finishes, and re-running skips units already in
that log. A single provider failure (quota, timeout, truncated response) is
recorded and the run continues rather than losing the whole batch.

Each unit gets its OWN output directory, because the module name comes from
whatever the model declares inside the file — two sections that both declare
"---- MODULE Commissioning ----" would otherwise silently overwrite each other.

    python run_batch.py --chapters 4,5 \
        --provider vertex-gemini --model gemini-3.1-pro-preview \
        --tla-tools tla2tools.jar
"""
import argparse
import json
import time
import traceback
from pathlib import Path

from src.generation.generate_tla import generate_for_unit


def load_done(log_path: Path) -> set:
    if not log_path.exists():
        return set()
    done = set()
    for line in log_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            done.add(json.loads(line)["unit_id"])
        except (json.JSONDecodeError, KeyError):
            continue
    return done


def chapter_of(unit_id: str) -> str:
    return unit_id.split("_", 1)[1].split(".")[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chapters", default="4,5",
                    help="Comma-separated top-level chapters to include, e.g. '4,5'")
    ap.add_argument("--corpus-dir", default="data/processed/core")
    ap.add_argument("--provider", default="vertex-gemini")
    ap.add_argument("--model", default="gemini-3.1-pro-preview")
    ap.add_argument("--out-dir", default="models/generated/ch45")
    ap.add_argument("--tla-tools", default="tla2tools.jar")
    ap.add_argument("--log", default=None, help="JSONL result log (default: <out-dir>/results.jsonl)")
    ap.add_argument("--limit", type=int, default=None, help="Only run the first N pending units")
    ap.add_argument("--sleep", type=float, default=2.0, help="Seconds between calls")
    args = ap.parse_args()

    wanted = {c.strip() for c in args.chapters.split(",") if c.strip()}
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    log_path = Path(args.log) if args.log else out_dir / "results.jsonl"

    ranked = json.load(open(Path(args.corpus_dir) / "ranked_candidates.json", encoding="utf-8"))
    units = [r for r in ranked if chapter_of(r["id"]) in wanted]

    done = load_done(log_path)
    pending = [u for u in units if u["id"] not in done]
    if args.limit:
        pending = pending[:args.limit]

    print(f"[batch] chapters={sorted(wanted)} candidates={len(units)} "
          f"already_done={len(done)} to_run={len(pending)}", flush=True)

    for i, unit in enumerate(pending, 1):
        uid = unit["id"]
        print(f"\n[batch] ({i}/{len(pending)}) {uid}  score={unit.get('final_score')}", flush=True)
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

        result["final_score"] = unit.get("final_score")
        result["title"] = unit.get("title")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(result) + "\n")

        if i < len(pending):
            time.sleep(args.sleep)

    # Summary over the whole log, not just this invocation.
    rows = [json.loads(l) for l in log_path.read_text(encoding="utf-8").splitlines() if l.strip()]
    gen = [r for r in rows if r.get("generated")]
    passed = [r for r in gen if r.get("sany", {}).get("passed")]
    print(f"\n[batch] DONE  total={len(rows)}  generated={len(gen)}  "
          f"sany_pass={len(passed)}  sany_fail={len(gen) - len(passed)}  "
          f"failed_to_generate={len(rows) - len(gen)}", flush=True)
    print(f"[batch] log: {log_path}", flush=True)


if __name__ == "__main__":
    main()
