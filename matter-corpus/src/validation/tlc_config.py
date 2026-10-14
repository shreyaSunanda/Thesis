"""
Derive a runnable TLC configuration from a generated TLA+ module.

SANY only proves a module parses and scopes. To actually explore its state
space — which is where specification gaps show up — TLC needs a .cfg naming
the initial predicate, the next-state relation, and a CONCRETE value for every
declared CONSTANT. The generator deliberately does not emit values (the prompt
asks for CONSTANTS plus a comment saying what each one is), so this module
infers them from how each constant is *used* in the module body.

The inference is deliberately crude and conservative — it is a harness for
reaching states, not a semantic reading of the spec. Every choice it makes is
recorded in the returned dict so a config that produced an odd result can be
inspected rather than trusted blindly.

Kinds inferred, in priority order:
  numeric  - used in arithmetic/range/comparison position  -> small Nat
  boolean  - negated, compared to TRUE/FALSE, or used as a bare predicate
  set      - appears as the right side of \\in / \\subseteq / a function domain
  sentinel - named like a null/none placeholder            -> model value
  opaque   - anything else                                 -> model value

A model value is TLC's "distinct uninterpreted constant": equal to itself and
unequal to every other value, which is exactly the right semantics for a
sentinel or an unanalyzed identifier, and costs nothing in state space.
"""
import itertools
import re

NUMERIC_VALUE = 3
SET_SIZE = 2

# Matched against the whole name, case-insensitively: NullSeqNum, NULL_VALUE,
# NoneSelected and NullNodeID are all sentinels, and a model value is exactly
# the right encoding for "a distinct value that is not any of the others".
# "NoInput" is listed explicitly: the generation prompt mandates that exact
# name for the no-event sentinel, and a model value is the right encoding for
# it (distinct from every real input, comparable against anything).
_SENTINEL_NAME_HINT = re.compile(
    r"null|none|^nil$|^no_?value$|^no_?input$|undefined|unset|^empty", re.IGNORECASE
)

_NUMERIC_NAME_HINT = re.compile(
    r"max|min|size|count|limit|timeout|threshold|num|window|interval|"
    r"retries|retransmit|length|backoff|delay|idle|active|budget|capacity|"
    r"ms$|sec$|seconds$|millis",
    re.IGNORECASE,
)
_BOOLEAN_NAME_HINT = re.compile(r"^(is|has|can|should|supports?|enable)|supported$|enabled$|flag$", re.IGNORECASE)
# Deliberately NOT a bare /s$/: that matched STATUS_SUCCESS and
# ERR_NO_SHARED_TRUST_ROOTS, turning plain enum constants into two-element
# sets. Only unambiguous collection names qualify.
_SET_NAME_HINT = re.compile(
    r"set$|ids$|types$|states$|nodes$|peers$|keys$|indices$|fabrics$|sessions$|messages$",
    re.IGNORECASE,
)

# A CamelCase name ending in "s" is almost always a collection
# (DeviceSupportedVersions, MessageCounters, Senders). Requiring a lowercase
# letter immediately before an uppercase one keeps SCREAMING_CASE enum members
# out - STATUS_SUCCESS ends in "s" but is a single value, and handing it a
# two-element set breaks every comparison against it.
_CAMEL_PLURAL_HINT = re.compile(r"[a-z][A-Z].*s$")

# Definitions whose NAME says "this is a safety property to check". TLC will not
# check an invariant unless the .cfg names it explicitly, so a module that
# carefully defines NeverUndefined would otherwise be model-checked for deadlock
# only and the property silently ignored - the exact mistake that would make a
# generated model look clean when it is not.
# Deliberately strict. A loose version matched InvokeArmFailSafeZeroLength
# (an ACTION, via "^Inv") and NoMsg (a record CONSTANT, via "^No[A-Z]"), and
# TLC rejects a non-predicate named as an invariant outright - turning a
# checkable module into a config error.
_INVARIANT_NAME_HINT = re.compile(
    r"^(?:Inv(?:ariant)?(?:[A-Z_0-9]|$)|TypeOK|TypeInv|Never[A-Z]|Always[A-Z]|"
    r"Safe(?:ty)?(?:[A-Z_0-9]|$))|Invariant$|Inv$|OK$",
)

