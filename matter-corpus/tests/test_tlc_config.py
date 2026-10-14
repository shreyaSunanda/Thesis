"""
Regression tests for TLC config inference.

Every case here is a real misclassification observed while running the ch4/ch5
batch, not a synthetic example - the classifier is a heuristic, so the only
thing keeping it honest is pinning the mistakes it has actually made.
"""
import pytest

from src.validation.tlc_config import classify_constant, parse_module, plan_configs


def test_implication_arrow_is_not_a_numeric_comparison():
    """"=> STATUS_SUCCESS" contains ">", but it is implication, not a comparison.

    Misreading it assigned the number 3 to all eleven protocol message-type
    constants of core_4.14.2.3, which then crashed TLC the moment one was
    compared against a string.
    """
    code = "Resp == responderState = \"DONE\" => status' = STATUS_SUCCESS"
    assert classify_constant("STATUS_SUCCESS", code) == "opaque"


def test_tuple_brackets_are_not_a_numeric_comparison():
    code = "A == UNCHANGED <<MSG_SIGMA1, state>>"
    assert classify_constant("MSG_SIGMA1", code) == "opaque"


def test_record_field_value_is_not_a_function_set():
    """[status |-> ERR_X] ends in "-> NAME]" but is a record, not [S -> T]."""
    code = "A == out' = [status |-> ERR_INVALID_PARAMETER]"
    assert classify_constant("ERR_INVALID_PARAMETER", code) == "opaque"


def test_function_set_still_detected_as_set():
    code = "Init == counters \\in [Peers -> 0..3]"
    assert classify_constant("Peers", code) == "set"


def test_enum_like_name_ending_in_s_is_not_a_set():
    """A bare /s$/ hint turned ERR_NO_SHARED_TRUST_ROOTS into a two-element set."""
    code = "A == status' = ERR_NO_SHARED_TRUST_ROOTS"
    assert classify_constant("ERR_NO_SHARED_TRUST_ROOTS", code) == "opaque"


def test_genuine_arithmetic_use_is_numeric():
    code = "A == /\\ e \\in 1..MaxExpiry\n      /\\ window' = MaxWindowSize - 1"
    assert classify_constant("MaxExpiry", code) == "numeric"
    assert classify_constant("MaxWindowSize", code) == "numeric"


def test_null_named_constant_is_a_sentinel_even_with_num_in_the_name():
    """NullSeqNum was read as numeric by the "num" name hint and given 3."""
    code = "Init == pendingAck = NullSeqNum"
    assert classify_constant("NullSeqNum", code) == "sentinel"


def test_arithmetic_use_overrides_a_sentinel_name():
    """Usage beats naming: a 'Null' constant that gets incremented is numeric."""
    code = "A == seq' = NullSeqNum + 1"
    assert classify_constant("NullSeqNum", code) == "numeric"


def test_boolean_capability_flag_detected():
    code = "A == /\\ chan' = (IF ~ConcurrentConnectionSupported THEN \"Closed\" ELSE chan)"
    assert classify_constant("ConcurrentConnectionSupported", code) == "boolean"


MODULE = """---- MODULE Demo ----
EXTENDS Naturals

CONSTANTS MaxExpiry, NullValue, FlagA

VARIABLES state, pending

TypeOK == state \\in {"a", "b"}
NeverUndefined == state # "Undefined"
Helper(x) == x + 1
Gate == IF FlagA THEN state = "a" ELSE state = "b"

Init == /\\ state = "a" /\\ pending = NullValue
Next == /\\ state' = "b" /\\ UNCHANGED pending
====
"""


def test_parse_module_finds_declarations_and_invariants():
    info = parse_module(MODULE)
    assert info["module_name"] == "Demo"
    assert info["constants"] == ["MaxExpiry", "NullValue", "FlagA"]
    assert info["variables"] == ["state", "pending"]
    # Both property-shaped names picked up; the parameterised helper is not a
    # candidate invariant, and neither are Init/Next.
    assert set(info["invariants"]) == {"TypeOK", "NeverUndefined"}
    assert "Helper" not in info["invariants"]


def test_plan_configs_emits_a_runnable_cfg():
    plan = plan_configs(MODULE)
    assert plan["has_init"] and plan["has_next"] and not plan["uses_spec"]
    cfg = plan["configs"][0]["text"]
    assert "INIT Init" in cfg and "NEXT Next" in cfg
    assert "INVARIANT NeverUndefined" in cfg
    assert "MaxExpiry = 3" in cfg
    assert "NullValue = NullValue" in cfg       # model value, not a string


def test_single_boolean_constant_is_run_both_ways():
    """A capability flag gates whole branches - pinning it hides behavior."""
    plan = plan_configs(MODULE)
    assignments = [c["bool_assignment"]["FlagA"] for c in plan["configs"]]
    assert sorted(assignments) == [False, True]
    assert not plan["partial_boolean_coverage"]


