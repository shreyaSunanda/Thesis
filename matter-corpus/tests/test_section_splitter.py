# import pytest
# from src.parsing.section_splitter import SectionSplitter

# def test_basic_section_splitting():
#     """
#     Tests that a flat sequence of lines mimicking Matter spec style
#     is correctly split into discrete sections with correct content and page numbers.
#     """
#     splitter = SectionSplitter(doc_name="core")
    
#     sample_lines = [
#         {"text": "1. Introduction", "page_num": 1, "font_size": 12.0, "is_bold": True},
#         {"text": "This is the first paragraph of the introduction.", "page_num": 1, "font_size": 10.0, "is_bold": False},
#         {"text": "1.1 Scope", "page_num": 2, "font_size": 11.0, "is_bold": True},
#         {"text": "This covers the scope of the matter protocol.", "page_num": 2, "font_size": 10.0, "is_bold": False},
#         {"text": "1.1.1 Exclusions", "page_num": 2, "font_size": 10.5, "is_bold": True},
#         {"text": "Some features are excluded from this release.", "page_num": 3, "font_size": 10.0, "is_bold": False},
#     ]
    
#     sections = splitter.split_sections(sample_lines)
    
#     assert len(sections) == 3
    
#     # Verify Section 1
#     sec1 = sections[0]
#     assert sec1["id"] == "core_1"
#     assert sec1["title"] == "Introduction"
#     assert sec1["page_start"] == 1
#     assert sec1["page_end"] == 1
#     assert sec1["parent_id"] is None
#     assert "This is the first paragraph" in sec1["full_text"]
    
#     # Verify Section 1.1
#     sec1_1 = sections[1]
#     assert sec1_1["id"] == "core_1.1"
#     assert sec1_1["title"] == "Scope"
#     assert sec1_1["page_start"] == 2
#     assert sec1_1["page_end"] == 2
#     assert sec1_1["parent_id"] == "core_1"
#     assert "This covers the scope" in sec1_1["full_text"]
    
#     # Verify Section 1.1.1
#     sec1_1_1 = sections[2]
#     assert sec1_1_1["id"] == "core_1.1.1"
#     assert sec1_1_1["title"] == "Exclusions"
#     assert sec1_1_1["page_start"] == 2
#     assert sec1_1_1["page_end"] == 3
#     assert sec1_1_1["parent_id"] == "core_1.1"
#     assert "Some features are excluded" in sec1_1_1["full_text"]


# def test_hierarchy_and_parent_id():
#     """
#     Tests that parent-child relationships are correctly established
#     even if there are gaps in numbering or deep nesting.
#     """
#     splitter = SectionSplitter(doc_name="app_cluster")
    
#     sample_lines = [
#         {"text": "4 Cluster Definition", "page_num": 1, "font_size": 12.0, "is_bold": True},
#         {"text": "4.1 On/Off Cluster", "page_num": 1, "font_size": 11.0, "is_bold": True},
#         {"text": "4.1.1 Attributes", "page_num": 2, "font_size": 10.5, "is_bold": True},
#         {"text": "4.1.2 Commands", "page_num": 3, "font_size": 10.5, "is_bold": True},
#         {"text": "5 Another Section", "page_num": 4, "font_size": 12.0, "is_bold": True},
#     ]
    
#     sections = splitter.split_sections(sample_lines)
#     assert len(sections) == 5
    
#     # Map to access by ID easily
#     sec_map = {s["id"]: s for s in sections}
    
#     assert sec_map["app_cluster_4"]["parent_id"] is None
#     assert sec_map["app_cluster_4.1"]["parent_id"] == "app_cluster_4"
#     assert sec_map["app_cluster_4.1.1"]["parent_id"] == "app_cluster_4.1"
#     assert sec_map["app_cluster_4.1.2"]["parent_id"] == "app_cluster_4.1"
#     assert sec_map["app_cluster_5"]["parent_id"] is None


