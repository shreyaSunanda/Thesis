"""
Fixed TLA+ generation prompt template.

Forces every LLM, regardless of provider, into the same module "shape" so
outputs are structurally comparable later (Phase 3 agreement analysis) rather
than differing only because of arbitrary naming choices.
"""

TLA_GENERATION_TEMPLATE = """You are translating a section of the Matter IoT protocol specification into a formal TLA+ model.

SPEC TEXT FOR THIS UNIT ({unit_id} - {unit_title}):
---
{unit_text}
---

RELATED SECTIONS THIS UNIT REFERENCES (context only - do not model these directly unless the primary text above requires it):
---
{context_text}
---

Generate a TLA+ module following this exact structure:

---- MODULE {module_name} ----
EXTENDS Naturals

\\* Declare EVERY fixed value the spec text mentions (timeouts, limits, thresholds,
\\* fabric indices, etc.) here. Give each one a short comment saying what it is.
\\* If the spec text requires no fixed values, omit this line entirely.
CONSTANTS ConstName1, ConstName2

\\* pendingInput and the NoInput constant are REQUIRED - see rule 4a.
CONSTANTS NoInput
VARIABLES state, pendingInput   \\* add more variables only if the spec text requires them

\\* REQUIRED - the complete list of events this section can receive. See rule 4a.
Inputs == {"EventName1", "EventName2", "EventName3"}

Init == ...

\\* One action per distinct transition described in the spec text.
\\* Each action MUST have a comment directly above it: \\* SOURCE: {unit_id} <clause reference>
ActionName == ...

Next == \\/ Action1 \\/ Action2 \\/ ...

====

RULES:
1. Only model behavior explicitly stated in the spec text above. Do not invent transitions.
2. If the spec text is ambiguous or leaves a case unspecified, add a comment "\\* TODO: unspecified - <describe the gap>" instead of guessing.
3. Every action must cite its source with a "\\* SOURCE:" comment as shown above.
4. Do NOT include Undefined/Contradictory catch-all states or invariants - those are
   added separately by the gap-detection tooling, not by you. What you MUST do instead
   is give the module the fixed input shape described in rule 4a, which is what that
   tooling attaches to.
4a. MANDATORY INPUT SHAPE. The whole point of this exercise is to find situations the
   spec text does not say how to handle. A model that only ever does what the spec
   describes can never reveal one, so every module MUST make incoming events explicit,
   using EXACTLY these names:
     - CONSTANTS NoInput          \\* sentinel: nothing is waiting to be handled
     - VARIABLES pendingInput     \\* the event currently waiting, or NoInput
     - Inputs                     \\* a DEFINITION listing every event, see below
   "Inputs" is a DEFINITION, not a CONSTANT. Write the events out, in the module:
       Inputs == {"ArmFailSafe", "CommissioningComplete", "FailSafeTimeout"}
   Declaring it as "CONSTANTS Inputs" is WRONG: a TLA+ constant is a parameter, so a
   module cannot say what is in it, and the list is then lost.
   EVERY element of Inputs SHALL be a plain quoted string naming ONE event. Do not
   use records, tuples or structures as events. This is WRONG:
       Inputs == {[type |-> "ReceivePacket", seq |-> 3]}      \\* NO
   If an event carries data - a sequence number, a message, a node id - model that
   data as a SEPARATE VARIABLE that the handling action reads, not as a field of
   pendingInput. Never write "pendingInput.something" anywhere.
   "Inputs" must list every event the spec text mentions arriving at this component:
   commands, messages, responses, timer expiries, connection-loss events, user actions.
   Include events the spec mentions only in passing, and events it says arrive in
   SOME states - the interesting question is what happens when one arrives in a state
   the text never considers. LIST AN EVENT EVEN IF NO ACTION BELOW HANDLES IT: an
   event the spec says arrives but never says how to handle is the most valuable
   thing this exercise can find, and omitting it from Inputs hides it completely.
   Then:
     - Init SHALL set pendingInput = NoInput.
     - Include exactly one action that delivers an event:
           ReceiveInput(e) ==
               /\\ pendingInput = NoInput
               /\\ e \\in Inputs
               /\\ pendingInput' = e
               /\\ UNCHANGED <<every other variable>>
       and include it in Next as: \\E e \\in Inputs : ReceiveInput(e)
     - EVERY action that handles an event SHALL require a specific pendingInput value
       and clear it, e.g.
           /\\ pendingInput = "CommissioningComplete"
           /\\ ... guards the spec gives ...
           /\\ pendingInput' = NoInput
     - Actions that are NOT event-driven (internal timeouts you model as spontaneous,
       bookkeeping) SHALL leave pendingInput UNCHANGED.
   Do NOT add an action that silently discards an unhandled event. If the spec text
   does not say what happens when some event arrives in some state, leave that case
   unhandled - that silence is exactly what is being measured.
5. HARD REQUIREMENT - no undeclared identifiers: every name you use anywhere in the
   module (in Init, in any action, in Next) must be one of: (a) listed in CONSTANTS,
   (b) listed in VARIABLES, or (c) defined earlier in this same module with
   "Name == ...". Never reference a name that isn't declared or defined somewhere
   in the module - TLA+ has no implicit declarations, and an undefined name is a
   hard parse failure, not a warning.
6. If you need a field-like value on state (e.g. an expiry time, a fabric index,
   a flag), model it as an explicit VARIABLE (e.g. "expiry", "accessingFabricIndex")
   or as a field of a record-valued VARIABLE (e.g. "state.accessingFabricIndex"),
   never as a bare standalone name that was never declared.
7. If a step in the spec text describes a helper procedure or sub-behavior (e.g.
   "reset operational credentials", "remove orphaned RCACs"), you must either:
   (a) inline its logic directly into the action that needs it, or
   (b) define it explicitly elsewhere in the module with "HelperName == ...".
   Do not reference a helper name as if it were a predefined operator.
8. TLA+ is NOT Python/C/pseudocode. It has its own operator symbols, and using
   keyword-style logic operators is a hard PARSE failure (worse than a semantic
   error - the whole file becomes unparseable). Use exactly these:
     - negation:        ~x            (never "NOT x")
     - and:              /\\ or  x /\\ y   (never "AND")
     - or:               \\/ or  x \\/ y   (never "OR")
     - implication:      x => y        (never "IMPLIES" as a symbol)
     - equality (test):  x = y        ONE equals sign. "x == y" is NOT a
                          comparison: "==" DEFINES a new operator, so SANY
                          treats it as the start of a new definition and the
                          surrounding expression becomes unparseable. Use "=="
                          ONLY at the top level, to introduce a definition
                          ("Init == ...", "Next == ..."), never inside one.
     - not equal:        x # y   or  x /= y
     - inequality:       <, >, <=, >=  (no "ELSEIF" - use nested IF/THEN/ELSE,
                          or CASE ... -> ... [] ... -> ... OTHER -> ...)
     - for all / exists: \\A x \\in S : P(x)     \\E x \\in S : P(x)
   Before finalizing, re-read every IF/boolean expression you wrote and confirm
   none of them contain the English words NOT, AND, OR, ELSEIF, or IMPLIES used
   as if they were operators, and that every "==" in the module begins a
   top-level definition rather than comparing two values.
9. Do not assume ANY value, attribute, or helper operator exists outside this
   module unless it is a standard Naturals operator (e.g. +, -, <, >). This
   includes things that feel like they belong to a larger surrounding system
   (a global clock, a device's attribute list, a fabric table, a credentials
   store, etc.) - if the spec text implies such a thing exists, YOU must still
   declare it in THIS module: as a CONSTANT if fixed, a VARIABLE if it changes,
   or a "Name == ..." definition if it's derived/computed. Concretely, watch
   for these patterns and never leave them undeclared:
     - "current time now" / "current time" -> declare a VARIABLE (e.g. "now")
       and advance it explicitly in some action, or declare it as a CONSTANT
       if the spec text treats it as externally supplied.
     - "the set of all fabric indices" / "index 1-254" -> declare a CONSTANT
       set (e.g. "CONSTANTS FabricIndexSet") and use that, not a bare name.
     - a sentinel "no value" / "null" / "none" -> declare a CONSTANT for it
       (e.g. "CONSTANTS NullValue") rather than using an undeclared "Null".
     - any attribute list, table, or store the action reads/writes (networks,
       fabrics, credentials, sessions, etc.) -> declare it as a VARIABLE of
       this module and thread it through Init/actions/UNCHANGED like every
       other piece of state - never reference it as if some other module
       already defines it.
     - any helper computation used as a function call (e.g. "remove X from Y",
       "is a session active for fabric f") -> covered by rule 7: define it
       with "Name == ..." in this module, do not assume it exists.
10. TLA+ SYNTAX GOTCHAS that are hard parse failures. Every one of these was
   observed in real generated output, so check each before finalizing:
   a. TUPLES use double angle brackets: UNCHANGED <<a, b, c>>. Single angle
      brackets (<a, b, c>) do not parse - "<" is the less-than operator.
   b. SET DIFFERENCE is a single backslash: S \\ T. There is no "\\setminus"
      operator in TLA+ (that is LaTeX, not TLA+). Likewise use \\cup, \\cap,
      \\subseteq, \\in, \\notin - no other LaTeX-style word operators exist.
   c. RECORD FIELD LABELS must be bare identifiers, never strings:
         [state |-> "Idle", counter |-> 0]        \\* correct
         ["Client" |-> 5, "Server" |-> 4]         \\* WRONG - will not parse
      To build a mapping whose keys are strings or come from a set, use
      function notation with an explicit binder instead:
         [p \\in Peers |-> IF p = "Client" THEN 5 ELSE 4]
   d. SET CONSTRUCTORS come in exactly two forms, and mixing them does not parse:
         {x \\in S : P(x)}          \\* filter: pick elements of S satisfying P
         {f(x) : x \\in S}          \\* map: apply f to every element of S
      You may NOT put a condition in the map form
      ({e.id : e \\in S /\\ e.node = n} is WRONG). Filter first, then map:
         {e.id : e \\in {x \\in S : x.node = n}}
   e. QUANTIFIER BOUNDS IN ONE LIST ARE INDEPENDENT. In "\\E a \\in S, b \\in T",
      T may NOT mention a - all bounds are evaluated in the same outer scope,
      so a later bound referring to an earlier variable is an "Unknown
      operator" error. Nest the quantifiers instead:
         \\E sender \\in Nodes, ex \\in exchanges[sender] : P   \\* WRONG
         \\E sender \\in Nodes : \\E ex \\in exchanges[sender] : P   \\* correct
11. INDENTATION - TLA+ conjunction/disjunction lists are whitespace-sensitive,
   and getting this wrong is the single most common parse failure. Inside a
   "/\\" or "\\/" list, EVERY line belonging to an item must be indented strictly
   further right than the "/\\" (or "\\/") bullet itself. A line that returns to
   the bullet's own column ends the list.
   The practical consequence: do NOT split a record, set, tuple or function
   literal across multiple lines inside a conjunction list unless every
   continuation line - INCLUDING the closing "]" or "}" - is indented deeper
   than the bullet. This is WRONG and will not parse, because the closing "]"
   sits at the bullet's column:
       /\\ initiator = [
           state |-> "INIT",
           peerId |-> Null
       ]
   Prefer keeping such literals on a single line:
       /\\ initiator = [state |-> "INIT", peerId |-> Null]
   or, if too long, indent the whole literal past the bullet:
       /\\ initiator = [state  |-> "INIT",
                       peerId |-> Null]
   THE RELIABLE WAY TO AVOID THIS ENTIRELY: if a record, set or EXCEPT literal
   does not fit on ONE line, do not inline it in a conjunction list at all.
   Hoist it into its own top-level definition above the action and refer to it
   by name. Instead of this:
       Action ==
           /\\ network' = network \\cup {[EmptyMessage EXCEPT
               !.type = "PBKDFParamRequest",
               !.sessionId = sid
           ]}
   write this:
       ParamRequest(sid) == [EmptyMessage EXCEPT !.type = "PBKDFParamRequest",
                                                 !.sessionId = sid]
       Action ==
           /\\ network' = network \\cup {ParamRequest(sid)}
   A definition body is not inside a conjunction list, so its layout cannot
   break one. Apply this to EVERY multi-line literal you are tempted to write
   inside an action - records with many fields, long EXCEPT chains, big set
   literals.
   Also: never leave a blank or whitespace-only line in the middle of a
   conjunction list, and never use tab characters anywhere in the module.
12. FINITE STATE SPACE - this module will be model-checked with TLC, which has
   to enumerate every value you quantify over. Never quantify over, or draw a
   variable's value from, an infinite set:
     - "\\E n \\in Nat" / "\\A n \\in Int" are WRONG. Use an explicit finite
       range bounded by a CONSTANT you declared: "\\E n \\in 0..MaxSeqNum".
     - "Seq(S)" is infinite, so it is WRONG as a quantifier bound or as the set
       a variable ranges over. Model a bounded buffer as a set, or declare a
       maximum length constant and use "[1..MaxLen -> S]".
     - "SUBSET S" is acceptable ONLY when S is a small finite CONSTANT set.
   For the same reason, never let a counter grow without bound: any action of
   the form "x' = x + 1" must be guarded by an explicit upper bound
   (e.g. "/\\ x < MaxX"), or the state space is infinite and nothing can be
   checked. Wrap-around ("x' = (x + 1) % Modulus") is also fine.
13. NEVER declare a CONSTANT that takes arguments (e.g.
   "CONSTANTS CalculateBackoffTime(_, _)"). An operator CONSTANT has no value a
   model checker can be given - it needs a definition supplied from outside the
   module, which makes the module uncheckable on its own. If the spec text
   describes a computation you cannot express exactly (floating point, randomness,
   cryptography), define it in THIS module as a deterministic abstraction over
   what you can express, e.g.
       \\* Abstraction: backoff grows with the retry count; jitter is ignored.
       BackoffTime(n) == BaseInterval * (n + 1)
   and add a "\\* TODO: unspecified - ..." comment saying what you abstracted away.
14. USE SMALL ABSTRACT BOUNDS, NOT REAL-WORLD MAGNITUDES. The model will be
   enumerated by a model checker, so a literal like 4294967296 (2^32, a message
   counter range) or 65535 makes it uncheckable even though it is what the spec
   says. Declare such a limit as a CONSTANT with a comment giving the real value,
   and let the checking harness pick a small one:
       \\* Message counter space. Real value per spec: 2^32.
       CONSTANTS CounterModulus
   Never write the real magnitude as a literal in the module body.
15. EVERY ACTION MUST ACCOUNT FOR EVERY VARIABLE. In each action, each name you
   listed in VARIABLES must either get a primed assignment (x' = ...) or appear
   in an UNCHANGED clause. Leaving one out does not mean "it keeps its value" -
   it means the action says nothing about it, and a model checker rejects the
   step with "successor state is not completely specified ... the following
   variable is not assigned". Before finalizing each action, list your variables
   and tick off every one:
       Act ==
           /\\ state' = "Armed"
           /\\ timer' = 0
           /\\ UNCHANGED <<breadcrumb, pendingMsg>>   \\* every remaining variable
16. Output ONLY the TLA+ module code. No explanation before or after it, no markdown commentary.
"""


def build_prompt(unit_id: str, unit_title: str, unit_text: str, context_text: str, module_name: str) -> str:
    """
    Fills the template by plain substitution, NOT str.format().

    The rules section contains literal TLA+ set syntax ({x \\in S : P(x)}), and
    str.format() reads every brace as a field name - so adding a correct TLA+
    example to the prompt would blow up with a KeyError at generation time.
    Substituting the named placeholders directly keeps the template free to
    show real TLA+ code.
    """
    values = {
        "{unit_id}": unit_id,
        "{unit_title}": unit_title,
        "{unit_text}": unit_text,
        "{context_text}": context_text or "(none)",
        "{module_name}": module_name,
    }
    prompt = TLA_GENERATION_TEMPLATE
    for placeholder, value in values.items():
        prompt = prompt.replace(placeholder, str(value))
    return prompt