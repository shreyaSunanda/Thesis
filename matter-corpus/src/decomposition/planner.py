"""
Chooses how to split a model: a small set of *hub* variables shared by every
piece, and a partition of the remaining (*local*) variables into independent
groups. One submodule is generated per group, owning hubs + that group.

The split is driven purely by the model's own read/write structure, never
by naming conventions, so it applies equally to the hand-written models
(pendingEvent mailbox + phase variable) and to LLM-generated ones.

How groups are formed
---------------------
Two local variables must live in the same group when one action *writes*
one of them while reading or writing the other -- otherwise data would flow
between groups, which the abstraction step cannot represent (it would have
to give up). Actions that only write hubs (a catch-all UndefinedTransition
reading every guard, a timeout that just closes the session) create no
such tie: their reads of other groups' variables are abstracted soundly.
Each top-level conjunct of an invariant also ties its local variables
together, so every conjunct can be checked whole in some piece.

How hubs are chosen
-------------------
Greedily: repeatedly promote the variable touched by the most actions
(the mailbox, the protocol phase, ...) to hub, and keep the candidate that
minimises |hubs| + |largest group| while still producing >= 2 groups.
Variables no action ever writes are fixed after Init and are always hubs
(cheap, and it stops them tying unrelated groups together).

Soundness does not depend on these heuristics -- any hub/group choice is
checked soundly by src.decomposition.abstraction -- they only decide how
small and how precise the pieces are.
"""
from dataclasses import dataclass
from typing import Dict, FrozenSet, List, Optional, Set

from src.decomposition.footprint import Action, FootprintAnalyzer, flatten_actions, top_conjuncts
from src.tla.cfg import TLCConfig
from src.tla.sany_ast import Model, OpDef


class DecompositionUnsupported(Exception):
    """The model's shape is outside what automatic decomposition handles."""


@dataclass
class Group:
    variables: List[str]
    writers: List[str]        # actions that write at least one of these variables


@dataclass
class Plan:
    hubs: List[str]
    groups: List[Group]
    actions: List[str]
    rationale: str

    def to_dict(self) -> dict:
        return {
            "hubs": self.hubs,
            "groups": [{"variables": g.variables, "writers": g.writers} for g in self.groups],
            "actions": self.actions,
            "rationale": self.rationale,
        }


@dataclass
class SpecParts:
    init: OpDef
    next: OpDef
    spec: Optional[OpDef]


def spec_parts(model: Model, cfg: TLCConfig) -> SpecParts:
    """Resolves Init / Next from the cfg (INIT/NEXT, or SPECIFICATION's body)."""
    if cfg.init and cfg.next:
        i, n = model.def_by_name(cfg.init), model.def_by_name(cfg.next)
        if not (i and n):
            raise DecompositionUnsupported("INIT/NEXT in the cfg do not name operators of the module")
        return SpecParts(i, n, None)
    if not cfg.specification:
        raise DecompositionUnsupported("cfg has neither SPECIFICATION nor INIT/NEXT")
    spec = model.def_by_name(cfg.specification)
    if spec is None:
        raise DecompositionUnsupported(f"SPECIFICATION {cfg.specification} not found in module")

    init = nxt = None
    for c in top_conjuncts_temporal(model, model.body(spec)):
        if c.kind == "app" and c.op[0] == "def" and c.level <= 1 and init is None:
            init = model.defs[c.op[1]]
        elif c.kind == "app" and c.op == ("builtin", "[]"):
            sq = c.operands[0]
            if sq.kind == "app" and sq.op == ("builtin", "$SquareAct"):
                act = sq.operands[0]
                if act.kind == "app" and act.op[0] == "def" and model.defs[act.op[1]].arity == 0:
                    nxt = model.defs[act.op[1]]
    if init is None or nxt is None:
        raise DecompositionUnsupported(
            f"{spec.name} is not of the form `Init /\\ [][Next]_vars` with Init and Next "
            "named operators")
    return SpecParts(init, nxt, spec)