# def test_header_filtering_and_heuristics():
#     """
#     Tests that normal text sentences starting with numbers (like step lists) or
#     non-headers are NOT incorrectly parsed as section headers.
#     """
#     splitter = SectionSplitter(doc_name="core", min_header_font_size=11.0)
    
#     sample_lines = [
#         {"text": "4. Commissioning Flow", "page_num": 1, "font_size": 12.0, "is_bold": True},
#         # A list item that looks like a header pattern but has normal body font size and is not bold
#         {"text": "1. Turn on the device power switch.", "page_num": 1, "font_size": 10.0, "is_bold": False},
#         # Another list item that shouldn't be matched
#         {"text": "2. Wait for the blue LED to blink.", "page_num": 1, "font_size": 10.0, "is_bold": False},
#         # Header/Footer noise to skip
#         {"text": "Matter Core Specification 1.3", "page_num": 1, "font_size": 8.0, "is_bold": False},
#         {"text": "123", "page_num": 1, "font_size": 8.0, "is_bold": False},
#     ]
    
#     sections = splitter.split_sections(sample_lines)
    
#     # We should only have 1 section (Section 4)
#     assert len(sections) == 1
#     assert sections[0]["id"] == "core_4"
#     assert sections[0]["title"] == "Commissioning Flow"
    
#     # The body text should contain the list items, but NOT the skip lines (like page headers/footers)
#     full_text = sections[0]["full_text"]
#     assert "Turn on the device power switch." in full_text
#     assert "Wait for the blue LED to blink." in full_text
#     assert "Matter Core Specification" not in full_text
#     assert "123" not in full_text

import pytest
from src.parsing.section_splitter import SectionSplitter


# ---------------------------------------------------------------------------
# Regression tests for the two bugs caught by an independent full-corpus
# (Matter 1.6 Core Specification, 1335 pages) parser run, ported back here
# so they can't silently reappear as the parser evolves.
# ---------------------------------------------------------------------------
import pytest
from src.parsing.section_splitter import SectionSplitter


# ---------------------------------------------------------------------------
# Regression tests for the two bugs caught by an independent full-corpus
# (Matter 1.6 Core Specification, 1335 pages) parser run, ported back here
# so they can't silently reappear as the parser evolves.
# ---------------------------------------------------------------------------

def test_appendix_bleed_regression():
    """
    Regression test for the "RemoveEndpoint / appendix bleed" bug: before the
    appendix-boundary patterns were added, the last numbered section before an
    appendix would have no signal that a new section had started, and would
    silently swallow all following appendix content into its own full_text.

    This reproduces that boundary with a numbered command section
    (14.5.7.5 RemoveEndpoint Command) immediately followed by an appendix
    top-level heading, and asserts the two stay cleanly separated.
    """
    splitter = SectionSplitter(doc_name="core")

    sample_lines = [
        {"text": "14.5.7.5 RemoveEndpoint Command", "page_num": 1251, "font_size": 10.5, "is_bold": True},
        {"text": "This command is used to remove a dynamic endpoint.", "page_num": 1251, "font_size": 10.0, "is_bold": False},
        {"text": "On receipt, the server SHALL remove the specified endpoint.", "page_num": 1252, "font_size": 10.0, "is_bold": False},
        {"text": "Appendix A: Tag-Length-Value (TLV) Encoding Format", "page_num": 1253, "font_size": 14.0, "is_bold": True},
        {"text": "This appendix defines the TLV encoding used throughout Matter.", "page_num": 1253, "font_size": 10.0, "is_bold": False},
    ]

    sections = splitter.split_sections(sample_lines)

    assert len(sections) == 2

    remove_endpoint = sections[0]
    assert remove_endpoint["id"] == "core_14.5.7.5"
    assert remove_endpoint["title"] == "RemoveEndpoint Command"
    assert remove_endpoint["page_start"] == 1251
    assert remove_endpoint["page_end"] == 1252
    # The critical assertion: appendix content must NOT have bled into this section.
    assert "Tag-Length-Value" not in remove_endpoint["full_text"]
    assert "TLV encoding" not in remove_endpoint["full_text"]

    appendix_a = sections[1]
    assert appendix_a["id"] == "core_A"
    assert appendix_a["title"] == "Tag-Length-Value (TLV) Encoding Format"
    assert appendix_a["page_start"] == 1253
    assert "TLV encoding used throughout Matter" in appendix_a["full_text"]