# A definition is only usable as INVARIANT if it is a STATE predicate: no
# primed variables (that would be an action) and no temporal operators.
_NOT_A_STATE_PREDICATE = re.compile(r"'|\[\]|<>|WF_|SF_|UNCHANGED|ENABLED")


def strip_comments(tla_code: str) -> str:
    """Removes (* block *) and \\* line comments so usage scans see only code."""
    code = re.sub(r"\(\*.*?\*\)", " ", tla_code, flags=re.DOTALL)
    code = re.sub(r"\\\*[^\n]*", " ", code)
    return code


def _definition_bodies(code: str) -> dict:
    """Maps each top-level nullary definition name to its body text.

    A definition runs from its "==" up to the next line that starts a new
    top-level definition (or the module terminator), which is how TLA+'s
    layout works for the generated modules this harness sees.
    """
    starts = [(m.group(1), m.start(), m.end())
              for m in re.finditer(r"^([A-Za-z_]\w*)\s*==", code, re.MULTILINE)]
    enders = [m.start() for m in re.finditer(r"^(?:[A-Za-z_]\w*\s*(?:\(.*?\))?\s*==|={4,})",
                                             code, re.MULTILINE)]
    bodies = {}
    for name, start, end in starts:
        nxt = next((e for e in enders if e > start), len(code))
        bodies[name] = code[end:nxt]
    return bodies


def parse_module(tla_code: str) -> dict:
    """Extracts module name, CONSTANTS, VARIABLES and top-level definition names."""
    code = strip_comments(tla_code)

    name_match = re.search(r"-{2,}\s*MODULE\s+(\w+)\s*-{2,}", code)
    module_name = name_match.group(1) if name_match else None

    def names_in_blocks(keyword: str) -> list:
        found = []
        for m in re.finditer(rf"^\s*{keyword}\s+(.*?)(?=^\s*(?:[A-Za-z_]\w*\s*(?:\(.*?\))?\s*==|CONSTANTS?\s|VARIABLES?\s|ASSUME\b|====))",
                             code, re.MULTILINE | re.DOTALL):
            found.extend(re.findall(r"[A-Za-z_]\w*", m.group(1)))
        return found

    # CONSTANTS may declare OPERATORS, e.g. "CalculateMrpBackoffTime(_, _)".
    # Those cannot be given a value in a .cfg - they need a definition override
    # pointing at a real operator, which there is nothing sensible to synthesize
    # from. They are separated out so the caller can say so plainly instead of
    # emitting a config TLC will reject.
    operator_constants = []
    for m in re.finditer(r"^\s*([A-Za-z_]\w*)\s*\(\s*_\s*(?:,\s*_\s*)*\)", code, re.MULTILINE):
        operator_constants.append(m.group(1))

    constants, variables = [], []
    for raw in names_in_blocks(r"CONSTANTS?"):
        if raw not in constants and raw not in operator_constants:
            constants.append(raw)
    for raw in names_in_blocks(r"VARIABLES?"):
        if raw not in variables:
            variables.append(raw)

    definitions = [m.group(1) for m in
                   re.finditer(r"^([A-Za-z_]\w*)\s*(?:\([^)]*\))?\s*==", code, re.MULTILINE)]

    # Only zero-arity definitions can be used as INVARIANT - an operator taking
    # arguments is a helper, not a property.
    nullary = {m.group(1) for m in re.finditer(r"^([A-Za-z_]\w*)\s*==", code, re.MULTILINE)}
    reserved = {"Init", "Next", "Spec", "Vars", "vars"}
    bodies = _definition_bodies(code)
    invariants = []
    for d in dict.fromkeys(definitions):
        if d not in nullary or d in reserved or not _INVARIANT_NAME_HINT.search(d):
            continue
        body = bodies.get(d, "")
        if _NOT_A_STATE_PREDICATE.search(body):
            continue
        # A bare record/set/tuple literal is a value, not a predicate (NoMsg).
        if body.lstrip().startswith(("[", "{", "<<", '"')):
            continue
        invariants.append(d)

    return {
        "module_name": module_name,
        "constants": constants,
        "variables": variables,
        "definitions": definitions,
        "operator_constants": operator_constants,
        "invariants": invariants,
        "code_no_comments": code,
    }


