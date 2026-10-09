"""
Orchestrates one decomposed check of a model:

    plan (planner.py) -> one piece per group (abstraction.py)
      -> SANY + TLC on each piece -> replay counterexamples on the full model
      (replay.py) -> merged, de-duplicated findings

Findings are keyed by (invariant, violating action, values of the hub
variables just before the violating step). For the house-style models that
key is exactly "(phase, event) is unhandled", i.e. the granularity the
thesis reports findings at, and the same key is computed for full-model
runs, so decomposed and undecomposed results can be compared directly.
"""
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from src.decomposition.abstraction import AbstractionError, build_submodule
from src.decomposition.planner import DecompositionUnsupported, Plan, make_plan, spec_parts
from src.decomposition.replay import replay
from src.tla.cfg import TLCConfig
from src.tla.sany_ast import Model
from src.tla.tools import TLCResult, TraceState, Violation, run_sany, run_tlc

FindingKey = Tuple[str, str, Tuple[Tuple[str, str], ...]]

# Counterexamples replayed per finding key and piece. More only matters when
# the shortest ones are all spurious; see replay.py on "unconfirmed".
TRACES_PER_KEY = 8


def finding_key(v: Violation, hubs: List[str]) -> FindingKey:
    last = v.trace[-1] if v.trace else TraceState("?", {})
    pre = v.trace[-2] if len(v.trace) >= 2 else last
    return (v.invariant, last.action,
            tuple((h, pre.values.get(h, "?")) for h in hubs))


def key_to_dict(k: FindingKey) -> dict:
    return {"invariant": k[0], "action": k[1], "pre_state": dict(k[2])}


@dataclass
class PieceResult:
    name: str
    variables: List[str]
    hidden: List[str]
    tla_path: str
    status: str
    distinct_states: Optional[int] = None
    violations: int = 0
    replay_status: Optional[str] = None
    errors: List[str] = field(default_factory=list)


@dataclass
class Finding:
    key: FindingKey
    status: str                      # "confirmed" | "unconfirmed"
    found_in: List[str]
    trace: List[TraceState]          # full-model trace if confirmed, else the piece's

    def to_dict(self) -> dict:
        d = key_to_dict(self.key)
        d.update(status=self.status, found_in=self.found_in,
                 trace=[{"action": s.action, "state": s.values} for s in self.trace])
        return d


@dataclass
class DecompositionResult:
    plan: Optional[Plan]
    pieces: List[PieceResult]
    findings: List[Finding]
    # Every piece finished within budget: no finding can be missing. A replay
    # running out of budget cannot lose findings, only leave some
    # "unconfirmed", so it is tracked separately.
    complete: bool
    error: Optional[str] = None
    replay_complete: bool = True

    @property
    def largest_piece_states(self) -> Optional[int]:
        sizes = [p.distinct_states for p in self.pieces if p.distinct_states is not None]
        return max(sizes) if sizes else None


