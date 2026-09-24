# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

This is a thesis project about preparing the **Matter smart-home specification** (Core Spec + Application Cluster Spec) for LLM-assisted formal modeling of underspecified clauses. The only real code lives under `matter-corpus/`; the repo root is just a wrapper (`README.md` is a one-line stub, top-level `requirements.txt` mirrors `matter-corpus/requirements.txt`).

The pipeline turns a Matter spec PDF into a structured, cross-referenced, tagged, ranked JSON corpus, and `ArmFailSafe.tla` / `ArmFailSafe.cfg` (root of `matter-corpus/`) are a hand-written TLA+ model of one top-ranked candidate section (`core_11.10.7.2 ArmFailSafe Command`), checked with TLC via `tla2tools.jar`. That model is the target artifact the corpus pipeline is meant to help identify candidates for — the `UndefinedTransition` action in the model is a deliberate catch-all: if TLC reaches it, that's a formal specification gap worth reviewing (see the thesis methodology reference in the file's comments, "B.4.3").

## Commands

All commands run from `matter-corpus/` (there is a `.venv/` there, though it may need `python3 -m venv .venv --upgrade-deps` if `pip` is missing — the checked-in one has no `pip` binary).

```bash
cd matter-corpus
pip install -r requirements.txt      # pymupdf, pytest

# Run the full pipeline over a spec PDF
python -m src.build_corpus --pdf data/raw_pdfs/Matter-1.6-Core-Specification.pdf --doc-name core
# Optional flags: --out-dir, --min-header-font-size (default 11.0),
# --content-start-page (skip front-matter/ToC pages before parsing; 39 was the
# right cutoff for the Matter 1.6 Core spec)

# Quick manual smoke test on the small bundled PDF snippet (data/raw_pdfs/chapter_snippet.pdf)
python process_snippet.py

# Tests
pytest tests/
pytest tests/test_section_splitter.py::test_appendix_bleed_regression   # single test
```

`doc_name` becomes the id prefix for every section (`core` for the Core Specification, `app_cluster` for the Application Cluster Specification), so id collisions between the two specs are avoided by construction.

Source PDFs (`data/raw_pdfs/`) and pipeline output (`data/processed/`) are gitignored except for `.gitkeep`.

## Pipeline architecture

`src/build_corpus.py` wires together six stages in a fixed order (see its module docstring for the full rationale); each stage consumes and returns the same list of section dicts, threading state through mutation plus returned lists:

1. **`ingestion/pdf_extractor.py` (`PDFExtractor`)** — PyMuPDF layout-aware extraction into `RichLine` objects (text + page + font size/name + bold + bbox). Also merges soft-hyphen (`U+00AD`) line breaks so a word split across a page-wrap ("commis­" / "sioning") doesn't corrupt downstream header/keyword regexes.
2. **`parsing/section_splitter.py` (`SectionSplitter`)** — detects section headers and splits the flat line stream into a hierarchical tree (`parent_id` resolved by walking up the dotted numbering). Handles three header grammars: numeric (`4.15.2 Title`), appendix top-level (`Appendix A: Title`), and appendix subsections (`A.2.3 Title` — letter-rooted, so hierarchy resolution treats the first numbering component specially, see `_parse_section_number`). Distinguishes real headers from bolded normative body sentences ("3. If Msg1 contains ...") via a word-count cap and an RFC2119 keyword filter (SHALL/MUST/SHOULD/MAY) — see `_looks_like_prose_not_header`.
3. **`parsing/crossref_extractor.py` (`CrossRefExtractor`)** — regex-extracts `Section X.Y` / `Table Z` / `§` references from `full_text` and resolves them against known in-corpus section ids; unmatched references stay as unresolved refs, and unmatched `see ...` phrases are collected separately.
4. **`tagging/heuristic_tagger.py` (`HeuristicTagger`)** — keyword/regex tags per section (`state`, `timer`, `event`, `command`, `attribute`, `commissioning`, `security`, `network`, `matter`), used for corpus filtering/exploration, independent of the ranking scores below.
5. **`parsing/dependency_graph.py` (`DependencyGraph`)** — builds the *reverse* edge (`referenced_by`) that `cross_refs` alone doesn't give you, from the resolved, in-corpus cross-refs only (self-references and refs to unknown/external ids are dropped). `closure(unit_id, max_hops, direction)` does a BFS in either direction — this is the reproducible rule intended for automated LLM-context assembly (a fixed max-hops cutoff instead of ad hoc manual selection).
6. **`ranking/candidate_ranker.py` (`rank_candidates`)** — scores each section for formal-modeling relevance: `final_score = 0.6 * density_score + 0.4 * raw_score + dependency_bonus`, where `raw_score` is a weighted keyword-hit count (state-machine/timer/transport-window vocabulary — see `_KEYWORD_WEIGHTS`), `density_score` normalizes that per 100 words so long sections don't win on volume alone, and `dependency_bonus` rewards structurally-central sections (capped). Sections under `MIN_WORD_COUNT` (50) are excluded outright; only sections scoring `>= CANDIDATE_SCORE_THRESHOLD` (20.0) are returned, sorted descending. **The keyword list/weights are a reconstruction**, not the original validated table (see the module's `CALIBRATION NOTE`) — when re-deriving or tuning it, sanity-check that known-good candidates (`core_5.5`, `core_11.10.7.2`, `core_4.19.4.8`, `core_4.12.2.1`, `core_9.15.1.3`) still land in a similar rank neighborhood before trusting new output.

Outputs land in `data/processed/<doc-name>/`: `sections.json` (full corpus, cross_refs + tags + references/referenced_by all attached), `dependency_graph.json` (standalone graph), `ranked_candidates.json` (sections above threshold, sorted).

The README's repository-structure diagram also lists `storage/corpus_store.py` (SQLite read/write) and `validate/sample_check.py` (manual-review sampling) — these are aspirational/not yet implemented; there is no `src/storage/` or `src/validate/` directory in this checkout.

## Provenance note

A recurring pattern in this codebase (see comments in `section_splitter.py`, `dependency_graph.py`, `candidate_ranker.py`): logic was ported over or reconstructed after a **thesis collaborator's independent parser**, run on the full 1335-page Matter 1.6 Core Specification, caught bugs this codebase's smaller/snippet-tested version missed (appendix-boundary bleed, appendix header grammar, missing flow-control vocabulary in ranking, footer-boilerplate leaking into `full_text`). When touching these modules, check the regression tests in `tests/test_section_splitter.py` first — they encode those specific real-world failure cases, not just synthetic examples.