def test_many_booleans_fall_back_to_capped_coverage_and_say_so():
    code = MODULE.replace("CONSTANTS MaxExpiry, NullValue, FlagA",
                          "CONSTANTS MaxExpiry, NullValue, FlagA, FlagB, FlagC")
    code = code.replace("Gate == ", "Guard == FlagB = TRUE /\\ FlagC = TRUE\nGate == ")
    plan = plan_configs(code, max_configs=4)
    assert plan["partial_boolean_coverage"]
    assert len(plan["configs"]) == 2


def test_record_set_constructor_field_is_a_set():
    """[sender: Senders, counter: MessageCounters] draws each field from a SET.

    Giving MessageCounters the number 3 made the whole constructor
    unenumerable ("can't enumerate the value of the `counter' field: 3").
    """
    code = "ValidMessages == [sender: Senders, counter: MessageCounters]"
    assert classify_constant("MessageCounters", code) == "set"
    assert classify_constant("Senders", code) == "set"


def test_camelcase_plural_is_a_set_but_screaming_case_is_not():
    """DeviceSupportedVersions is a collection; STATUS_SUCCESS is one value."""
    code = "A == msg' = [versions |-> CommissionerSupportedVersions]"
    assert classify_constant("CommissionerSupportedVersions", code) == "set"
    assert classify_constant("STATUS_SUCCESS", code) == "opaque"


def test_constant_indexed_as_a_function_is_flagged():
    """MaxWindowSize["Server"] needs a function value whose domain we cannot infer."""
    from src.validation.tlc_config import applied_as_function
    code = 'Init == w = [p \\in Peers |-> MaxWindowSize["Server"]]'
    assert applied_as_function("MaxWindowSize", code)
    assert not applied_as_function("Peers", code)


def test_maps_to_arrow_is_not_function_application():
    """"counter |-> [..." must not read as indexing `counter`."""
    from src.validation.tlc_config import applied_as_function
    assert not applied_as_function("counter", 'r == [counter |-> [a |-> 1]]')


# ---------------------------------------------------------------------------
# Input-alphabet recovery.
#
# These pin the harness artifact found on the first ch45_v2 run: Inputs was
# classified as a generic set and filled with model values, so no guard could
# ever match the pending input and 4 of 5 modules "found a gap" at depth 2 with
# identical traces. The alphabet has to come from the module's own guards.
# ---------------------------------------------------------------------------
from src.validation.tlc_config import (extract_input_alphabet, input_alphabet_tla,
                                         extract_record_alphabet, record_alphabet_tla)


def test_alphabet_from_equality_guards():
    """The real core_5.5 shape: handlers compare against string literals."""
    code = '''
    HandleReq == /\\ pendingInput = "PASE_PBKDFParamRequest"
                 /\\ pendingInput' = NoInput
    HandlePake == /\\ pendingInput = "PASE_PAKE3"
                  /\\ pendingInput' = NoInput
    '''
    got = extract_input_alphabet(code)
    assert got["literals"] == ["PASE_PBKDFParamRequest", "PASE_PAKE3"]
    assert got["structured"] is False


def test_alphabet_includes_set_membership_guards():
    """core_5.5 also uses `pendingInput \\in {...}` for shared handlers."""
    code = 'Close == /\\ pendingInput \\in {"CloseSession", "NFC_SELECT"}'
    assert extract_input_alphabet(code)["literals"] == ["CloseSession", "NFC_SELECT"]


def test_record_matching_is_reported_not_guessed():
    """
    core_4.20.3.8 matches records carrying quantifier-bound variables. The
    alphabet cannot be recovered without inventing domains for them, so this
    must be flagged rather than silently approximated.
    """
    code = 'Handle == /\\ pendingInput = [type |-> "ReceivePacket", seq |-> s]'
    assert extract_input_alphabet(code)["structured"] is True


def test_field_access_also_counts_as_structured():
    """core_4.12.5.1 crashed on pendingInput.type - same class, must be caught."""
    code = 'Handle == /\\ pendingInput.type = "Send"'
    assert extract_input_alphabet(code)["structured"] is True


def test_no_input_sentinel_is_not_part_of_the_alphabet():
    """`pendingInput = NoInput` is the idle guard, not a receivable event."""
    code = 'Idle == /\\ pendingInput = NoInput\nGo == /\\ pendingInput = "Real"'
    assert extract_input_alphabet(code)["literals"] == ["Real"]


def test_alphabet_renders_as_a_tla_set():
    assert input_alphabet_tla(["A", "B"]) == '{"A", "B"}'


def test_record_alphabet_reads_bounds_from_the_quantifier():
    """
    The real core_4.20.3.8 shape. The record's non-literal fields are bound by
    the enclosing \\E, so the domain is stated by the module and does not have
    to be invented.
    """
    code = '''
    SeqNums == 0..MaxSeqNum
    ReceivePacket ==
        /\\ \\E seq \\in SeqNums, hasAck \\in BOOLEAN :
               /\\ pendingInput = [type |-> "ReceivePacket", seq |-> seq, hasAck |-> hasAck]
    '''
    got = extract_record_alphabet(code)
    assert got["unresolved"] == []
    assert got["sets"] == ['[type: {"ReceivePacket"}, seq: SeqNums, hasAck: BOOLEAN]']


