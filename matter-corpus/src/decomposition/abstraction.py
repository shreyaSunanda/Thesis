r"""
Generates the submodule for one group: the original module with the
*hidden* variables (every other group's locals) existentially abstracted
away, by rewriting the original source text in place.

Soundness argument (why a piece can never miss a violation)
-----------------------------------------------------------
Each rewritten Init / Next / CONSTRAINT is implied by the original
(Init => Init', Next => Next'), so every reachable state of the full model,
projected onto the piece's variables, is reachable in the piece: the piece
over-approximates. Each rewritten invariant is implied by the original
(Inv => Inv'), and since every top-level conjunct of an invariant lives
whole in some piece (the planner guarantees this), every violation of the
full model shows up as a violation in at least one piece.

The over-approximation is built from three rewrite rules, applied only to
subexpressions that mention a hidden variable:

  1. An atom (a boolean leaf such as `outstanding < MaxOutstanding`) in a
     purely positive position becomes TRUE, in a purely negative position
     FALSE -- by monotonicity this can only make the enclosing formula
     weaker in the right direction, and it introduces no extra branching.
  2. An atom in a mixed position (an IF condition, either side of <=>)
     becomes a fresh variable `abs__hN` quantified `\E abs__hN \in BOOLEAN`
     at the top of the definition -- "the hidden condition could be either".
  3. Frame conditions drop the hidden variables (UNCHANGED <<a, h, b>>
     becomes UNCHANGED <<a, b>>); a hidden assignment `h' = e` is just an
     atom with no visible prime, so rule 1 turns it into TRUE.

What is *not* abstractable -- hidden data flowing into a visible variable,
e.g. `queueLen' = outstanding` -- raises AbstractionError rather than
guessing; the planner's tie rule exists to prevent exactly that.

Precision (why reported findings are not spurious)
--------------------------------------------------
Over-approximation can produce counterexamples that the full model cannot
actually perform. Those are filtered by src.decomposition.replay, which
re-executes every counterexample on the *full* model.

Text-level details
------------------
Edits are applied to the original text using SANY's exact source spans, so
everything not rewritten -- comments, CONSTANTS, ASSUME, helper operators
-- is preserved verbatim. Replacements are single-line, which keeps every
other line's /\ and \/ bullet alignment intact.
"""
import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

from src.decomposition.footprint import FootprintAnalyzer
from src.decomposition.planner import SpecParts
from src.tla.cfg import TLCConfig
from src.tla.sany_ast import Model, Node, OpDef, Span


class AbstractionError(Exception):
    pass


_CONNECTIVES = {"\\land", "\\lor", "$ConjList", "$DisjList"}
_EXISTS = {"$BoundedExists", "$UnboundedExists"}
_BINDERS_NO_HOIST = {"$BoundedForall", "$UnboundedForall", "$FcnConstructor", "$SetOfAll",
                     "$SubsetOf", "$BoundedChoose", "$UnboundedChoose", "$RecursiveFcnSpec"}
# Operators whose application is a boolean value (used to abstract boolean
# sub-terms sitting in value position, e.g. `flag' = (h > 0)`).
_BOOL_BUILTINS = {"=", "/=", "\\in", "\\notin", "\\subseteq", "\\lnot", "\\land", "\\lor",
                  "=>", "\\equiv", "$ConjList", "$DisjList", "$BoundedExists",
                  "$UnboundedExists", "$BoundedForall", "$UnboundedForall", "TRUE", "FALSE"}
_BOOL_DEFS = {"<", ">", "\\leq", "\\geq", "<=", ">="}


@dataclass
class _DefWork:
    """Edits accumulated for one definition at one polarity."""
    edits: List[Tuple[Span, str]] = field(default_factory=list)
    fresh: List[str] = field(default_factory=list)


