"""
Tests for SANY/TLC integration and automatic decomposition (src/tla,
src/decomposition, src/verify).

The central check is *losslessness*: for models small enough to also check
whole, the decomposed run must report exactly the full model's findings
(every one confirmed by replay on the full model, none missed, none
invented). PAFTPSessionNaive.tla is the regression target -- it is the model
the 2026-09-18 session decomposed by hand (SESSION_LOG §6), so the automatic
split has to find the same concerns and reproduce Findings B and C.

These tests run the real TLA+ tools and need `java` on PATH.
"""
import shutil
import textwrap
from pathlib import Path

import pytest

from src.decomposition.abstraction import AbstractionError, build_submodule
from src.decomposition.planner import DecompositionUnsupported, make_plan, spec_parts
from src.tla.cfg import parse_cfg, parse_cfg_file
from src.tla.sany_ast import load_model
from src.tla.tools import run_sany, run_tlc
from src.verify import verify_model

ROOT = Path(__file__).resolve().parents[1]
PAFTP = ROOT / "tla_models" / "core_4.20.3_session" / "PAFTPSessionNaive.tla"
LLM_STYLE = ROOT / "tests" / "fixtures" / "llm_style" / "FailSafeContext.tla"
ARMFAILSAFE = ROOT / "ArmFailSafe.tla"

pytestmark = pytest.mark.skipif(shutil.which("java") is None, reason="needs java for SANY/TLC")


# ----------------------------------------------------------------- cfg

def test_cfg_roundtrip_keeps_constants_verbatim():
    cfg = parse_cfg(textwrap.dedent("""\
        SPECIFICATION Spec
        \\* a comment
        CONSTANTS
            MaxQueue = 2
            Node = {n1, n2}
        INVARIANT TypeOK
        INVARIANTS A B
        CHECK_DEADLOCK FALSE
        ====
    """))
    assert cfg.specification == "Spec"
    assert cfg.invariants == ["TypeOK", "A", "B"]
    assert cfg.check_deadlock is False
    assert "Node = {n1, n2}" in cfg.constants_text
    again = parse_cfg(cfg.render())
    assert again.invariants == cfg.invariants and again.constants_text.strip() == cfg.constants_text.strip()


# ------------------------------------------------------------- planner

def test_planner_finds_the_hand_split_on_paftp():
    m = load_model(PAFTP)
    plan = make_plan(m, parse_cfg_file(PAFTP.with_suffix(".cfg")))
    assert plan.hubs == ["pendingEvent", "phase"]
    groups = [set(g.variables) for g in plan.groups]
    # The three concerns of the hand decomposition (Handshake / AckWindow / SDU) ...
    assert {"handshakeTimerRunning"} in groups
    assert {"outstanding", "ackTimerRunning", "pendingAck", "sendAckTimerRunning", "freeSlots"} in groups
    # ... with SDU further split: sending queue and receive reassembly never interact.
    assert {"queueLen", "sduInProgress"} in groups
    assert {"reassemblyInProgress"} in groups


def test_planner_refuses_tightly_coupled_model():
    m = load_model(ARMFAILSAFE)
    with pytest.raises(DecompositionUnsupported):
        make_plan(m, parse_cfg_file(ARMFAILSAFE.with_suffix(".cfg")))


# --------------------------------------------------------- abstraction

def test_generated_pieces_parse_and_drop_hidden_variables(tmp_path):
    m = load_model(PAFTP)
    cfg = parse_cfg_file(PAFTP.with_suffix(".cfg"))
    parts = spec_parts(m, cfg)
    hidden = ["outstanding", "ackTimerRunning", "pendingAck", "sendAckTimerRunning",
              "freeSlots", "queueLen", "sduInProgress", "reassemblyInProgress"]
    sub = build_submodule(m, cfg, parts, hidden, "PAFTP__handshake")
    p = tmp_path / "PAFTP__handshake.tla"
    p.write_text(sub.text)
    assert run_sany(p).ok
    code = "\n".join(l.split("\\*")[0] for l in sub.text.splitlines())
    for h in hidden:
        assert h not in code, f"hidden variable {h} survived in the piece"