def decompose_and_check(model: Model, cfg: TLCConfig, out_dir: Path, *,
                        max_states: int, timeout: int) -> DecompositionResult:
    try:
        plan = make_plan(model, cfg)
        parts = spec_parts(model, cfg)
    except DecompositionUnsupported as e:
        return DecompositionResult(None, [], [], False, error=str(e))

    pieces_dir = out_dir / "pieces"
    pieces_dir.mkdir(parents=True, exist_ok=True)
    all_vars = set(model.variables.values())
    pieces: List[PieceResult] = []
    per_key: Dict[FindingKey, Dict[str, List[List[TraceState]]]] = {}
    complete = True

    for i, g in enumerate(plan.groups, 1):
        hidden = sorted(all_vars - set(plan.hubs) - set(g.variables))
        name = f"{model.module_name}__part{i}"
        try:
            sub = build_submodule(model, cfg, parts, hidden, name)
        except AbstractionError as e:
            return DecompositionResult(plan, pieces, [], False,
                                       error=f"piece {i} ({', '.join(g.variables)}): {e}")
        tla = pieces_dir / f"{name}.tla"
        tla.write_text(sub.text, encoding="utf-8")
        (pieces_dir / f"{name}.cfg").write_text(sub.cfg.render(), encoding="utf-8")
        # Sibling modules the original EXTENDS must be visible to the piece.
        for f in model.tla_path.parent.glob("*.tla"):
            if f.stem != model.module_name and not (pieces_dir / f.name).exists():
                (pieces_dir / f.name).write_text(f.read_text(encoding="utf-8"), encoding="utf-8")

        pr = PieceResult(name, sub.variables, sub.hidden, str(tla), status="pending")
        pieces.append(pr)
        sany = run_sany(tla)
        if not sany.ok:
            pr.status = "sany_error"
            pr.errors.append(sany.output[-3000:])
            return DecompositionResult(plan, pieces, [], False,
                                       error=f"generated piece {name} failed SANY (a bug in the "
                                             "abstraction step, please report the model)")
        res = run_tlc(tla, pieces_dir / f"{name}.cfg", max_states=max_states, timeout=timeout,
                      check_deadlock=False, group_by=lambda v: finding_key(v, plan.hubs),
                      traces_per_group=TRACES_PER_KEY)
        pr.status, pr.distinct_states, pr.violations = res.status, res.distinct_states, res.violation_count
        pr.errors = res.errors[:5]
        if not res.completed:
            complete = False
        for v in res.violations:
            k = finding_key(v, plan.hubs)
            per_key.setdefault(k, {}).setdefault(name, []).append(v.trace)

    # Replay: per piece, the shortest few traces of every key it found;
    # strict round first, permissive round only for what is still unconfirmed.
    confirmed: Dict[FindingKey, List[TraceState]] = {}
    replay_complete = True
    for pr in pieces:
        selected: List[Tuple[FindingKey, List[TraceState]]] = []
        for k, by_piece in per_key.items():
            for t in sorted(by_piece.get(pr.name, []), key=len)[:TRACES_PER_KEY]:
                selected.append((k, t))
        if not selected:
            pr.replay_status = "nothing to replay"
            continue
        statuses = []
        for round_name, permissive in (("strict", False), ("permissive", True)):
            todo = [i for i, (k, _) in enumerate(selected) if k not in confirmed]
            if not todo:
                break
            out = replay(model, cfg, parts.init.name, parts.next.name, pr.variables,
                         [selected[i][1] for i in todo], out_dir / "replay" / pr.name / round_name,
                         max_states=max_states, timeout=timeout, allow_hidden_steps=permissive)
            statuses.append(f"{round_name}: {out.tlc.status}")
            if not out.tlc.completed:
                replay_complete = False
                pr.errors += out.tlc.errors[:3]
            for j in out.confirmed:
                confirmed.setdefault(selected[todo[j]][0], out.full_traces[j])
        pr.replay_status = "; ".join(statuses)

    findings = []
    for k, by_piece in sorted(per_key.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2])):
        if k in confirmed:
            findings.append(Finding(k, "confirmed", sorted(by_piece), confirmed[k]))
        else:
            some = min((t for ts in by_piece.values() for t in ts), key=len)
            findings.append(Finding(k, "unconfirmed", sorted(by_piece), some))
    return DecompositionResult(plan, pieces, findings, complete, replay_complete=replay_complete)


def findings_from_full_run(res: TLCResult, key_vars: List[str]) -> List[Finding]:
    """
    Groups a full-model run's violations into findings, keyed on `key_vars`:
    the plan's hubs when a plan exists (so the keys match decomposed runs),
    otherwise the model's control variables (see verify.control_variables).
    """
    by_key: Dict[FindingKey, List[TraceState]] = {}
    for v in res.violations:
        k = finding_key(v, key_vars)
        if k not in by_key or len(v.trace) < len(by_key[k]):
            by_key[k] = v.trace
    return [Finding(k, "confirmed", ["full model"], t) for k, t in sorted(by_key.items())]