def top_conjuncts_temporal(model: Model, node):
    if node.kind == "app" and node.op[0] == "builtin" and node.op[1] in ("\\land", "$ConjList"):
        return [c for o in node.operands for c in top_conjuncts_temporal(model, o)]
    return [node]


def make_plan(model: Model, cfg: TLCConfig, max_hub_fraction: float = 0.34) -> Plan:
    if cfg.properties:
        raise DecompositionUnsupported(
            "temporal PROPERTY checking does not decompose this way (safety invariants only)")
    if model.extends_has_instances:
        raise DecompositionUnsupported("module uses INSTANCE; not supported")

    fa = FootprintAnalyzer(model)
    parts = spec_parts(model, cfg)
    actions = flatten_actions(model, parts.next, fa)
    var_uids = set(model.variables)
    names = model.variables

    # Invariant / constraint conjuncts: each must end up whole in one piece.
    conj_fps = []
    for inv in cfg.invariants + cfg.constraints:
        d = model.def_by_name(inv)
        if d is None:
            raise DecompositionUnsupported(f"INVARIANT/CONSTRAINT {inv} not found in module")
        for c in top_conjuncts(model, model.body(d)):
            conj_fps.append(fa.of(c).mentions)

    written = set().union(*(a.footprint.writes for a in actions)) if actions else set()
    frozen = var_uids - written

    degree: Dict[int, int] = {v: 0 for v in var_uids}
    for a in actions:
        # Frames don't count: in TLA+ every action mentions every variable
        # (UNCHANGED ...), which says nothing about what it depends on.
        for v in a.footprint.reads | a.footprint.writes:
            degree[v] += 1
    order = sorted(var_uids - frozen, key=lambda v: (-degree[v], names[v]))
    max_hubs = max(1, int(len(var_uids) * max_hub_fraction))

    best = None
    hubs: Set[int] = set(frozen)
    for k in range(0, min(max_hubs, len(order)) + 1):
        if k > 0:
            hubs = set(frozen) | set(order[:k])
        groups = _components(var_uids - hubs, hubs, actions, conj_fps)
        if len(groups) >= 2:
            cost = len(hubs - frozen) + max(len(g) for g in groups)
            if best is None or cost < best[0]:
                best = (cost, set(hubs), groups)

    if best is None:
        raise DecompositionUnsupported(
            "no split found: every choice of up to "
            f"{max_hubs} hub variable(s) leaves all other variables data-dependent on each other")

    _, hubs, groups = best
    out_groups = []
    for g in sorted(groups, key=lambda g: sorted(names[v] for v in g)):
        writers = [a.name for a in actions if a.footprint.writes & g]
        out_groups.append(Group(sorted(names[v] for v in g), sorted(set(writers))))
    hub_names = sorted(names[v] for v in hubs)
    rationale = (
        f"{len(out_groups)} independent variable groups once {hub_names} are treated as "
        f"shared hubs" + (f" ({sorted(names[v] for v in frozen)} are never written after Init)"
                          if frozen else "")
    )
    return Plan(hub_names, out_groups, [a.name for a in actions], rationale)


def _components(local: Set[int], hubs: Set[int], actions: List[Action],
                conj_fps: List[FrozenSet[int]]) -> List[Set[int]]:
    parent = {v: v for v in local}

    def find(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    def tie(vs):
        vs = [v for v in vs if v in parent]
        for a, b in zip(vs, vs[1:]):
            parent[find(a)] = find(b)

    for a in actions:
        if a.footprint.writes - hubs:
            tie(sorted((a.footprint.reads | a.footprint.writes) - hubs))
    for fp in conj_fps:
        tie(sorted(fp - hubs))

    comps: Dict[int, Set[int]] = {}
    for v in local:
        comps.setdefault(find(v), set()).add(v)
    return list(comps.values())
