"""
Minimal reader/writer for TLC .cfg files.

Only the statement *kinds* are interpreted (SPECIFICATION, INIT, NEXT,
INVARIANT, PROPERTY, CONSTRAINT, ...). The CONSTANTS block is kept as raw
text and copied verbatim into every generated config, so model values,
`<-` substitutions and odd formatting survive untouched.
"""
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

_KEYWORDS = [
    "SPECIFICATION", "INIT", "NEXT", "INVARIANTS", "INVARIANT", "PROPERTIES", "PROPERTY",
    "CONSTANTS", "CONSTANT", "CONSTRAINTS", "CONSTRAINT", "ACTION_CONSTRAINTS",
    "ACTION_CONSTRAINT", "SYMMETRY", "VIEW", "CHECK_DEADLOCK", "POSTCONDITION", "ALIAS",
]
_KW_RE = re.compile(r"(?<![A-Za-z0-9_])(" + "|".join(_KEYWORDS) + r")(?![A-Za-z0-9_])")


@dataclass
class TLCConfig:
    specification: Optional[str] = None
    init: Optional[str] = None
    next: Optional[str] = None
    invariants: List[str] = field(default_factory=list)
    properties: List[str] = field(default_factory=list)
    constraints: List[str] = field(default_factory=list)
    action_constraints: List[str] = field(default_factory=list)
    constants_text: str = ""          # raw body of every CONSTANT(S) block, joined
    symmetry: Optional[str] = None
    view: Optional[str] = None
    check_deadlock: Optional[bool] = None
    other: List[str] = field(default_factory=list)   # statements we don't interpret

    def render(self) -> str:
        out = []
        if self.specification:
            out.append(f"SPECIFICATION {self.specification}")
        if self.init:
            out.append(f"INIT {self.init}")
        if self.next:
            out.append(f"NEXT {self.next}")
        if self.constants_text.strip():
            out.append("CONSTANTS\n" + self.constants_text.rstrip())
        for kw, items in (("INVARIANT", self.invariants), ("PROPERTY", self.properties),
                          ("CONSTRAINT", self.constraints),
                          ("ACTION_CONSTRAINT", self.action_constraints)):
            for it in items:
                out.append(f"{kw} {it}")
        if self.symmetry:
            out.append(f"SYMMETRY {self.symmetry}")
        if self.view:
            out.append(f"VIEW {self.view}")
        if self.check_deadlock is not None:
            out.append(f"CHECK_DEADLOCK {'TRUE' if self.check_deadlock else 'FALSE'}")
        out.extend(self.other)
        return "\n\n".join(out) + "\n"


def _strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.S)
    return re.sub(r"\\\*.*", "", text)


def parse_cfg_file(path) -> TLCConfig:
    return parse_cfg(Path(path).read_text(encoding="utf-8"))


def parse_cfg(text: str) -> TLCConfig:
    text = _strip_comments(text)
    # A trailing "====" line is legal in .cfg files and ignored by TLC.
    text = re.sub(r"^\s*=+\s*$", "", text, flags=re.M)

    cfg = TLCConfig()
    pieces = _KW_RE.split(text)
    # pieces = [preamble, KW1, body1, KW2, body2, ...]
    const_bodies = []
    for kw, body in zip(pieces[1::2], pieces[2::2]):
        words = body.split()
        if kw == "SPECIFICATION":
            cfg.specification = words[0] if words else None
        elif kw == "INIT":
            cfg.init = words[0] if words else None
        elif kw == "NEXT":
            cfg.next = words[0] if words else None
        elif kw in ("INVARIANT", "INVARIANTS"):
            cfg.invariants += words
        elif kw in ("PROPERTY", "PROPERTIES"):
            cfg.properties += words
        elif kw in ("CONSTRAINT", "CONSTRAINTS"):
            cfg.constraints += words
        elif kw in ("ACTION_CONSTRAINT", "ACTION_CONSTRAINTS"):
            cfg.action_constraints += words
        elif kw in ("CONSTANT", "CONSTANTS"):
            const_bodies.append(body.strip("\n"))
        elif kw == "SYMMETRY":
            cfg.symmetry = words[0] if words else None
        elif kw == "VIEW":
            cfg.view = words[0] if words else None
        elif kw == "CHECK_DEADLOCK":
            cfg.check_deadlock = bool(words) and words[0].upper() == "TRUE"
        else:
            cfg.other.append(f"{kw} {body.strip()}")
    cfg.constants_text = "\n".join(b for b in const_bodies if b.strip())
    return cfg