def test_appendix_top_level_and_subsections_parsed():
    """
    Regression test for the "Appendix A misparse" bug: appendix headings
    ("Appendix A: Title") don't follow the numeric heading grammar at all, so
    the original numeric-only header_regex never recognized them as section
    boundaries, and appendix subsections ("A.2.3 Title") broke hierarchy
    resolution because the letter-rooted section number couldn't be parsed
    into a comparable tuple.

    This verifies: the top-level appendix heading becomes its own section,
    a direct subsection resolves its parent correctly, and a subsection whose
    intermediate level was never itself a section (A.2.3 with no A.2) still
    resolves up to the nearest existing ancestor (A) rather than crashing or
    silently getting parent_id=None.
    """
    splitter = SectionSplitter(doc_name="core")

    sample_lines = [
        {"text": "Appendix A: Tag-Length-Value (TLV) Encoding Format", "page_num": 1253, "font_size": 14.0, "is_bold": True},
        {"text": "This appendix defines the TLV encoding used throughout Matter.", "page_num": 1253, "font_size": 10.0, "is_bold": False},
        {"text": "A.1 Overview", "page_num": 1253, "font_size": 11.0, "is_bold": True},
        {"text": "TLV is a compact binary encoding scheme.", "page_num": 1253, "font_size": 10.0, "is_bold": False},
        {"text": "A.2.3 Nested Structure Encoding", "page_num": 1255, "font_size": 10.5, "is_bold": True},
        {"text": "Nested structures are encoded using container elements.", "page_num": 1255, "font_size": 10.0, "is_bold": False},
    ]

    sections = splitter.split_sections(sample_lines)
    assert len(sections) == 3

    sec_map = {s["id"]: s for s in sections}

    appendix_a = sec_map["core_A"]
    assert appendix_a["title"] == "Tag-Length-Value (TLV) Encoding Format"
    assert appendix_a["parent_id"] is None

    a_1 = sec_map["core_A.1"]
    assert a_1["title"] == "Overview"
    assert a_1["parent_id"] == "core_A"

    # A.2 was never its own section — hierarchy resolution must fall back to
    # the nearest existing ancestor (A), not None and not a crash.
    a_2_3 = sec_map["core_A.2.3"]
    assert a_2_3["title"] == "Nested Structure Encoding"
    assert a_2_3["parent_id"] == "core_A"

def test_basic_section_splitting():
    """
    Tests that a flat sequence of lines mimicking Matter spec style
    is correctly split into discrete sections with correct content and page numbers.
    """
    splitter = SectionSplitter(doc_name="core")
    
    sample_lines = [
        {"text": "1. Introduction", "page_num": 1, "font_size": 12.0, "is_bold": True},
        {"text": "This is the first paragraph of the introduction.", "page_num": 1, "font_size": 10.0, "is_bold": False},
        {"text": "1.1 Scope", "page_num": 2, "font_size": 11.0, "is_bold": True},
        {"text": "This covers the scope of the matter protocol.", "page_num": 2, "font_size": 10.0, "is_bold": False},
        {"text": "1.1.1 Exclusions", "page_num": 2, "font_size": 10.5, "is_bold": True},
        {"text": "Some features are excluded from this release.", "page_num": 3, "font_size": 10.0, "is_bold": False},
    ]
    
    sections = splitter.split_sections(sample_lines)
    
    assert len(sections) == 3
    
    # Verify Section 1
    sec1 = sections[0]
    assert sec1["id"] == "core_1"
    assert sec1["title"] == "Introduction"
    assert sec1["page_start"] == 1
    assert sec1["page_end"] == 1
    assert sec1["parent_id"] is None
    assert "This is the first paragraph" in sec1["full_text"]
    
    # Verify Section 1.1
    sec1_1 = sections[1]
    assert sec1_1["id"] == "core_1.1"
    assert sec1_1["title"] == "Scope"
    assert sec1_1["page_start"] == 2
    assert sec1_1["page_end"] == 2
    assert sec1_1["parent_id"] == "core_1"
    assert "This covers the scope" in sec1_1["full_text"]
    
    # Verify Section 1.1.1
    sec1_1_1 = sections[2]
    assert sec1_1_1["id"] == "core_1.1.1"
    assert sec1_1_1["title"] == "Exclusions"
    assert sec1_1_1["page_start"] == 2
    assert sec1_1_1["page_end"] == 3
    assert sec1_1_1["parent_id"] == "core_1.1"
    assert "Some features are excluded" in sec1_1_1["full_text"]


