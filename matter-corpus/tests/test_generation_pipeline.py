"""
Tests for the generation stages (context -> behaviour -> TLA+ -> cfg) and
their chaining into verification, with a scripted stand-in for OpenRouter so
no network or API key is needed.
"""
import json
import shutil
from pathlib import Path

import pytest

from src.generation.context import build_context, render_context
from src.generation.llm import LLMResponse
from src.generation.tla_generation import clean_module, module_name_for
from src.run_pipeline import run_section

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "llm_style" / "FailSafeContext.tla"

SECTIONS = {
    "core_11.10.7": {"id": "core_11.10.7", "title": "Commands", "parent_id": None,
                     "page_start": 880, "page_end": 890, "references": [],
                     "full_text": "11.10.7. Commands"},
    "core_11.10.7.2": {"id": "core_11.10.7.2", "title": "Fail Safe Context",
                       "parent_id": "core_11.10.7", "page_start": 883, "page_end": 886,
                       "references": ["core_11.10.6.1", "core_9.9.9"],
                       "full_text": "11.10.7.2. ArmFailSafe ... SHALL arm the fail-safe timer"},
    "core_11.10.6.1": {"id": "core_11.10.6.1", "title": "Breadcrumb",
                       "parent_id": "core_11.10.6", "page_start": 880, "page_end": 880,
                       "references": [], "full_text": "11.10.6.1. Breadcrumb ..."},
    "core_4.11.1.1": {"id": "core_4.11.1.1", "title": "Second hop", "parent_id": None,
                      "page_start": 1, "page_end": 1, "references": [], "full_text": "..."},
}


class ScriptedLLM:
    """Returns canned replies in order and records the prompts it was given."""

    def __init__(self, replies):
        self.replies = list(replies)
        self.prompts = []

    def complete(self, prompt, *, max_tokens):
        self.prompts.append(prompt)
        return LLMResponse(self.replies.pop(0), "fake/model", "fake/model-routed", "stop")


BEHAVIOUR = {
    "state_variables": [], "states": [], "events": [], "guards": [],
    "transitions": [{"event": "ArmFailSafe", "source_sections": ["11.10.7.2"]}],
    "timers_counters": [], "error_behaviour": [],
    "unclear_behaviour": [{"description": "expiry while disarmed",
                           "source_sections": ["11.10.7.2", "99.99"]}],
}


def test_context_matches_notebook_rule():
    b = build_context(SECTIONS, "core_11.10.7.2", second_hop=["4.11.1.1"])
    # parent, target, resolvable one-hop refs (9.9.9 is not in corpus), chosen 2nd hop
    assert b["context_section_ids"] == ["11.10.7", "11.10.7.2", "11.10.6.1", "4.11.1.1"]
    assert "SECTION 11.10.7.2: Fail Safe Context" in render_context(b)


def test_module_name_and_cleanup():
    assert module_name_for("ArmFailSafe Command") == "ArmFailSafeCommand"
    out = clean_module("```tla\nHere you go:\n---- MODULE Wrong ----\nVARIABLE x\n====\nThanks!\n```",
                       "Right")
    assert out["text"].startswith("---- MODULE Right ----")
    assert out["text"].rstrip().endswith("====")
    assert len(out["notes"]) == 3      # prose before, rename, prose after


@pytest.mark.skipif(shutil.which("java") is None, reason="needs java for SANY/TLC")
def test_pipeline_chains_generation_into_verification(tmp_path):
    module = module_name_for("Fail Safe Context")
    tla = FIXTURE.read_text().replace("MODULE FailSafeContext", "MODULE Placeholder")
    cfg = FIXTURE.with_suffix(".cfg").read_text()
    llm = ScriptedLLM([json.dumps(BEHAVIOUR), "```\n" + tla + "\n```", cfg])

    summary = run_section("core_11.10.7.2", SECTIONS, llm, out_root=tmp_path,
                          verify_kwargs={"max_states": 1000})
    out = tmp_path / "core_11.10.7.2"

    # The prompts are the notebook's, parameterised with this section.
    assert "Section 11.10.7.2, Fail Safe Context." in llm.prompts[0]
    assert f"---- MODULE {module} ----" in llm.prompts[1]
    assert "SPECIFICATION Spec" in llm.prompts[2]

    beh = json.loads((out / "behaviour.json").read_text())
    assert beh["validation"]["invalid_source_sections"] == ["99.99"]
    assert beh["behavioral_model"]["unclear_behaviour"][0]["confirmed_underspecification"] is False

    assert (out / f"{module}.tla").read_text().startswith(f"---- MODULE {module} ----")
    prov = json.loads((out / "provenance.json").read_text())
    assert prov["stages"]["tla"]["actual_model"] == "fake/model-routed"

    # 1000 states is below the fixture's full state space, so the run must
    # have gone through automatic decomposition.
    assert summary["outcome"] == "checked_decomposed" and summary["decomposed"]
    assert (out / "verification" / module / "report.md").exists()

    # Cached stages are reused: a second run makes no LLM calls.
    llm2 = ScriptedLLM([])
    again = run_section("core_11.10.7.2", SECTIONS, llm2, out_root=tmp_path,
                        verify_kwargs={"max_states": 1000})
    assert llm2.prompts == [] and again["outcome"] == "checked_decomposed"