class Abstractor:
    def __init__(self, model: Model, hidden: Set[int], parts: SpecParts, cfg: TLCConfig):
        self.m = model
        self.hidden = hidden
        self.parts = parts
        self.cfg = cfg
        self.fa = FootprintAnalyzer(model)
        self.visible = set(model.variables) - hidden
        self._counter = 0
        # (def uid, polarity) -> work; polarity +1 is written in place under
        # the original name, -1 is emitted as a renamed copy `<name>__under`.
        self.work: Dict[Tuple[int, int], _DefWork] = {}
        self._pending: List[Tuple[int, int]] = []
        self._cur: Optional[_DefWork] = None
        self._no_hoist_depth = 0
        self._frame_tuple_defs = {
            d.uid for d in model.root_defs
            if d.arity == 0 and self._is_var_tuple(model.body(d))
        }
        for uid in hidden:
            span = model.decl_spans.get(uid)
            if span is None:
                raise AbstractionError(f"hidden variable {model.variables[uid]} is declared "
                                       "outside the root module")

    # ----------------------------------------------------------- queries

    def mentions_hidden(self, n: Node) -> bool:
        return bool(self.fa.of(n).mentions & self.hidden)

    def def_mentions_hidden(self, d: OpDef) -> bool:
        return bool(self.fa.of_def(d).mentions & self.hidden)

    def visible_primes(self, n: Node) -> Set[int]:
        fp = self.fa.of(n)
        return set((fp.writes | fp.frames) - self.hidden)

    def _is_var_tuple(self, n: Node) -> bool:
        return (n.kind == "app" and n.op == ("builtin", "$Tuple")
                and all(o.kind == "app" and o.op[0] == "var" for o in n.operands))

    def _hidden_names(self, n: Node) -> str:
        return ", ".join(sorted(self.m.variables[v] for v in self.fa.of(n).mentions & self.hidden))

    # ----------------------------------------------------------- driver

    def request(self, d: OpDef, pol: int):
        key = (d.uid, pol)
        if key not in self.work:
            self.work[key] = _DefWork()
            self._pending.append(key)

    def run(self, roots: List[OpDef]):
        for d in roots:
            self.request(d, +1)
        while self._pending:
            uid, pol = self._pending.pop()
            d = self.m.defs[uid]
            if not self.def_mentions_hidden(d) or uid in self._frame_tuple_defs:
                continue
            if d.filename != self.m.module_name:
                raise AbstractionError(f"operator {d.name} from an EXTENDed module reads "
                                       "hidden state")
            self._cur = self.work[(uid, pol)]
            self.bool(self.m.body(d), pol)
            self._cur = None

    # ------------------------------------------------- rewrite primitives

    def edit(self, span: Span, text: str):
        self._cur.edits.append((span, text))

    def fresh(self, n: Node) -> str:
        if self._no_hoist_depth:
            raise AbstractionError(
                f"hidden variable(s) {self._hidden_names(n)} used under a binder "
                f"(\\A, CHOOSE, set/function constructor) in `{self._snippet(n)}`")
        self._counter += 1
        name = f"abs__h{self._counter}"
        self._cur.fresh.append(name)
        return name

    def _snippet(self, n: Node) -> str:
        t = " ".join(self.m.text(n.span).split()) if n.span else "?"
        return t if len(t) < 90 else t[:87] + "..."

    # ------------------------------------------------- boolean positions

    def bool(self, n: Node, pol: int):
        if not self.mentions_hidden(n):
            return
        if n.kind == "let":
            if any(self.def_mentions_hidden(self.m.defs[u]) for u in n.let_defs):
                return self.atom(n, pol)
            return self.bool(n.body, pol)
        if n.kind != "app":
            return self.atom(n, pol)

        kind, ref = n.op
        if kind == "builtin":
            if ref in _CONNECTIVES or ref == "[]":
                for c in n.operands:
                    self.bool(c, pol)
                return
            if ref == "\\lnot":
                return self.bool(n.operands[0], -pol)
            if ref == "=>":
                self.bool(n.operands[0], -pol)
                return self.bool(n.operands[1], pol)
            if ref == "\\equiv":
                for c in n.operands:
                    self.bool(c, 0)
                return
            if ref == "$IfThenElse":
                c, a, b = n.operands
                self.bool(c, 0)
                self.bool(a, pol)
                return self.bool(b, pol)
            if ref == "$Case":
                for arm in n.operands:
                    if arm.kind == "app" and arm.op == ("builtin", "$Pair"):
                        g, v = arm.operands
                        if g.kind == "app":           # OTHER arm has a string marker
                            self.bool(g, 0)
                        self.bool(v, pol)
                return
            if ref in _EXISTS:
                if any(s is not None and self.mentions_hidden(s) for _, s in n.bounds):
                    return self.atom(n, pol)
                return self.bool(n.operands[0], pol)
            if ref == "UNCHANGED":
                return self.frame_unchanged(n)
            if ref in ("$SquareAct", "$AngleAct"):
                self.bool(n.operands[0], pol)
                return self.frame_subscript(n.operands[1])
            if ref in ("$WF", "$SF"):
                self.frame_subscript(n.operands[0])
                return self.bool(n.operands[1], pol)
            return self.atom(n, pol)

        if kind == "def":
            d = self.m.defs[ref]
            if any(self.mentions_hidden(a) for a in n.operands):
                return self.atom(n, pol)
            if pol == 0 or d.filename != self.m.module_name:
                return self.atom(n, pol)
            self.request(d, pol)
            if pol < 0:
                # Rename the call to the under-approximating copy.
                l1, c1, _, _ = n.span
                self.edit((l1, c1, l1, c1 + len(d.name) - 1), f"{d.name}__under")
            return
        return self.atom(n, pol)

    def atom(self, n: Node, pol: int):
        if self.visible_primes(n):
            # Keep the visible assignment; abstract only the hidden parts of
            # the value it is assigned (IF/CASE conditions, boolean sub-terms).
            return self.value(n)
        if pol > 0:
            self.edit(n.span, "TRUE")
        elif pol < 0:
            self.edit(n.span, "FALSE")
        else:
            self.edit(n.span, self.fresh(n))

    # --------------------------------------------------- value positions

    def value(self, n: Node):
        if not self.mentions_hidden(n):
            return
        if n.kind == "app" and n.op[0] == "builtin":
            ref = n.op[1]
            if ref == "$IfThenElse":
                c, a, b = n.operands
                self.bool(c, 0)
                self.value(a)
                return self.value(b)
            if ref == "$Case":
                for arm in n.operands:
                    if arm.kind == "app" and arm.op == ("builtin", "$Pair"):
                        g, v = arm.operands
                        if g.kind == "app":
                            self.bool(g, 0)
                        self.value(v)
                return
            if ref in ("'",) and n.operands[0].kind == "app" and n.operands[0].op[0] == "var":
                return    # x' itself: only reached when x is visible
            if ref in _BINDERS_NO_HOIST or ref in _EXISTS:
                if any(s is not None and self.mentions_hidden(s) for _, s in n.bounds):
                    return self._flow_error(n)
                self._no_hoist_depth += 1
                try:
                    for c in n.operands:
                        self.value(c)
                finally:
                    self._no_hoist_depth -= 1
                return
            if ref in _BOOL_BUILTINS and not self.visible_primes(n):
                return self.edit(n.span, self.fresh(n))
            for c in n.operands:
                self.value(c)
            return
        if (n.kind == "app" and n.op[0] == "def" and not self.visible_primes(n)
                and self.m.defs[n.op[1]].name in _BOOL_DEFS):
            return self.edit(n.span, self.fresh(n))
        if n.kind == "app" and n.op[0] == "def" and not self.visible_primes(n) \
                and self.m.defs[n.op[1]].level <= 1 and _looks_boolean_def(self.m, n):
            return self.edit(n.span, self.fresh(n))
        return self._flow_error(n)

    def _flow_error(self, n: Node):
        raise AbstractionError(
            f"hidden variable(s) {self._hidden_names(n)} flow into visible state through "
            f"`{self._snippet(n)}` (line {n.span[0] if n.span else '?'})")

    # -------------------------------------------------------------- frames

    def _frame_vars(self, n: Node) -> Optional[List[int]]:
        """Variables listed by a frame expression, or None if it isn't one."""
        if n.kind == "app" and n.op[0] == "var":
            return [n.op[1]]
        if n.kind == "app" and n.op == ("builtin", "$Tuple"):
            out = []
            for o in n.operands:
                sub = self._frame_vars(o)
                if sub is None:
                    return None
                out += sub
            return out
        if n.kind == "app" and n.op[0] == "def" and self.m.defs[n.op[1]].arity == 0:
            return self._frame_vars(self.m.body(self.m.defs[n.op[1]]))
        return None

    def frame_unchanged(self, n: Node):
        vs = self._frame_vars(n.operands[0])
        if vs is None:
            raise AbstractionError(f"cannot abstract frame `{self._snippet(n)}`")
        keep = [self.m.variables[v] for v in vs if v not in self.hidden]
        self.edit(n.span, f"UNCHANGED <<{', '.join(keep)}>>" if keep else "TRUE")

    def frame_subscript(self, n: Node):
        if not self.mentions_hidden(n):
            return
        if n.kind == "app" and n.op[0] == "def" and n.op[1] in self._frame_tuple_defs:
            return    # the tuple definition itself is filtered in place
        vs = self._frame_vars(n)
        if vs is None:
            raise AbstractionError(f"cannot abstract subscript `{self._snippet(n)}`")
        keep = [self.m.variables[v] for v in vs if v not in self.hidden]
        self.edit(n.span, f"<<{', '.join(keep)}>>")