def test_record_alphabet_keeps_literal_only_records():
    code = 'SendPacket == /\\ pendingInput = [type |-> "SendPacket"]'
    assert extract_record_alphabet(code)["sets"] == ['[type: {"SendPacket"}]']


def test_fields_only_ever_read_are_unresolved():
    """
    The real core_4.12.5.1 shape: fields are read off pendingInput but no
    record is ever constructed, so nothing states what they range over. This
    must stay unrecoverable - inventing a domain for `msg` is exactly the
    mistake the alphabet rule exists to prevent.
    """
    code = '''
    Handle == /\\ pendingInput.type = "PrepareOutgoingMessage"
              /\\ LET msg == pendingInput.msg IN msg.rFlag
    '''
    got = extract_record_alphabet(code)
    assert got["sets"] == []
    assert any(u.startswith("msg ") for u in got["unresolved"])


def test_record_sets_union_into_one_alphabet():
    sets = ['[type: {"A"}]', '[type: {"B"}, n: Nums]']
    assert record_alphabet_tla(sets) == '[type: {"A"}] \\cup [type: {"B"}, n: Nums]'


# ---------------------------------------------------------------------------
# Declared alphabet (prompt rule 4a).
#
# These pin the blind spot that motivated the rule: scanning guards can only
# find events some action handles, so an event handled NOWHERE - the most
# valuable finding available - was invisible.
# ---------------------------------------------------------------------------
from src.validation.tlc_config import extract_declared_alphabet, unhandled_everywhere


def test_declared_alphabet_is_read_from_the_module():
    code = 'Inputs == {"Arm", "Complete", "FailSafeTimeout"}'
    assert extract_declared_alphabet(code) == ["Arm", "Complete", "FailSafeTimeout"]


def test_declared_alphabet_includes_events_no_action_handles():
    """The whole point of rule 4a. FailSafeTimeout has no guard anywhere."""
    code = '''
    Inputs == {"Arm", "Complete", "FailSafeTimeout"}
    Arm == /\\ pendingInput = "Arm"
    Complete == /\\ pendingInput = "Complete"
    '''
    declared = extract_declared_alphabet(code)
    handled = extract_input_alphabet(code)["literals"]
    assert "FailSafeTimeout" in declared
    assert "FailSafeTimeout" not in handled, "guard scan must NOT see it - that is the blind spot"
    assert unhandled_everywhere(declared, handled) == ["FailSafeTimeout"]


def test_no_declaration_returns_empty_so_caller_falls_back():
    """Modules generated before rule 4a declare Inputs as a CONSTANT."""
    code = 'CONSTANTS NoInput, Inputs\nArm == /\\ pendingInput = "Arm"'
    assert extract_declared_alphabet(code) == []


def test_declaration_in_a_comment_is_ignored():
    code = '\\* Inputs == {"Fake"}\nInputs == {"Real"}'
    assert extract_declared_alphabet(code) == ["Real"]


def test_everything_handled_reports_nothing_unhandled():
    assert unhandled_everywhere(["A", "B"], ["A", "B"]) == []


# --- the four misclassifications that cost ch45_v4 its verdicts -------------

def test_constant_compared_with_a_string_is_a_string():
    """core_4.19.4.11: "Role" read as boolean from its name, given TRUE, then
    compared with "GATTClient". TLC: "Attempted to compare equality of boolean
    TRUE with non-boolean"."""
    code = 'A == m = IF Role = "GATTClient" THEN "x" ELSE "y"'
    assert classify_constant("Role", code) == "string"


def test_string_constant_gets_a_literal_the_module_compares_against():
    """Giving it its own name would silently take the ELSE branch everywhere."""
    from src.validation.tlc_config import _compared_with_string, constant_value
    code = 'A == m = IF Role = "GATTClient" THEN "x" ELSE "y"'
    lit = _compared_with_string("Role", code)[0]
    assert lit == "GATTClient"
    assert constant_value("Role", "string", literal=lit) == '"GATTClient"'


def test_set_membership_against_strings_is_a_string():
    code = 'A == Mode \\in {"Fast", "Slow"}'
    assert classify_constant("Mode", code) == "string"


def test_underscore_prefixed_plural_is_not_a_set():
    """core_4.3.1.11: every Bit_* constant is one bit, not a collection."""
    code = "A == x = Bit_PressResetButtonUntilLightBlinks"
    assert classify_constant("Bit_PressResetButtonUntilLightBlinks", code) == "opaque"
    assert classify_constant("Bit_PressSetupButtonNTimes", code) == "opaque"


def test_sentinels_stay_model_values():
    """Measured, not assumed.

    Rendering sentinels as strings fixed core_4.6.7, where a model value met
    the string "Unsecured" - and broke three other units in the mirror-image
    way when the whole corpus was re-run: "check equality of string
    \"NoSession\" with non-string" (core_4.8.2), "compare integer 3 with
    non-integer" (core_4.12.1), "check equality of record" (core_4.14.2.3).
    Model values win 3 to 1, so they stay.
    """
    from src.validation.tlc_config import constant_value
    assert constant_value("NullState", "sentinel") == "NullState"
    assert constant_value("DummyId", "opaque") == "DummyId"