def _normalize_for_arithmetic(code: str) -> str:
    """
    Blanks out multi-character tokens that merely CONTAIN < > - so that a plain
    scan for arithmetic context cannot mistake them for one.

    Without this, "=> STATUS_SUCCESS" (implication), "UNCHANGED <<state, x>>"
    (tuple brackets) and "[p -> Peers]" (function set) all look like a numeric
    comparison against the following name, and enum-like constants get handed
    the number 3 - which then blows up at runtime the moment TLC compares them
    against a string. Observed on core_4.14.2.3, where all eleven protocol
    message-type constants were misread as numbers.
    """
    for token in ("|->", "<<", ">>", "=>", "->", "<-", "/\\", "\\/"):
        code = code.replace(token, " " * len(token))
    return code


def _strip_maps_to(code: str) -> str:
    """
    Blanks "|->" only, leaving plain "->" intact.

    Set detection looks for function-set syntax ([S -> T]), but a record
    literal [status |-> ERR_INVALID_PARAMETER] ends in "-> NAME]" too, which
    made every enum constant appearing as a record field value look like a set.
    Removing the maps-to arrow first keeps the two apart.
    """
    return code.replace("|->", "   ")



_STRING_CMP_CACHE = {}


def _compared_with_string(name: str, code: str) -> list:
    """String literals this constant is directly compared against, in order.

    Only DIRECT comparisons count (Name = "x", "x" = Name, Name # "x",
    Name \\in {"x", ...}). An indirect one - a variable that holds the constant
    being compared elsewhere - is not detectable this way; sentinels cover that
    case by being strings themselves.
    """
    n = re.escape(name)
    lits = []
    for pat in (rf"\b{n}\s*(?:=|#)\s*\"([^\"]*)\"",
                rf"\"([^\"]*)\"\s*(?:=|#)\s*\b{n}\b"):
        lits += re.findall(pat, code)
    m = re.search(rf"\b{n}\s*\\in\s*\{{([^}}]*)\}}", code)
    if m:
        lits += _STRING_LIT.findall(m.group(1))
    seen, out = set(), []
    for l in lits:
        if l not in seen:
            seen.add(l)
            out.append(l)
    return out


