"""
End-to-end tests for the unhandled-input gap detector.

These run TLC for real, because the thing being tested is a claim about what
TLC does, and the previous detector (plain deadlock checking) failed in exactly
the way a mocked test would have missed: it worked, it just measured the wrong
thing. The two cases below are the whole contract.
"""
import shutil
import textwrap

import pytest

from src.validation.run_tlc import check_module

pytestmark = pytest.mark.skipif(shutil.which("java") is None,
                                reason="TLC needs a JRE on PATH")

TLA_TOOLS = "tla2tools.jar"


def write(tmp_path, name, body):
    path = tmp_path / f"{name}.tla"
    path.write_text(textwrap.dedent(body).lstrip(), encoding="utf-8")
    return path


# A protocol that ENDS cleanly: the input is delivered, handled, and then
# nothing more happens. Plain deadlock checking flagged exactly this shape as a
# candidate gap 14 times over, and every one was a false alarm.
TERMINATES_CLEANLY = """
    ---- MODULE Terminates ----
    CONSTANTS NoInput, Inputs
    VARIABLES state, pendingInput

    Init == /\\ state = "Idle"
            /\\ pendingInput = NoInput

    ReceiveInput(e) == /\\ pendingInput = NoInput
                       /\\ e \\in Inputs
                       /\\ pendingInput' = e
                       /\\ UNCHANGED state

    \\* Handles EVERY input, in every state it can arrive in.
    Handle == /\\ pendingInput = "Go"
              /\\ state' = "Done"
              /\\ pendingInput' = NoInput

    Next == \\/ \\E e \\in Inputs : ReceiveInput(e)
            \\/ Handle
    ====
"""

# The same protocol, except Handle only works from "Idle". Once the model is in
# "Done" and another input arrives, nothing consumes it - the spec said nothing
# about that case. THAT is a gap.
LEAVES_INPUT_UNHANDLED = """
    ---- MODULE Unhandled ----
    CONSTANTS NoInput, Inputs
    VARIABLES state, pendingInput

    Init == /\\ state = "Idle"
            /\\ pendingInput = NoInput

    ReceiveInput(e) == /\\ pendingInput = NoInput
                       /\\ e \\in Inputs
                       /\\ pendingInput' = e
                       /\\ UNCHANGED state

    Handle == /\\ pendingInput = "Go"
              /\\ state = "Idle"
              /\\ state' = "Done"
              /\\ pendingInput' = NoInput

    Next == \\/ \\E e \\in Inputs : ReceiveInput(e)
            \\/ Handle
    ====
"""


def test_clean_termination_is_not_reported_as_a_gap(tmp_path):
    """The regression that motivated replacing deadlock detection entirely.

    This model reaches a state where nothing at all is enabled - a deadlock -
    but no input is waiting, so the spec is not silent about anything. It must
    come back clean.
    """
    path = write(tmp_path, "Terminates", TERMINATES_CLEANLY)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["has_input_shape"]
    assert result["outcome"] == "no_error", result
    assert not result["gap_candidate"]


def test_input_with_no_handler_is_reported_as_a_gap(tmp_path):
    path = write(tmp_path, "Unhandled", LEAVES_INPUT_UNHANDLED)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["outcome"] == "unhandled_input", result
    assert result["gap_candidate"]
    trace = result["runs"][0].get("trace", "")
    assert "state = \"Done\"" in trace, trace


def test_module_without_the_input_shape_is_not_silently_passed(tmp_path):
    """A module skipping rule 4a must not come back as 'nothing found'."""
    path = write(tmp_path, "NoShape", """
        ---- MODULE NoShape ----
        VARIABLES state
        Init == state = "Idle"
        Next == state' = "Done"
        ====
    """)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["outcome"] == "no_shape"
    assert not result.get("gap_candidate")


# A module whose guards name no input at all. Its alphabet cannot be recovered,
# so it must come back as not-checkable rather than as a clean run: with the
# placeholder alphabet this shape produced a fabricated gap at depth 2.
NAMES_NO_INPUT = """
    ---- MODULE Nameless ----
    CONSTANTS NoInput, Inputs
    VARIABLES state, pendingInput

    Init == /\\ state = "Idle"
            /\\ pendingInput = NoInput

    ReceiveInput(e) == /\\ pendingInput = NoInput
                       /\\ e \\in Inputs
                       /\\ pendingInput' = e
                       /\\ UNCHANGED state

    Handle == /\\ pendingInput # NoInput
              /\\ state' = "Done"
              /\\ pendingInput' = NoInput

    Next == \\/ \\E e \\in Inputs : ReceiveInput(e)
            \\/ Handle
    ====
"""