def _looks_boolean_def(m: Model, n: Node) -> bool:
    body = m.body(m.defs[n.op[1]])
    return body.kind == "app" and body.op[0] == "builtin" and body.op[1] in _BOOL_BUILTINS


# ====================================================================== text

def _apply_edits(text: str, first_line: int, first_col: int,
                 edits: List[Tuple[Span, str]]) -> str:
    """Applies span edits (absolute coordinates) to `text`, which starts at
    (first_line, first_col) of the original file."""
    lines = text.split("\n")

    def rel(line, col):
        r = line - first_line
        return r, (col - first_col if r == 0 else col - 1)

    for (l1, c1, l2, c2), repl in sorted(edits, key=lambda e: (e[0][0], e[0][1]), reverse=True):
        r1, k1 = rel(l1, c1)
        r2, k2 = rel(l2, c2)
        new = lines[r1][:k1] + repl + lines[r2][k2 + 1:]
        lines[r1:r2 + 1] = [new]
    return "\n".join(lines)


def _hoist(def_text: str, model: Model, d: OpDef, fresh: List[str]) -> str:
    r"""Prefix the definition body with `\E abs__h1, ... \in BOOLEAN :`.
    The body is moved to its own line at its original column, so junction
    bullets inside it keep their alignment."""
    if not fresh:
        return def_text
    body = model.body(d)
    bl, bc = body.span[0], body.span[1]
    r = bl - d.span[0]
    k = bc - d.span[1] if r == 0 else bc - 1
    lines = def_text.split("\n")
    head, rest = lines[r][:k], lines[r][k:]
    quant = f"\\E {', '.join(fresh)} \\in BOOLEAN :"
    lines[r:r + 1] = [head.rstrip() + " " + quant if head.strip() else head + quant,
                      " " * (bc - 1) + rest]
    return "\n".join(lines)


