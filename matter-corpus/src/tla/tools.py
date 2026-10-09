"""
Thin wrappers around the TLA+ tools in tla2tools.jar: SANY (parse / semantic
check) and TLC (explicit-state model checking).

TLC is always run with a resource budget, because the point of running it
inside the pipeline is to *notice* state-space explosion and hand the model
to src.decomposition instead of letting the JVM grind until it runs out of
memory. The budget has three independent limits, whichever trips first:

  * max_states - enforced inside TLC itself: the model is wrapped in a module
                 whose CONSTRAINT asserts TLCGet("distinct") <= max_states, so
                 TLC stops deterministically at that many distinct states.
  * timeout    - wall-clock seconds, enforced from Python.
  * heap       - JVM -Xmx (env TLC_HEAP, e.g. "4g"); an OutOfMemoryError is
                 reported as its own status rather than a generic failure.

TLC runs with -tool so its output is machine-readable message blocks, and
-continue so *every* reachable violation is collected, not just the first:
the decomposition's losslessness check compares the full set of findings.
"""
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, Hashable, List, Optional

_REPO_ROOT = Path(__file__).resolve().parents[2]

BUDGET_MARKER = "TLC_STATE_BUDGET_EXCEEDED"


def tla2tools_jar() -> Path:
    jar = Path(os.environ.get("TLA2TOOLS_JAR", _REPO_ROOT / "tla2tools.jar"))
    if not jar.exists():
        raise FileNotFoundError(f"tla2tools.jar not found at {jar} (set TLA2TOOLS_JAR)")
    return jar


def java_cmd() -> List[str]:
    cmd = [os.environ.get("JAVA", "java"), "-XX:+UseParallelGC"]
    heap = os.environ.get("TLC_HEAP")
    if heap:
        cmd.append(f"-Xmx{heap}")
    return cmd


# --------------------------------------------------------------------- SANY

@dataclass
class SanyResult:
    ok: bool
    output: str


def run_sany(tla_path, timeout: int = 120) -> SanyResult:
    tla_path = Path(tla_path).resolve()
    proc = subprocess.run(
        java_cmd() + ["-cp", str(tla2tools_jar()), "tla2sany.SANY", tla_path.name],
        cwd=tla_path.parent, capture_output=True, text=True, timeout=timeout,
    )
    out = proc.stdout + proc.stderr
    # SANY exits 0 even on some semantic errors in older builds; check text too.
    failed = proc.returncode != 0 or re.search(
        r"\*\*\* Errors:|Parse Error|Semantic errors|Fatal errors|Could not parse", out)
    return SanyResult(ok=not failed, output=out)


# ---------------------------------------------------------------------- TLC

@dataclass
class TraceState:
    action: str                 # "Init" for the initial state
    values: Dict[str, str]      # variable -> TLA+ value text, exactly as TLC printed it


@dataclass
class Violation:
    invariant: str
    trace: List[TraceState]


@dataclass
class TLCResult:
    # "ok" | "violations" | "budget_exceeded" | "timeout" | "out_of_memory" | "error"
    status: str
    distinct_states: Optional[int] = None
    states_generated: Optional[int] = None
    # Kept counterexamples (all of them, or the shortest few per group when
    # run_tlc was given group_by); violation_count counts every one TLC reported.
    violations: List[Violation] = field(default_factory=list)
    violation_count: int = 0
    errors: List[str] = field(default_factory=list)
    output: str = ""                 # tail of TLC's output, for diagnostics
    elapsed_seconds: Optional[float] = None

    @property
    def completed(self) -> bool:
        """TLC explored the whole (bounded) state space."""
        return self.status in ("ok", "violations")