def test_unrecoverable_alphabet_is_not_checkable_not_clean(tmp_path):
    """
    The harness artifact this rule exists for: Inputs used to be filled with
    model values (Inputs_1, Inputs_2) that no guard could match, so every
    module reported a gap on its first input. A module whose alphabet cannot
    be recovered must yield no verdict at all - never a gap, and never a pass.
    """
    path = write(tmp_path, "Nameless", NAMES_NO_INPUT)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["outcome"] == "input_alphabet_unknown", result
    assert not result.get("gap_candidate")


def test_recovered_alphabet_reaches_the_model(tmp_path):
    """The inputs TLC explores are the ones the module names, not placeholders."""
    path = write(tmp_path, "Unhandled", LEAVES_INPUT_UNHANDLED)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["input_alphabet"] == ["Go"]
    assert "Inputs_1" not in result["runs"][0].get("trace", "")


# The ground-truth case, pinned as a test instead of only asserted in a docstring.
#
# ArmFailSafe.tla is hand-written and has a KNOWN gap: CommissioningComplete
# arrives while Disarmed and the spec defines no handling. Two things this test
# records, both of which were previously claimed without being checked:
#
#  1. The detector CANNOT read ArmFailSafe.tla as written - it names its
#     variables pendingMsg/NullValue/Messages, not the mandated shape - so the
#     "verified against ground truth" claim only holds for a renamed copy.
#  2. The real gap is found at depth 2 with NO model action firing first. The
#     "reached after real progress" heuristic would score this ground-truth
#     finding as zero, so that heuristic ranks confidence; it does not decide
#     validity.
ARM_FAIL_SAFE_SHAPED = """
    ---- MODULE ArmFailSafeShaped ----
    EXTENDS Naturals
    CONSTANTS MaxExpiry, NoInput, Inputs
    VARIABLES state, failSafeExpiry, pendingInput

    Init == /\\ state = "Disarmed"
            /\\ failSafeExpiry = 0
            /\\ pendingInput = NoInput

    ArmFailSafeAction(e) ==
        /\\ pendingInput = "ArmFailSafe"
        /\\ e \\in 1..MaxExpiry
        /\\ state \\in {"Disarmed", "Armed"}
        /\\ state' = "Armed"
        /\\ failSafeExpiry' = e
        /\\ pendingInput' = NoInput

    CommissioningCompleteAction ==
        /\\ pendingInput = "CommissioningComplete"
        /\\ state = "Armed"
        /\\ state' = "Disarmed"
        /\\ failSafeExpiry' = 0
        /\\ pendingInput' = NoInput

    ReceiveMessage(m) ==
        /\\ pendingInput = NoInput
        /\\ pendingInput' = m
        /\\ UNCHANGED <<state, failSafeExpiry>>

    Next == \\/ \\E e \\in 1..MaxExpiry : ArmFailSafeAction(e)
            \\/ CommissioningCompleteAction
            \\/ \\E m \\in Inputs : ReceiveMessage(m)
    ====
"""


def test_ground_truth_gap_is_found_and_named(tmp_path):
    path = write(tmp_path, "ArmFailSafeShaped", ARM_FAIL_SAFE_SHAPED)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["outcome"] == "unhandled_input", result
    run = result["runs"][0]
    assert "CommissioningComplete" in run.get("unhandled_value", "")
    assert 'state = "Disarmed"' in run.get("trace", "")


def test_ground_truth_gap_fires_with_no_model_action_first(tmp_path):
    """
    Guards the correction above: the known-real gap has the same trace shape as
    the findings that were dismissed as initial-state artifacts. If this ever
    starts asserting otherwise, the dismissal rule has been applied too widely.
    """
    import make_gap_report as mgr
    path = write(tmp_path, "ArmFailSafeShaped", ARM_FAIL_SAFE_SHAPED)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert not mgr.made_progress(result)


# A module that declares an event it never handles anywhere. Before rule 4a the
# alphabet came from guards, so this event had no guard, was never delivered,
# and could not be reported - the strongest available finding was unreachable.
DECLARES_UNHANDLED_EVENT = """
    ---- MODULE Declared ----
    CONSTANTS NoInput
    VARIABLES state, pendingInput

    Inputs == {"Go", "NeverHandled"}

    Init == /\\ state = "Idle"
            /\\ pendingInput = NoInput

    ReceiveInput(e) == /\\ pendingInput = NoInput
                       /\\ e \\in Inputs
                       /\\ pendingInput' = e
                       /\\ UNCHANGED state

    Handle == /\\ pendingInput = "Go"
              /\\ state' = "Done"
              /\\ pendingInput' = NoInput

    Next == \\/ \\E e \\in Inputs : ReceiveInput(e)
            \\/ Handle
    ====
"""