def classify_constant(name: str, code: str) -> str:
    """Guesses how a CONSTANT is meant to be used, from its occurrences in `code`."""
    n = re.escape(name)
    arith = _normalize_for_arithmetic(code)
    fnset = _strip_maps_to(code)

    # Usage beats naming: a constant genuinely used in arithmetic IS numeric,
    # whatever it is called (a "NullSeqNum" that gets incremented, say).
    numeric_patterns = [
        rf"\.\.\s*{n}\b", rf"\b{n}\s*\.\.",
        rf"\b{n}\s*[-+*%]", rf"[-+*%]\s*{n}\b",
        rf"\b{n}\s*<=?", rf"\b{n}\s*>=?", rf"<=?\s*{n}\b", rf">=?\s*{n}\b",
    ]
    if any(re.search(p, arith) for p in numeric_patterns):
        return "numeric"

    # A constant the module COMPARES AGAINST A STRING must be a string. Observed
    # in core_4.19.4.11, where "Role" was read as boolean from its name and
    # given TRUE, then compared with "GATTClient": TLC aborts with "Attempted to
    # compare equality of boolean TRUE with non-boolean". Checked before the
    # name hints for exactly that reason - usage beats naming.
    if _compared_with_string(name, code):
        return "string"

    if _SENTINEL_NAME_HINT.search(name):
        return "sentinel"

    boolean_patterns = [
        rf"~\s*{n}\b", rf"\b{n}\s*=\s*(?:TRUE|FALSE)\b", rf"(?:TRUE|FALSE)\s*=\s*{n}\b",
        rf"\bIF\s+{n}\b", rf"\b{n}\s*\\in\s*BOOLEAN\b",
        rf"/\\\s*{n}\s*$", rf"\\/\s*{n}\s*$",
    ]
    if any(re.search(p, code, re.MULTILINE) for p in boolean_patterns):
        return "boolean"

    set_patterns = [
        rf"\\in\s+{n}\b", rf"\\subseteq\s+{n}\b", rf"\b{n}\s*\\(?:cup|cap|subseteq|X)\b",
        rf"\\(?:cup|cap)\s+{n}\b", rf"\[\s*{n}\s*->", rf"->\s*{n}\s*\]",
        rf"\bSUBSET\s+{n}\b", rf"\bCardinality\(\s*{n}\s*\)",
        # Record-SET constructor: [sender: Senders, counter: MessageCounters].
        # Each field's value there is a SET to draw from, not a single value -
        # giving one a number makes the whole constructor unenumerable.
        rf"[\[,]\s*\w+\s*:\s*{n}\b",
    ]
    if any(re.search(p, fnset) for p in set_patterns):
        return "set"

    # Name hints are a last resort - they are guesses, and a wrong numeric guess
    # is far more damaging than a wrong opaque one (a model value compares
    # cleanly against anything; the number 3 does not).
    if _NUMERIC_NAME_HINT.search(name):
        return "numeric"
    if _BOOLEAN_NAME_HINT.search(name):
        return "boolean"
    if _SET_NAME_HINT.search(name):
        return "set"
    # The camelCase-plural hint does NOT apply to a name carrying an
    # underscore-separated prefix. Bit_PressResetButtonUntilLightBlinks became
    # a set of model values in core_4.3.1.11 and TLC then compared it with a
    # scalar. Such a prefix (Bit_, STATUS_, MRP_) names ONE value in a family,
    # the same reasoning that already keeps STATUS_SUCCESS out of this branch,
    # whereas CommissionerSupportedVersions really is a collection.
    if "_" not in name and _CAMEL_PLURAL_HINT.search(name):
        return "set"
    return "opaque"


def applied_as_function(name: str, code: str) -> bool:
    """True if the module indexes this constant, e.g. MaxWindowSize["Server"].

    Such a constant needs a FUNCTION value, whose domain only the module's
    author knows - there is nothing to infer it from here. Detected so the
    harness can say so instead of handing TLC a scalar and letting it fail with
    "a non-function (an integer) was applied as a function".
    """
    # "|->" is rewritten to a non-blank token rather than blanked: blanking it
    # turns "counter |-> [a |-> 1]" into "counter    [a    1]", which then looks
    # exactly like indexing `counter`.
    code = code.replace("|->", "|=>")
    return re.search(rf"\b{re.escape(name)}\s*\[", code) is not None


def constant_value(name: str, kind: str, bool_choice: bool = True,
                   literal: str = None) -> str:
    """Renders the cfg right-hand side for one constant."""
    if kind == "numeric":
        return str(NUMERIC_VALUE)
    if kind == "boolean":
        return "TRUE" if bool_choice else "FALSE"
    if kind == "set":
        return "{" + ", ".join(f"{name}_{i}" for i in range(1, SET_SIZE + 1)) + "}"
    if kind == "string":
        # One of the literals the module compares it against, so a real branch
        # is exercised. This PINS that branch, the same way a boolean would -
        # not varied across configs today, which is a known gap.
        return f'"{literal or name}"'
    # sentinel / opaque: a model value named after the constant itself.
    #
    # MEASURED, not assumed. Rendering these as strings instead was tried, to
    # fix core_4.6.7 where a model value met the string "Unsecured". Re-running
    # the whole ch45_v4 corpus recovered that one unit and broke three others
    # in the mirror-image way - "check equality of string \"NoSession\" with
    # non-string" (core_4.8.2), "compare integer 3 with non-integer"
    # (core_4.12.1), "check equality of record" (core_4.14.2.3). Model values
    # win 3 to 1, so they stay.
    #
    # KNOWN LIMITATION: a sentinel reached indirectly still breaks. In
    # core_4.6.7 NullState is never compared with a string itself - it is
    # stored in rxStates and rxStates[c] is compared with "Unsecured". Only
    # dataflow would catch that; the "string" kind above only sees direct
    # comparisons.
    return name