def run_tlc(
    tla_path,
    cfg_path,
    *,
    max_states: Optional[int] = 1_000_000,
    timeout: Optional[int] = 600,
    collect_all: bool = True,
    group_by: Optional[Callable[[Violation], Hashable]] = None,
    traces_per_group: int = 8,
    check_deadlock: Optional[bool] = None,
    workers: str = "auto",
    stop_at_violations: bool = True,
) -> TLCResult:
    """
    Model-checks `tla_path` with `cfg_path` under the budget described in the
    module docstring. Sibling .tla files are copied alongside so EXTENDS of
    local modules keeps working; nothing is written into the model's own
    directory (TLC's states/ scratch dir lives in a temp dir too).

    check_deadlock: None = whatever the .cfg says (TLC default: on),
    False = pass -deadlock (do not report deadlocks).

    stop_at_violations: every INVARIANT is also added as a CONSTRAINT, so a
    state that violates an invariant is reported but not expanded. Each
    reported violation is then a *primary* one -- the step that breaks the
    invariant from a state where all invariants held -- instead of TLC also
    re-reporting the same broken state after every unrelated later step
    (which -continue otherwise does). This is what makes findings from the
    full model and from decomposed pieces comparable one-to-one.

    group_by / traces_per_group: a model can have far more violating states
    than is useful to keep in memory. With group_by, every violation is
    still parsed and counted, but only the shortest traces_per_group traces
    of each group (e.g. each finding key) are kept. Nothing is capped
    globally: a global cap would silently drop whole findings.
    """
    import time

    tla_path = Path(tla_path).resolve()
    cfg_path = Path(cfg_path).resolve()
    module = tla_path.stem

    with tempfile.TemporaryDirectory(prefix="tlc_") as tmp:
        tmp = Path(tmp)
        for f in tla_path.parent.glob("*.tla"):
            shutil.copy(f, tmp / f.name)
        cfg_text = cfg_path.read_text(encoding="utf-8")
        if stop_at_violations:
            from src.tla.cfg import parse_cfg
            for inv in parse_cfg(cfg_text).invariants:
                cfg_text = cfg_text.rstrip() + f"\nCONSTRAINT {inv}\n"
        target = module
        if max_states is not None:
            target = f"{module}__Budget"
            (tmp / f"{target}.tla").write_text(
                f"---- MODULE {target} ----\n"
                f"EXTENDS {module}, TLC\n"
                f"TLCStateBudget__ == Assert(TLCGet(\"distinct\") <= {int(max_states)}, "
                f"\"{BUDGET_MARKER}\")\n"
                "====\n",
                encoding="utf-8",
            )
            cfg_text = cfg_text.rstrip() + "\n\nCONSTRAINT TLCStateBudget__\n"
        (tmp / f"{target}.cfg").write_text(cfg_text, encoding="utf-8")

        cmd = java_cmd() + [
            "-cp", str(tla2tools_jar()), "tlc2.TLC", "-tool",
            "-workers", workers, "-metadir", str(tmp / "states"),
            "-config", f"{target}.cfg",
        ]
        if collect_all:
            cmd.append("-continue")
        if check_deadlock is False:
            cmd.append("-deadlock")
        cmd.append(f"{target}.tla")

        t0 = time.time()
        try:
            proc = subprocess.run(cmd, cwd=tmp, capture_output=True, text=True, timeout=timeout)
            out = proc.stdout + proc.stderr
            timed_out = False
        except subprocess.TimeoutExpired as e:
            out = _decode(e.stdout) + _decode(e.stderr)
            timed_out = True
        elapsed = time.time() - t0

    result = parse_tool_output(out, group_by=group_by, traces_per_group=traces_per_group)
    result.elapsed_seconds = round(elapsed, 2)
    if timed_out:
        result.status = "timeout"
    elif BUDGET_MARKER in out:
        result.status = "budget_exceeded"
        # TLC follows the failed Assert with a stack-position message that
        # points into the generated wrapper -- noise, not a model error.
        result.errors = [e for e in result.errors if "__Budget" not in e]
    elif "OutOfMemoryError" in out or "Java heap space" in out:
        result.status = "out_of_memory"
    elif result.errors:
        result.status = "error"
    elif result.violations:
        result.status = "violations"
    elif "Model checking completed" in out or result.distinct_states is not None:
        result.status = "ok"
    else:
        result.status = "error"
        result.errors.append("TLC produced no recognisable result")
    return result