def test_declared_alphabet_is_used_in_preference_to_guards(tmp_path):
    path = write(tmp_path, "Declared", DECLARES_UNHANDLED_EVENT)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["alphabet_source"] == "declared"
    assert result["input_alphabet"] == ["Go", "NeverHandled"]
    assert result["unhandled_everywhere"] == ["NeverHandled"]


def test_event_handled_nowhere_is_actually_reported(tmp_path):
    """Regression for the blind spot: the event must reach TLC and be found."""
    path = write(tmp_path, "Declared", DECLARES_UNHANDLED_EVENT)
    result = check_module(path, TLA_TOOLS, timeout=60)
    assert result["outcome"] == "unhandled_input"
    assert "NeverHandled" in result["runs"][0].get("trace", "")


# Rule 4b ranking. The same model twice, differing ONLY in whether its initial
# state counts as operational - so the test isolates the ranking signal from
# everything else.
_OP_MODULE = """
    ---- MODULE Op%s ----
    CONSTANTS NoInput
    VARIABLES state, pendingInput

    Inputs == {"Arm", "Complete"}
    Operational == %s

    Init == /\\ state = "Disarmed"
            /\\ pendingInput = NoInput

    ReceiveInput(e) == /\\ pendingInput = NoInput
                       /\\ e \\in Inputs
                       /\\ pendingInput' = e
                       /\\ UNCHANGED state

    Arm == /\\ pendingInput = "Arm"
           /\\ state' = "Armed"
           /\\ pendingInput' = NoInput

    Complete == /\\ pendingInput = "Complete"
                /\\ state = "Armed"
                /\\ state' = "Disarmed"
                /\\ pendingInput' = NoInput

    Next == \\/ \\E e \\in Inputs : ReceiveInput(e)
            \\/ Arm \\/ Complete
    ====
"""


def test_event_in_an_operational_state_ranks_strong(tmp_path):
    """Disarmed is a real resting state, so a gap there is a strong finding."""
    path = write(tmp_path, "OpStrong",
                 _OP_MODULE % ("Strong", 'state \\in {"Disarmed", "Armed"}'))
    r = check_module(path, TLA_TOOLS, timeout=60)
    assert r["outcome"] == "unhandled_input"
    assert r["gap_strength"] == "operational"


def test_event_in_scaffolding_ranks_weak(tmp_path):
    """Same model; only the Operational predicate changed."""
    path = write(tmp_path, "OpWeak",
                 _OP_MODULE % ("Weak", 'state # "Disarmed"'))
    r = check_module(path, TLA_TOOLS, timeout=60)
    assert r["outcome"] == "unhandled_input"
    assert r["gap_strength"] == "setup_only"


def test_weak_findings_are_still_reported(tmp_path):
    """
    Ranking, never filtering. The ground-truth ArmFailSafe gap arrives in that
    module's INITIAL state, so a rule that dropped initial-state findings would
    discard the one gap known to be real.
    """
    path = write(tmp_path, "OpWeak2",
                 _OP_MODULE % ("Weak2", 'state # "Disarmed"'))
    r = check_module(path, TLA_TOOLS, timeout=60)
    assert r["gap_candidate"] is True


def test_module_without_rule_4b_is_unranked_not_demoted(tmp_path):
    """Modules predating rule 4b must not be silently sorted to the bottom."""
    path = write(tmp_path, "Declared", DECLARES_UNHANDLED_EVENT)
    r = check_module(path, TLA_TOOLS, timeout=60)
    assert r["declares_operational"] is False
    assert r["gap_strength"] == "unranked"


def test_ground_truth_gap_ranks_operational(tmp_path):
    """
    ArmFailSafe's known gap: CommissioningComplete while Disarmed. Disarmed is
    where the device actually sits, so rule 4b must rank this STRONG even
    though it is reached at depth 2 with no model action - the shape that
    looked like noise before this ranking existed.
    """
    body = ARM_FAIL_SAFE_SHAPED.replace(
        "    Init == ", '    Operational == state \\in {"Disarmed", "Armed"}\n\n    Init == ')
    path = write(tmp_path, "ArmFailSafeShaped", body)
    r = check_module(path, TLA_TOOLS, timeout=60)
    assert r["outcome"] == "unhandled_input", r
    assert r["gap_strength"] == "operational"
    assert "CommissioningComplete" in r["runs"][0].get("unhandled_value", "")