def plan_configs(tla_code: str, max_configs: int = 4) -> dict:
    """
    Works out every .cfg needed to exercise a module.

    Boolean constants are the only ones worth varying: a device-capability flag
    like ConcurrentConnectionSupported gates whole branches of the model, so
    pinning it to one value would leave half the spec's behavior unreachable
    and silently under-report gaps. With few enough booleans every combination
    is run; past that the combinations are capped at all-TRUE / all-FALSE and
    the result is flagged `partial_boolean_coverage` so the gap report never
    claims coverage it does not have.
    """
    info = parse_module(tla_code)
    code = info["code_no_comments"]

    kinds = {c: classify_constant(c, code) for c in info["constants"]}
    literals = {c: (_compared_with_string(c, code) or [None])[0]
                for c in info["constants"] if kinds[c] == "string"}
    indexed = [c for c in info["constants"] if applied_as_function(c, code)]
    bools = [c for c, k in kinds.items() if k == "boolean"]

    if not bools:
        combos = [{}]
        partial = False
    elif 2 ** len(bools) <= max_configs:
        combos = [dict(zip(bools, choice))
                  for choice in itertools.product([True, False], repeat=len(bools))]
        partial = False
    else:
        combos = [{b: True for b in bools}, {b: False for b in bools}]
        partial = True

    has_spec = "Spec" in info["definitions"]
    configs = []
    for combo in combos:
        lines = []
        if has_spec:
            lines.append("SPECIFICATION Spec")
        else:
            lines.append("INIT Init")
            lines.append("NEXT Next")
        for inv in info["invariants"]:
            lines.append(f"INVARIANT {inv}")
        if info["constants"]:
            lines.append("")
            lines.append("CONSTANTS")
            for c in info["constants"]:
                lines.append(f"    {c} = "
                             f"{constant_value(c, kinds[c], combo.get(c, True), literals.get(c))}")
        configs.append({
            "bool_assignment": {k: bool(v) for k, v in combo.items()},
            "text": "\n".join(lines) + "\n",
        })

    return {
        "module_name": info["module_name"],
        "constants": info["constants"],
        "variables": info["variables"],
        "constant_kinds": kinds,
        "string_literals": literals,
        "operator_constants": info["operator_constants"],
        "indexed_constants": indexed,
        "invariants": info["invariants"],
        "uses_spec": has_spec,
        "has_init": "Init" in info["definitions"],
        "has_next": "Next" in info["definitions"],
        "partial_boolean_coverage": partial,
        "configs": configs,
    }


# ---------------------------------------------------------------------------
# Input alphabet recovery
#
# WHY: the detector asks "an event is pending - can any action consume it?".
# That question is only meaningful if the pending event is one the module can
# RECOGNISE. Classifying `Inputs` as a generic set and filling it with model
# values (Inputs_1, Inputs_2) makes every input unrecognisable by construction:
# `Inputs_1` never equals "ReceiveAck", so no handler guard ever matches and
# every module reports a gap at depth 2. That is a harness artifact, not a
# finding - it was caught on the first 5-module run, where 4 modules "found a
# gap" with identical 2-state traces and the 5th crashed dereferencing a field
# of a model value.
#
# The real alphabet is already in the module: it is exactly the set of literals
# its guards compare pendingInput against.
# ---------------------------------------------------------------------------