def test_hierarchy_and_parent_id():
    """
    Tests that parent-child relationships are correctly established
    even if there are gaps in numbering or deep nesting.
    """
    splitter = SectionSplitter(doc_name="app_cluster")
    
    sample_lines = [
        {"text": "4 Cluster Definition", "page_num": 1, "font_size": 12.0, "is_bold": True},
        {"text": "4.1 On/Off Cluster", "page_num": 1, "font_size": 11.0, "is_bold": True},
        {"text": "4.1.1 Attributes", "page_num": 2, "font_size": 10.5, "is_bold": True},
        {"text": "4.1.2 Commands", "page_num": 3, "font_size": 10.5, "is_bold": True},
        {"text": "5 Another Section", "page_num": 4, "font_size": 12.0, "is_bold": True},
    ]
    
    sections = splitter.split_sections(sample_lines)
    assert len(sections) == 5
    
    # Map to access by ID easily
    sec_map = {s["id"]: s for s in sections}
    
    assert sec_map["app_cluster_4"]["parent_id"] is None
    assert sec_map["app_cluster_4.1"]["parent_id"] == "app_cluster_4"
    assert sec_map["app_cluster_4.1.1"]["parent_id"] == "app_cluster_4.1"
    assert sec_map["app_cluster_4.1.2"]["parent_id"] == "app_cluster_4.1"
    assert sec_map["app_cluster_5"]["parent_id"] is None


def test_header_filtering_and_heuristics():
    """
    Tests that normal text sentences starting with numbers (like step lists) or
    non-headers are NOT incorrectly parsed as section headers.
    """
    splitter = SectionSplitter(doc_name="core", min_header_font_size=11.0)
    
    sample_lines = [
        {"text": "4. Commissioning Flow", "page_num": 1, "font_size": 12.0, "is_bold": True},
        # A list item that looks like a header pattern but has normal body font size and is not bold
        {"text": "1. Turn on the device power switch.", "page_num": 1, "font_size": 10.0, "is_bold": False},
        # Another list item that shouldn't be matched
        {"text": "2. Wait for the blue LED to blink.", "page_num": 1, "font_size": 10.0, "is_bold": False},
        # Header/Footer noise to skip
        {"text": "Matter Core Specification 1.3", "page_num": 1, "font_size": 8.0, "is_bold": False},
        {"text": "123", "page_num": 1, "font_size": 8.0, "is_bold": False},
    ]
    
    sections = splitter.split_sections(sample_lines)
    
    # We should only have 1 section (Section 4)
    assert len(sections) == 1
    assert sections[0]["id"] == "core_4"
    assert sections[0]["title"] == "Commissioning Flow"
    
    # The body text should contain the list items, but NOT the skip lines (like page headers/footers)
    full_text = sections[0]["full_text"]
    assert "Turn on the device power switch." in full_text
    assert "Wait for the blue LED to blink." in full_text
    assert "Matter Core Specification" not in full_text
    assert "123" not in full_text
