"""
Tests for finding where else the spec may already handle an event.

Built from the one scope artifact found by hand: core_4.12.2.1 reported an
acknowledgement arriving with nothing outstanding, and core_4.12.5.2 says what
that means. Two things that case taught, both pinned here:

  * Cross-references alone do NOT connect them. core_4.12.2.1 references only
    core_4.3.2; the sections are never linked in the text. What relates them is
    position, so siblings must be searched too.
  * Ranking by section order buried the answer. The sentence that says what an
    unmatched event means has to outrank sections that merely discuss it.
"""
import json
from pathlib import Path

import pytest

import make_gap_report as mgr

CORPUS = Path("data/processed/core")
pytestmark = pytest.mark.skipif(not (CORPUS / "sections.json").exists(),
                                reason="needs the built corpus")


@pytest.fixture(scope="module")
def corpus():
    secs = {s["id"]: s for s in json.loads((CORPUS / "sections.json").read_text())}
    graph = json.loads((CORPUS / "dependency_graph.json").read_text())
    return secs, graph


def test_event_name_becomes_searchable_terms():
    assert mgr.event_terms('"ReceiveAck"') == ["ack"]
    assert mgr.event_terms('"CommissioningComplete"') == ["commissioning", "complete"]


def test_generic_verbs_are_dropped():
    """"Receive"/"Send" match everything and would drown the real term."""
    assert "receive" not in mgr.event_terms('"ReceiveBTPPacket"')
    assert "send" not in mgr.event_terms('"SendPacket"')


def test_siblings_are_searched_not_just_cross_references(corpus):
    secs, graph = corpus
    assert "core_4.12.5.2" not in graph["core_4.12.2.1"]["references"], \
        "if this ever becomes a cross-reference the sibling search is still needed"
    assert "core_4.12.5.2" in mgr._sibling_ids("core_4.12.2.1", secs)


def test_the_known_scope_artifact_is_found_and_ranked_first(corpus):
    """The regression this whole function exists for."""
    secs, graph = corpus
    hits = mgr.neighbour_handling("core_4.12.2.1", '"ReceiveAck"', secs, graph)
    assert hits, "found nothing"
    assert hits[0]["ref"] == "core_4.12.5.2", [h["ref"] for h in hits]
    assert "no match" in hits[0]["quote"].lower()


def test_sections_merely_mentioning_the_event_rank_below(corpus):
    secs, graph = corpus
    hits = mgr.neighbour_handling("core_4.12.2.1", '"ReceiveAck"', secs, graph)
    assert hits[0]["score"] > hits[-1]["score"]


def test_unrecognisable_event_yields_nothing_rather_than_noise(corpus):
    secs, graph = corpus
    assert mgr.neighbour_handling("core_4.12.2.1", '"Send"', secs, graph) == []


def test_unknown_unit_is_handled(corpus):
    secs, graph = corpus
    assert mgr.neighbour_handling("core_99.9.9", '"ReceiveAck"', secs, graph) == []