def test_abstraction_refuses_hidden_data_flow(tmp_path):
    # y' = x makes x's value flow into y: hiding x while keeping y is not
    # expressible as an over-approximation without x's domain -> must refuse.
    (tmp_path / "Flow.tla").write_text(textwrap.dedent("""\
        ---- MODULE Flow ----
        EXTENDS Naturals
        VARIABLES x, y
        Init == x = 0 /\\ y = 0
        Next == \\/ x < 2 /\\ x' = x + 1 /\\ UNCHANGED y
                \\/ y' = x /\\ UNCHANGED x
        Spec == Init /\\ [][Next]_<<x, y>>
        ====
    """))
    (tmp_path / "Flow.cfg").write_text("SPECIFICATION Spec\n")
    m = load_model(tmp_path / "Flow.tla")
    cfg = parse_cfg_file(tmp_path / "Flow.cfg")
    with pytest.raises(AbstractionError, match="flow into visible state"):
        build_submodule(m, cfg, spec_parts(m, cfg), ["x"], "Flow__y")


# ------------------------------------------------------------- TLC runner

def test_state_budget_stops_tlc():
    r = run_tlc(PAFTP, PAFTP.with_suffix(".cfg"), max_states=300)
    assert r.status == "budget_exceeded"
    assert r.distinct_states is not None and r.distinct_states <= 310


# ------------------------------------------------------------ end to end

def _keys(findings, status=None):
    return {(f["invariant"], f["action"], tuple(sorted(f["pre_state"].items())))
            for f in findings if status is None or f["status"] == status}


@pytest.mark.parametrize("model", [PAFTP, LLM_STYLE], ids=["paftp-house-style", "llm-style"])
def test_decomposition_is_lossless(model, tmp_path):
    rep = verify_model(model, out_dir=tmp_path, compare=True)
    cmp_ = rep["comparison"]
    assert cmp_["available"]
    assert cmp_["missed_by_decomposition"] == []
    assert cmp_["confirmed_but_not_in_full"] == []
    assert cmp_["decomposed_confirmed"] == cmp_["full_findings"] > 0
    assert cmp_["largest_piece_states"] < cmp_["full_states"]


def test_paftp_reproduces_findings_B_and_C(tmp_path):
    rep = verify_model(PAFTP, out_dir=tmp_path, decompose="always")
    confirmed = _keys(rep["findings"], "confirmed")
    pre = lambda phase, ev: (("pendingEvent", f'"{ev}"'), ("phase", f'"{phase}"'))
    # Finding B: data-phase events arriving during the handshake.
    for ev in ["SendPacket", "ReceiveAck", "ReceivePacket", "SendSDU", "ReceiveBeginSegment"]:
        assert ("NeverUndefined", "UndefinedTransition", pre("Handshake", ev)) in confirmed
    # Finding C: stale handshake notifications after establishment.
    for ev in ["ReceiveHandshakeResponse", "HandshakeTimeout"]:
        assert ("NeverUndefined", "UndefinedTransition", pre("Established", ev)) in confirmed


def test_decomposition_triggers_only_when_budget_exceeded(tmp_path):
    small = verify_model(PAFTP, out_dir=tmp_path / "a")
    assert small["outcome"] == "checked_full" and small["decomposition"] is None
    tight = verify_model(PAFTP, out_dir=tmp_path / "b", max_states=1000)
    assert tight["full_check"]["status"] == "budget_exceeded"
    assert tight["outcome"] == "checked_decomposed"
    assert _keys(tight["findings"], "confirmed") == _keys(small["findings"])
    assert (tmp_path / "b" / "report.md").exists()


def test_sany_error_stops_before_tlc(tmp_path):
    bad = tmp_path / "Bad.tla"
    bad.write_text("---- MODULE Bad ----\nVARIABLES x\nInit == x = \n====\n")
    (tmp_path / "Bad.cfg").write_text("INIT Init\nNEXT Init\n")
    rep = verify_model(bad, out_dir=tmp_path / "out")
    assert rep["outcome"] == "sany_error" and rep["full_check"] is None
