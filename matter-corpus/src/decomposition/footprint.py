r"""
Variable footprints of TLA+ expressions: which state variables an
expression reads, which it writes (primed, other than as a frame
condition), and which it merely frames (UNCHANGED x, or x' = x).

Calls to user-defined operators are expanded transitively, so an action
written as `/\ Guard /\ Effect(e)` gets the footprint of Guard's and
Effect's bodies, not just of the call site.
"""
from dataclasses import dataclass
from typing import Dict, FrozenSet, List, Optional, Set

from src.tla.sany_ast import Model, Node, OpDef


@dataclass(frozen=True)
class Footprint:
    reads: FrozenSet[int] = frozenset()
    writes: FrozenSet[int] = frozenset()
    frames: FrozenSet[int] = frozenset()

    @property
    def mentions(self) -> FrozenSet[int]:
        return self.reads | self.writes | self.frames

    def __or__(self, other: "Footprint") -> "Footprint":
        return Footprint(self.reads | other.reads, self.writes | other.writes,
                         self.frames | other.frames)

    def primed(self) -> "Footprint":
        """Footprint of the same expression under a prime: every read becomes a write."""
        return Footprint(frozenset(), self.reads | self.writes, self.frames)


EMPTY = Footprint()


class FootprintAnalyzer:
    def __init__(self, model: Model):
        self.m = model
        self._def_memo: Dict[int, Footprint] = {}
        self._node_memo: Dict[int, Footprint] = {}
        self._in_progress: Set[int] = set()

    def of_def(self, d: OpDef) -> Footprint:
        if d.uid in self._def_memo:
            return self._def_memo[d.uid]
        if d.uid in self._in_progress:      # recursive operator: fixpoint not needed
            return EMPTY                    # (the outer call collects the rest)
        self._in_progress.add(d.uid)
        fp = self.of(self.m.body(d))
        self._in_progress.discard(d.uid)
        self._def_memo[d.uid] = fp
        return fp

    def of(self, node: Optional[Node]) -> Footprint:
        if node is None:
            return EMPTY
        key = id(node)
        if key in self._node_memo:
            return self._node_memo[key]
        fp = self._compute(node)
        self._node_memo[key] = fp
        return fp

    def _compute(self, n: Node) -> Footprint:
        if n.kind == "let":
            fp = self.of(n.body)
            # LET-local definitions are reached through calls in the body.
            return fp
        if n.kind != "app":
            fp = EMPTY
            for c in n.children():
                fp = fp | self.of(c)
            return fp

        kind, ref = n.op
        if kind == "var":
            return Footprint(reads=frozenset([ref]))
        if kind == "builtin":
            if ref == "'":
                return self.of(n.operands[0]).primed()
            if ref == "UNCHANGED":
                return Footprint(frames=self.of(n.operands[0]).mentions)
            if ref == "=":
                framed = _frame_equality_var(n)
                if framed is not None:
                    return Footprint(frames=frozenset([framed]))
        fp = EMPTY
        if kind == "def":
            fp = self.of_def(self.m.defs[ref])
        for c in n.children():
            fp = fp | self.of(c)
        return fp


def _frame_equality_var(n: Node) -> Optional[int]:
    """The variable uid if `n` is x' = x (either orientation), else None."""
    a, b = n.operands
    for p, q in ((a, b), (b, a)):
        if (p.kind == "app" and p.op == ("builtin", "'") and p.operands
                and p.operands[0].kind == "app" and p.operands[0].op[0] == "var"
                and q.kind == "app" and q.op == p.operands[0].op):
            return q.op[1]
    return None


# ----------------------------------------------------------------- actions

@dataclass
class Action:
    name: str            # matches the label TLC prints in traces
    node: Node
    footprint: Footprint = EMPTY


_DISJ = {"\\lor", "$DisjList"}


def flatten_actions(model: Model, next_def: OpDef, fa: FootprintAnalyzer) -> List[Action]:
    """
    Splits Next into its top-level disjuncts, looking through zero-arity
    operator definitions whose body is itself a disjunction (Next == A \\/ B
    where A == C \\/ D yields C, D, B). Each leaf is named the way TLC names
    it in counterexample traces, so findings can be keyed consistently.
    """
    out: List[Action] = []

    def leaf_name(node: Node, fallback: str) -> str:
        cur = node
        while True:
            if cur.kind == "app" and cur.op[0] == "def":
                return model.defs[cur.op[1]].name
            if (cur.kind == "app" and cur.op[0] == "builtin"
                    and cur.op[1] in ("$BoundedExists", "$UnboundedExists") and cur.operands):
                cur = cur.operands[0]
                continue
            return fallback

    def visit(node: Node, fallback: str):
        if node.kind == "app" and node.op[0] == "builtin" and node.op[1] in _DISJ:
            for i, c in enumerate(node.operands):
                visit(c, f"{fallback}_{i + 1}")
            return
        if node.kind == "app" and node.op[0] == "def":
            d = model.defs[node.op[1]]
            body = model.body(d)
            if d.arity == 0 and body.kind == "app" and body.op[0] == "builtin" and body.op[1] in _DISJ:
                visit(body, d.name)
                return
        out.append(Action(leaf_name(node, fallback), node, fa.of(node)))

    visit(model.body(next_def), next_def.name)
    return out


def top_conjuncts(model: Model, node: Node) -> List[Node]:
    """Top-level conjuncts of a state predicate, looking through zero-arity defs."""
    if node.kind == "app" and node.op[0] == "builtin" and node.op[1] in ("\\land", "$ConjList"):
        return [c for o in node.operands for c in top_conjuncts(model, o)]
    if node.kind == "app" and node.op[0] == "def":
        d = model.defs[node.op[1]]
        if d.arity == 0:
            return top_conjuncts(model, model.body(d))
    return [node]