def _code_mask(src: str) -> str:
    """`src` with comments blanked (same length, newlines kept), so keyword
    searches never match inside comments."""
    out = list(src)
    i, n, depth = 0, len(src), 0
    while i < n:
        if depth == 0 and src.startswith("\\*", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        if src.startswith("(*", i):
            depth += 1
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if depth and src.startswith("*)", i):
            depth -= 1
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if depth and src[i] != "\n":
            out[i] = " "
        i += 1
    return "".join(out)


@dataclass
class Submodule:
    name: str
    text: str
    cfg: TLCConfig
    variables: List[str]
    hidden: List[str]


def build_submodule(model: Model, cfg: TLCConfig, parts: SpecParts, hidden_names: List[str],
                    name: str) -> Submodule:
    hidden = {u for u, v in model.variables.items() if v in hidden_names}
    ab = Abstractor(model, hidden, parts, cfg)

    roots = [parts.init, parts.next] + ([parts.spec] if parts.spec else [])
    sub_cfg = TLCConfig(
        specification=cfg.specification, init=cfg.init, next=cfg.next,
        constants_text=cfg.constants_text, constraints=list(cfg.constraints),
        action_constraints=list(cfg.action_constraints),
        # Deadlock is a global property (no action of ANY piece enabled); it
        # does not decompose, so it is only ever checked on the full model.
        check_deadlock=False,
    )
    for inv in cfg.invariants:
        d = model.def_by_name(inv)
        roots.append(d)
        sub_cfg.invariants.append(inv)
    for c in cfg.constraints + cfg.action_constraints:
        roots.append(model.def_by_name(c))
    if cfg.symmetry or cfg.view:
        for opname in filter(None, (cfg.symmetry, cfg.view)):
            d = model.def_by_name(opname)
            if d and ab.def_mentions_hidden(d):
                raise AbstractionError(f"SYMMETRY/VIEW {opname} reads hidden variables")
        sub_cfg.symmetry, sub_cfg.view = cfg.symmetry, cfg.view

    ab.run(roots)

    src = model.source
    line_starts = [0]
    for ln in src.split("\n"):
        line_starts.append(line_starts[-1] + len(ln) + 1)

    def off(line, col):
        return line_starts[line - 1] + col - 1

    edits: List[Tuple[int, int, str]] = []     # (start offset, end offset exclusive, text)

    # 1. Definitions.
    requested = {uid for uid, _ in ab.work}
    for d in model.root_defs:
        mentions = ab.def_mentions_hidden(d)
        if not mentions:
            continue
        start, end = off(d.span[0], d.span[1]), off(d.span[2], d.span[3]) + 1
        orig = model.text(d.span)
        if d.uid in ab._frame_tuple_defs:
            body = model.body(d)
            keep = [model.variables[o.op[1]] for o in body.operands if o.op[1] not in hidden]
            new = _apply_edits(orig, d.span[0], d.span[1], [(body.span, f"<<{', '.join(keep)}>>")])
            edits.append((start, end, new))
            continue
        if d.uid not in requested:
            edits.append((start, end, f"\\* {d.name}: removed -- reads variables of another piece"))
            continue
        pieces = []
        for pol in (+1, -1):
            w = ab.work.get((d.uid, pol))
            if w is None:
                continue
            t = _apply_edits(orig, d.span[0], d.span[1], w.edits)
            t = _hoist(t, model, d, w.fresh)
            if pol < 0:
                t = re.sub(r"^(\s*)" + re.escape(d.name), r"\g<1>" + d.name + "__under", t, count=1)
            pieces.append(t)
        if (d.uid, +1) not in ab.work:
            # Only needed negatively: every call site was renamed to the
            # __under copy, so the original body is not needed at all.
            pieces.insert(0, f"\\* {d.name}: only {d.name}__under is used in this piece")
        edits.append((start, end, "\n\n".join(pieces)))

    # 2. VARIABLES statements: drop hidden names.
    mask = _code_mask(src)
    kw = [m.start() for m in re.finditer(r"(?<![A-Za-z0-9_])VARIABLES?(?![A-Za-z0-9_])", mask)]
    by_stmt: Dict[int, List[Tuple[int, int, str]]] = {}
    for uid, vname in model.variables.items():
        span = model.decl_spans.get(uid)
        if span is None:
            continue
        s = off(span[0], span[1])
        k = max((p for p in kw if p < s), default=None)
        if k is None:
            raise AbstractionError("could not locate VARIABLES declaration")
        by_stmt.setdefault(k, []).append((s, off(span[2], span[3]) + 1, vname))
    for k, decls in by_stmt.items():
        decls.sort()
        keep = [v for _, _, v in decls if v not in hidden_names]
        end = decls[-1][1]
        edits.append((k, end, f"VARIABLES {', '.join(keep)}" if keep else ""))

    # 3. Module header.
    m = re.search(r"MODULE\s+" + re.escape(model.module_name) + r"\b", mask)
    edits.append((m.start(), m.end(), f"MODULE {name}"))

    text = src
    for s, e, t in sorted(edits, key=lambda x: x[0], reverse=True):
        text = text[:s] + t + text[e:]

    header = (f"\\* AUTO-GENERATED by src.decomposition from {model.module_name}.tla -- do not edit.\n"
              f"\\* Piece keeps variables {sorted(set(model.variables.values()) - set(hidden_names))};\n"
              f"\\* abstracts away {sorted(hidden_names)} (see src/decomposition/abstraction.py).\n")
    text = header + text
    return Submodule(name=name, text=text, cfg=sub_cfg,
                     variables=sorted(set(model.variables.values()) - set(hidden_names)),
                     hidden=sorted(hidden_names))
