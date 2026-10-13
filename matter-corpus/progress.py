"""
Live progress view for run_batch.py. Reads the JSONL log, so it works while a
batch is still running and after it finishes.

    watch -n 10 '.venv/bin/python progress.py'
"""
import json
import sys
from pathlib import Path

log = Path(sys.argv[1] if len(sys.argv) > 1 else "models/generated/ch45/results.jsonl")
total = int(sys.argv[2]) if len(sys.argv) > 2 else 40

rows = []
if log.exists():
    for line in log.read_text(encoding="utf-8").splitlines():
        if line.strip():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass  # a row still being written

gen = [r for r in rows if r.get("generated")]
ok = [r for r in gen if r.get("sany", {}).get("passed")]
bad = [r for r in gen if not r.get("sany", {}).get("passed")]
err = [r for r in rows if not r.get("generated")]

done = len(rows)
bar = "#" * int(30 * done / total) + "." * (30 - int(30 * done / total))
print(f"[{bar}] {done}/{total}")
print(f"SANY pass {len(ok)}   fail {len(bad)}   generation errors {len(err)}")
print()
for r in rows:
    if not r.get("generated"):
        st = "ERR "
    elif r.get("sany", {}).get("passed"):
        st = "PASS"
    else:
        st = "FAIL"
    print(f"  {st}  {r['unit_id']:<18} {(r.get('title') or '')[:44]}")

if bad:
    print("\nSANY failures:")
    for r in bad:
        out = (r.get("sany", {}).get("output") or "").strip().splitlines()
        first = next((l for l in out if "Error" in l or "error" in l), out[0] if out else "")
        print(f"  {r['unit_id']:<18} {first[:70]}")