_INPUT_VAR = "pendingInput"

# pendingInput = "Literal"
_EQ_STRING = re.compile(rf"\b{_INPUT_VAR}\s*=\s*\"([^\"]*)\"")
# pendingInput \in {"A", "B"}
_IN_SET = re.compile(rf"\b{_INPUT_VAR}\s*\\in\s*\{{([^}}]*)\}}")
_STRING_LIT = re.compile(r"\"([^\"]*)\"")
# Shapes this recovery deliberately does NOT handle, see below.
_EQ_RECORD = re.compile(rf"\b{_INPUT_VAR}\s*=\s*\[")
_FIELD_ACCESS = re.compile(rf"\b{_INPUT_VAR}\s*\.\s*[A-Za-z_]")


def extract_input_alphabet(tla_code: str) -> dict:
    """
    Recovers the inputs a module can actually recognise.

    Returns {"literals": [...], "structured": bool}.

    `structured` is True when the module matches pendingInput against RECORDS
    ([type |-> "X", seq |-> s]) or reads fields off it. Those alphabets cannot
    be recovered by scanning literals: the record patterns carry free variables
    bound by enclosing quantifiers, so building the set means inventing domains
    for them, and a wrong domain silently changes what the model checks. Such
    modules are reported as not-checkable rather than run with a guessed
    alphabet - the same rule this harness already applies to timeouts: no
    verdict is a distinct answer from "no gap found".
    """
    code = strip_comments(tla_code)
    structured = bool(_EQ_RECORD.search(code) or _FIELD_ACCESS.search(code))

    literals = []
    for m in _EQ_STRING.finditer(code):
        literals.append(m.group(1))
    for m in _IN_SET.finditer(code):
        literals.extend(_STRING_LIT.findall(m.group(1)))

    seen, ordered = set(), []
    for lit in literals:
        if lit not in seen:
            seen.add(lit)
            ordered.append(lit)
    return {"literals": ordered, "structured": structured}


def input_alphabet_tla(literals: list) -> str:
    """The alphabet as a TLA+ set expression, for the detector wrapper."""
    return "{" + ", ".join(f'"{lit}"' for lit in literals) + "}"


# --- record-shaped alphabets -----------------------------------------------
#
# Some modules match pendingInput against a RECORD rather than a name:
#
#     \E seq \in SeqNums, hasAck \in BOOLEAN, ackSeq \in SeqNums :
#         pendingInput = [type |-> "ReceivePacket", seq |-> seq, ...]
#
# The field values that are not literals are quantifier-bound, and the bound is
# stated right there in the \E. So the record set is READ from the module, not
# invented: [type: {"ReceivePacket"}, seq: SeqNums, hasAck: BOOLEAN, ...].
#
# This only works when every non-literal field has a recoverable bound. A
# module that merely reads fields off pendingInput (pendingInput.msg) never
# writes the record down, so nothing states what a msg is; those still come
# back unrecoverable, because inventing that domain is the exact mistake this
# whole mechanism exists to avoid.

_RECORD_PATTERN = re.compile(rf"\b{_INPUT_VAR}\s*=\s*\[([^\[\]]*)\]")
_FIELD = re.compile(r"([A-Za-z_]\w*)\s*\|->\s*(.+)")
_QUANT_BINDING = re.compile(r"([A-Za-z_]\w*)\s*\\in\s*([^,:]+?)\s*(?=,|:|$)")


def _bindings_before(code: str, pos: int) -> dict:
    """Variable -> bound, from the nearest \\E quantifier preceding `pos`."""
    start = code.rfind("\\E", 0, pos)
    if start == -1:
        return {}
    head = code[start + 2:pos]
    # Only the quantifier head, up to the ":" that opens its body.
    head = head.split(":")[0]
    return {m.group(1): m.group(2).strip() for m in _QUANT_BINDING.finditer(head)}


