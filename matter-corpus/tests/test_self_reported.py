"""
Tests for harvesting the generator's own "TODO: unspecified" notes.

Prompt rule 2 asks the model to flag, rather than invent, behaviour the spec
text does not define. Those notes existed in 7 of 12 generated modules and were
read by nothing until now. These tests pin what the harvester must do with
them - in particular that it reaches modules TLC cannot give a verdict on,
which is the whole reason the signal is worth having.
"""
import json
import textwrap

import make_gap_report as mgr


def write(tmp_path, name, body):
    p = tmp_path / f"{name}.tla"
    p.write_text(textwrap.dedent(body).lstrip(), encoding="utf-8")
    return p


def test_note_is_attributed_to_the_definition_below_it():
    """A note sits ABOVE the action it concerns; "unspecified" alone is useless."""
    body = """
        Init == /\\ state = "Idle"

        \\* TODO: unspecified - what happens when CM=0 and discovery is off
        GenerateTXTRecord ==
            /\\ state = "Idle"
    """
    import pathlib, tempfile
    d = pathlib.Path(tempfile.mkdtemp())
    p = write(d, "M", body)
    notes = mgr.extract_self_reported(p)
    assert len(notes) == 1
    assert notes[0]["near"] == "GenerateTXTRecord"
    assert "CM=0" in notes[0]["text"]


def test_note_inside_a_definition_belongs_to_that_definition():
    body = """
        HandleAck ==
            /\\ pendingInput = "Ack"
            \\* TODO: unspecified - no rule for an ack with nothing outstanding
            /\\ state' = "Idle"
    """
    import pathlib, tempfile
    d = pathlib.Path(tempfile.mkdtemp())
    p = write(d, "M", body)
    assert mgr.extract_self_reported(p)[0]["near"] == "HandleAck"


def test_ordinary_comments_are_not_harvested():
    body = """
        \\* SOURCE: core_4.1.1 Something
        \\* TODO: tidy this up later
        Init == /\\ state = "Idle"
    """
    import pathlib, tempfile
    d = pathlib.Path(tempfile.mkdtemp())
    p = write(d, "M", body)
    assert mgr.extract_self_reported(p) == []


def test_missing_file_yields_no_notes_rather_than_raising():
    assert mgr.extract_self_reported("/nonexistent/path/M.tla") == []


def test_units_with_no_tlc_verdict_are_still_collected(tmp_path):
    """
    The point of the whole signal. A module that failed SANY never reaches the
    TLC log, so collecting from the TLC log would silently drop exactly the
    units that have no other evidence at all.
    """
    mod = write(tmp_path, "Broken", """
        \\* TODO: unspecified - the spec never says what follows the timeout
        Init == /\\ state = "Idle"
    """)
    (tmp_path / "results.jsonl").write_text(json.dumps({
        "unit_id": "core_9.9.9",
        "title": "Broken Section",
        "final_score": 12.0,
        "tla_path": str(mod),
        "sany": {"passed": False},
    }) + "\n", encoding="utf-8")

    # rows = the TLC log, which does NOT contain this unit
    found = mgr.collect_self_reported(tmp_path, rows=[])
    assert len(found) == 1
    assert found[0]["unit_id"] == "core_9.9.9"
    assert found[0]["outcome"] == "did not compile"
    assert "never says what follows" in found[0]["notes"][0]["text"]


def test_real_corpus_notes_are_found():
    """Guards the regex against the notes actually present in ch45_v2."""
    import pathlib
    log = pathlib.Path("models/generated/ch45_v2/results.jsonl")
    if not log.exists():
        return
    found = mgr.collect_self_reported(log.parent, rows=[])
    total = sum(len(f["notes"]) for f in found)
    assert total >= 9, f"expected the 9 known notes, found {total}"
