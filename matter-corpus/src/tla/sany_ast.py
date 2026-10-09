"""
Loads a TLA+ module's *semantic* parse tree from SANY (the official TLA+
parser shipped in tla2tools.jar) via its XML exporter.

Why SANY instead of regexes over the .tla text: the models this pipeline has
to handle are not only the hand-written ones (which follow a fixed
pendingEvent / UndefinedTransition house style) but also LLM-generated ones,
which use arbitrary variable names, helper operators, LET, CASE, EXCEPT, etc.
Deciding which variables an action reads and writes -- the input to automatic
decomposition -- has to be exact, and only the real parser can resolve every
name to "this is variable x" vs. "this is a bound parameter that happens to
be called x". Every node also carries its exact source span, which the
abstraction step uses to rewrite the original text in place.
"""
import subprocess
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from src.tla.tools import tla2tools_jar, java_cmd


# Span = (line_begin, col_begin, line_end, col_end); 1-based, inclusive.
Span = Tuple[int, int, int, int]


class SanyError(RuntimeError):
    """SANY could not parse / semantically process the module."""


@dataclass
class Node:
    """
    One expression node. `kind` is one of:
      "app"     - operator application; `op` says what is applied:
                    ("builtin", name) | ("def", uid) | ("var", uid) |
                    ("const", uid) | ("param", uid)
      "string" / "number" / "at" / "let" / "other"
    Bound variables of quantifiers / set comprehensions are in `bounds` as
    (param_uids, bounding-set node or None).
    """
    kind: str
    span: Optional[Span]
    level: int = 0
    op: Optional[Tuple[str, object]] = None
    operands: List["Node"] = field(default_factory=list)
    bounds: List[Tuple[List[int], Optional["Node"]]] = field(default_factory=list)
    value: Optional[str] = None
    let_defs: List[int] = field(default_factory=list)   # for kind == "let"
    body: Optional["Node"] = None                        # for kind == "let"

    def children(self) -> List["Node"]:
        out = list(self.operands)
        for _, s in self.bounds:
            if s is not None:
                out.append(s)
        if self.body is not None:
            out.append(self.body)
        return out


@dataclass
class OpDef:
    uid: int
    name: str
    params: List[int]
    level: int
    span: Optional[Span]
    filename: str
    body: Optional[Node] = None       # filled lazily by Model

    @property
    def arity(self) -> int:
        return len(self.params)


@dataclass
class Assume:
    span: Optional[Span]
    body: Node