def extract_record_alphabet(tla_code: str) -> dict:
    """
    Recovers a record-shaped input alphabet.

    Returns {"sets": [tla set expressions], "unresolved": [field names]}.
    `unresolved` non-empty means the alphabet must not be used: at least one
    field's domain is not stated anywhere in the module.
    """
    code = strip_comments(tla_code)
    sets, unresolved = [], []

    for m in _RECORD_PATTERN.finditer(code):
        bindings = _bindings_before(code, m.start())
        parts = []
        for raw in _split_fields(m.group(1)):
            fm = _FIELD.match(raw.strip())
            if not fm:
                continue
            name, value = fm.group(1), fm.group(2).strip()
            if value.startswith('"') and value.endswith('"'):
                parts.append(f"{name}: {{{value}}}")
            elif value in bindings:
                parts.append(f"{name}: {bindings[value]}")
            else:
                unresolved.append(f"{name} (= {value})")
        if parts:
            sets.append("[" + ", ".join(parts) + "]")

    # Fields read off pendingInput but never written in any record pattern: the
    # module's own text never says what they range over.
    written = {f.split(":")[0] for s in sets for f in s.strip("[]").split(", ")}
    for fm in re.finditer(rf"\b{_INPUT_VAR}\s*\.\s*([A-Za-z_]\w*)", code):
        if fm.group(1) not in written:
            unresolved.append(f"{fm.group(1)} (read but never constructed)")

    seen, uniq = set(), []
    for u in unresolved:
        if u not in seen:
            seen.add(u)
            uniq.append(u)
    return {"sets": sets, "unresolved": uniq}


def _split_fields(body: str) -> list:
    """Splits a record body on top-level commas."""
    out, depth, cur = [], 0, ""
    for ch in body:
        if ch in "[{(":
            depth += 1
        elif ch in "]})":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return out


def record_alphabet_tla(sets: list) -> str:
    """The union of the recovered record sets."""
    return " \\cup ".join(sets)


# ---------------------------------------------------------------------------
# Declared input alphabet (prompt rule 4a)
#
# Recovering the alphabet from guards can only ever find events some action
# HANDLES - a guard is what it scans for. An event that no action handles has
# no guard, so it is never recovered, never delivered to the model, and can
# never be reported. That is the most valuable finding available here ("the
# spec says this arrives and never says what to do with it in any state") and
# the guard scan is structurally blind to it.
#
# Rule 4a therefore makes the module write the alphabet out as a DEFINITION.
# When it is there, it is authoritative: it is what the generator believed the
# section can receive, including events it deliberately left unhandled. The
# guard scan stays only as a fallback for modules generated before that rule.
# ---------------------------------------------------------------------------

_DECLARED_INPUTS = re.compile(r"^[ \t]*Inputs\s*==\s*\{([^}]*)\}", re.MULTILINE)


def extract_declared_alphabet(tla_code: str) -> list:
    """The events a module declares in `Inputs == {...}`, in written order.

    Returns [] when the module declares no such definition (it predates rule
    4a, or declared Inputs as a CONSTANT), which is the caller's signal to fall
    back to scanning guards.
    """
    m = _DECLARED_INPUTS.search(strip_comments(tla_code))
    if not m:
        return []
    seen, ordered = set(), []
    for lit in _STRING_LIT.findall(m.group(1)):
        if lit not in seen:
            seen.add(lit)
            ordered.append(lit)
    return ordered


def unhandled_everywhere(declared: list, handled: list) -> list:
    """Declared events that no guard in the module matches.

    Reported so the gap report can say WHY an event went unhandled: one that no
    action mentions at all is a different and stronger finding than one that is
    handled in some states but not the state it arrived in.
    """
    return [e for e in declared if e not in set(handled)]


# Rule 4b: the module says when it is past setup. Read only for ranking - a
# finding in a state the device genuinely sits in outranks one in scaffolding.
_OPERATIONAL_DEF = re.compile(r"^[ \t]*Operational\s*==", re.MULTILINE)


def declares_operational(tla_code: str) -> bool:
    return bool(_OPERATIONAL_DEF.search(strip_comments(tla_code)))