def _decode(b) -> str:
    if b is None:
        return ""
    return b.decode(errors="replace") if isinstance(b, bytes) else b


_MSG = re.compile(r"@!@!@STARTMSG (\d+):(\d+) @!@!@\n(.*?)@!@!@ENDMSG \1 @!@!@", re.S)

# tlc2.output.EC codes used below.
_INVARIANT_VIOLATED = {2107, 2110}        # initial state / behavior
_DEADLOCK = 2114
_STATE = 2217
_STATS = 2199
_CLASS_ERROR = 1
_TRACE_START = {2107, 2110, 2114, 2116, 2111, 2112}


def parse_tool_output(out: str, group_by: Optional[Callable[[Violation], Hashable]] = None,
                      traces_per_group: int = 8) -> TLCResult:
    res = TLCResult(status="error", output=out[-20000:])
    groups: Dict[Hashable, List[Violation]] = {}
    kept: List[Violation] = []
    current: Optional[Violation] = None

    def finish(v: Optional[Violation]):
        if v is None:
            return
        res.violation_count += 1
        if group_by is None:
            kept.append(v)
            return
        g = groups.setdefault(group_by(v), [])
        g.append(v)
        if len(g) > traces_per_group:
            g.sort(key=lambda x: len(x.trace))
            g.pop()

    for code_s, cls_s, body in _MSG.findall(out):
        code, cls = int(code_s), int(cls_s)
        body = body.strip("\n")
        if code in _INVARIANT_VIOLATED:
            finish(current)
            m = re.search(r"Invariant (\S+) is violated", body)
            current = Violation(invariant=m.group(1) if m else "?", trace=[])
        elif code == _DEADLOCK:
            finish(current)
            current = Violation(invariant="Deadlock", trace=[])
        elif code == _STATE:
            if current is not None:
                current.trace.append(_parse_state(body))
        elif code == _STATS:
            m = re.search(r"([\d,]+) states generated, ([\d,]+) distinct states found", body)
            if m:
                res.states_generated = int(m.group(1).replace(",", ""))
                res.distinct_states = int(m.group(2).replace(",", ""))
        elif cls == _CLASS_ERROR and code not in _TRACE_START and code != 2121:
            if BUDGET_MARKER not in body:
                res.errors.append(body)
            finish(current)
            current = None
    finish(current)
    res.violations = kept if group_by is None else [v for g in groups.values() for v in g]
    if res.distinct_states is None:
        # Budget/timeout stops never print the final 2199 line; fall back to
        # the last progress report so the caller still sees how far it got.
        for m in re.finditer(r"([\d,]+) states generated.*?([\d,]+) distinct states found", out):
            res.states_generated = int(m.group(1).replace(",", ""))
            res.distinct_states = int(m.group(2).replace(",", ""))
    return res


def _parse_state(body: str) -> TraceState:
    lines = body.split("\n")
    head = lines[0]
    m = re.match(r"^\d+: <(\S+)", head)
    if m:
        action = m.group(1)
        if action == "Initial":
            action = "Init"
    else:
        action = head.split(":", 1)[-1].strip()
    values: Dict[str, str] = {}
    entries: List[str] = []
    for line in lines[1:]:
        if line.startswith("/\\ ") or not entries:
            entries.append(line[3:] if line.startswith("/\\ ") else line)
        else:
            entries[-1] += "\n" + line
    for e in entries:
        if " = " in e:
            k, v = e.split(" = ", 1)
            values[k.strip()] = v.strip()
    return TraceState(action=action, values=values)