class Model:
    """
    The parsed root module: its variables, constants and operator
    definitions (including those pulled in via EXTENDS), plus the original
    source text so callers can map spans back to text.
    """

    def __init__(self, tla_path: Path, root: ET.Element, source: str):
        self.tla_path = Path(tla_path)
        self.module_name = root.findtext("RootModule")
        self.source = source
        self.lines = source.split("\n")
        self._ctx: Dict[int, ET.Element] = {
            int(e.findtext("UID")): e[1] for e in root.find("context")
        }

        self.builtins: Dict[int, str] = {}
        self.variables: Dict[int, str] = {}
        self.constants: Dict[int, str] = {}
        self.params: Dict[int, str] = {}
        self.defs: Dict[int, OpDef] = {}
        self.decl_spans: Dict[int, Span] = {}
        self.assumes: List[Assume] = []
        self.extends_has_instances = False

        for uid, el in self._ctx.items():
            tag = el.tag
            if tag == "BuiltInKind":
                self.builtins[uid] = el.findtext("uniquename")
            elif tag == "OpDeclNode":
                name = el.findtext("uniquename")
                kind = int(el.findtext("kind"))
                fname = el.findtext("location/filename")
                # kind 2 = CONSTANT, 3 = VARIABLE (tla2sany.semantic.ASTConstants)
                if fname == self.module_name:
                    if kind == 3:
                        self.variables[uid] = name
                    elif kind == 2:
                        self.constants[uid] = name
                    self.decl_spans[uid] = _span(el)
                elif kind == 2:
                    self.constants[uid] = name
                elif kind == 3:
                    # A VARIABLE declared in an EXTENDed module still belongs
                    # to the state; keep it so footprints stay exact. It gets
                    # no decl_span: spans index into the root file only.
                    self.variables[uid] = name
            elif tag == "FormalParamNode":
                self.params[uid] = el.findtext("uniquename")
            elif tag == "UserDefinedOpKind":
                params_el = el.find("params")
                params = [
                    int(p.findtext("FormalParamNodeRef/UID"))
                    for p in (params_el if params_el is not None else [])
                ]
                self.defs[uid] = OpDef(
                    uid=uid,
                    name=el.findtext("uniquename"),
                    params=params,
                    level=int(el.findtext("level") or 0),
                    span=_span(el),
                    filename=el.findtext("location/filename"),
                )
            elif tag == "InstanceNode" and el.findtext("location/filename") == self.module_name:
                self.extends_has_instances = True

        root_mod = next(
            el for el in self._ctx.values()
            if el.tag == "ModuleNode" and el.findtext("uniquename") == self.module_name
        )
        for ref in root_mod:
            if ref.tag == "AssumeNodeRef":
                a = self._ctx[int(ref.findtext("UID"))]
                self.assumes.append(Assume(_span(a), self._node(a.find("body")[0])))
        # Root-module operator definitions, in source order (LET-local
        # definitions are excluded: they are reached through their LET node).
        let_local = set()
        for el in self._ctx.values():
            if el.tag == "UserDefinedOpKind":
                for let in el.iter("LetInNode"):
                    for r in let.find("opDefs"):
                        let_local.add(int(r.findtext("UID")))
        self.root_defs: List[OpDef] = sorted(
            (d for d in self.defs.values()
             if d.filename == self.module_name and d.uid not in let_local and d.span),
            key=lambda d: (d.span[0], d.span[1]),
        )

    # ------------------------------------------------------------------ API

    def def_by_name(self, name: str) -> Optional[OpDef]:
        for d in self.root_defs:
            if d.name == name:
                return d
        for d in self.defs.values():
            if d.name == name:
                return d
        return None

    def body(self, d: OpDef) -> Node:
        if d.body is None:
            el = self._ctx[d.uid].find("body")
            d.body = self._node(el[0]) if el is not None and len(el) else Node("other", None)
        return d.body

    def text(self, span: Span) -> str:
        l1, c1, l2, c2 = span
        if l1 == l2:
            return self.lines[l1 - 1][c1 - 1:c2]
        parts = [self.lines[l1 - 1][c1 - 1:]]
        parts += self.lines[l1:l2 - 1]
        parts.append(self.lines[l2 - 1][:c2])
        return "\n".join(parts)

    def op_name(self, node: Node) -> str:
        """Human-readable name of an "app" node's operator."""
        kind, ref = node.op
        if kind == "builtin":
            return ref
        if kind == "def":
            return self.defs[ref].name
        if kind == "var":
            return self.variables[ref]
        if kind == "const":
            return self.constants[ref]
        return self.params.get(ref, f"param{ref}")

    # ------------------------------------------------------------ internals

    def _node(self, el: ET.Element) -> Node:
        tag = el.tag
        span = _span(el)
        level = int(el.findtext("level") or 0)
        if tag == "OpApplNode":
            opref = el.find("operator")[0]
            uid = int(opref.findtext("UID"))
            if opref.tag == "BuiltInKindRef":
                op = ("builtin", self.builtins[uid])
            elif opref.tag == "UserDefinedOpKindRef":
                op = ("def", uid)
            elif opref.tag == "OpDeclNodeRef":
                op = ("var", uid) if uid in self.variables else ("const", uid)
            elif opref.tag == "FormalParamNodeRef":
                op = ("param", uid)
            else:
                op = ("other", opref.tag)
            operands = [self._node(c) for c in el.find("operands")]
            bounds = []
            bs = el.find("boundSymbols")
            if bs is not None:
                for b in bs:
                    pids = [int(r.findtext("UID")) for r in b.findall("FormalParamNodeRef")]
                    set_el = [c for c in b if c.tag != "FormalParamNodeRef"]
                    bounds.append((pids, self._node(set_el[0]) if set_el else None))
            return Node("app", span, level, op, operands, bounds)
        if tag == "StringNode":
            return Node("string", span, level, value=el.findtext("StringValue"))
        if tag in ("NumeralNode", "DecimalNode"):
            return Node("number", span, level, value=el.findtext("IntValue") or "")
        if tag == "AtNode":
            return Node("at", span, level)
        if tag == "LetInNode":
            defs = [int(r.findtext("UID")) for r in el.find("opDefs")]
            return Node("let", span, level, let_defs=defs, body=self._node(el.find("body")[0]))
        # LabelNode, SubstInNode, OpArgNode, ... : keep the nearest nested
        # expressions so footprints stay conservative (nothing is hidden
        # from the read/write analysis just because the wrapper is unusual).
        return Node("other", span, level,
                    operands=[self._node(c) for c in _nearest_exprs(el)])


_EXPR_TAGS = {"OpApplNode", "LetInNode", "StringNode", "NumeralNode",
              "DecimalNode", "AtNode", "LabelNode", "SubstInNode"}


def _nearest_exprs(el: ET.Element) -> List[ET.Element]:
    out = []
    for c in el:
        if c.tag in _EXPR_TAGS:
            out.append(c)
        elif c.tag != "location":
            out.extend(_nearest_exprs(c))
    return out


def _span(el: ET.Element) -> Optional[Span]:
    loc = el.find("location")
    if loc is None:
        return None
    return (
        int(loc.findtext("line/begin")), int(loc.findtext("column/begin")),
        int(loc.findtext("line/end")), int(loc.findtext("column/end")),
    )


def load_model(tla_path, timeout: int = 120) -> Model:
    """
    Runs SANY's XML exporter on `tla_path` (its directory is the working
    directory, so sibling modules it EXTENDS are found) and returns the
    parsed Model. Raises SanyError with SANY's own message on failure.
    """
    tla_path = Path(tla_path).resolve()
    if "\t" in tla_path.read_text(encoding="utf-8"):
        # SANY's column numbers for tab-indented source don't map 1:1 onto
        # characters, which would corrupt every span-based rewrite.
        raise SanyError(f"{tla_path.name}: contains tab characters; expand tabs to spaces first")
    proc = subprocess.run(
        java_cmd() + ["-cp", str(tla2tools_jar()), "tla2sany.xml.XMLExporter", "-o", tla_path.name],
        cwd=tla_path.parent, capture_output=True, text=True, timeout=timeout,
    )
    if proc.returncode != 0 or not proc.stdout.lstrip().startswith("<?xml"):
        raise SanyError(proc.stderr.strip() or proc.stdout.strip() or "SANY XML export failed")
    root = ET.fromstring(proc.stdout)
    return Model(tla_path, root, tla_path.read_text(encoding="utf-8"))
