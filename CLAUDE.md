# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

This is a thesis project about preparing the **Matter smart-home specification** (Core Spec + Application Cluster Spec) for LLM-assisted formal modeling of underspecified clauses. The only real code lives under `matter-corpus/`; the repo root is just a wrapper (`README.md` is a one-line stub, top-level `requirements.txt` mirrors `matter-corpus/requirements.txt`).

The pipeline turns a Matter spec PDF into a structured, cross-referenced, tagged, ranked JSON corpus, then (per target section) assembles LLM context, extracts a behavioural JSON model and a TLA+ module via OpenRouter, and checks it with SANY + TLC — automatically decomposing the model when TLC's state space exceeds a budget. `ArmFailSafe.tla` / `ArmFailSafe.cfg` (root of `matter-corpus/`) and the models under `tla_models/` are hand-written TLA+ models; the `UndefinedTransition` action in them is a deliberate catch-all: if TLC reaches it, that's a formal specification gap worth reviewing (see the thesis methodology reference in the file's comments, "B.4.3").

## Commands

All commands run from `matter-corpus/` (there is a `.venv/` there, though it may need `python3 -m venv .venv --upgrade-deps` if `pip` is missing — the checked-in one has no `pip` binary).

```bash
cd matter-corpus
pip install -r requirements.txt      # pymupdf, pytest, openai

# Run the full pipeline over a spec PDF
python -m src.build_corpus --pdf data/raw_pdfs/Matter-1.6-Core-Specification.pdf --doc-name core
# Optional flags: --out-dir, --min-header-font-size (default 11.0),
# --content-start-page (skip front-matter/ToC pages before parsing; 39 was the
# right cutoff for the Matter 1.6 Core spec)

# Quick manual smoke test on the small bundled PDF snippet (data/raw_pdfs/chapter_snippet.pdf)
python process_snippet.py

# Spec -> TLA+ -> SANY/TLC (needs OPENROUTER_API_KEY for the LLM stages, and java)
python -m src.run_pipeline --sections core_11.10.7.2 --second-hop 4.11.1.1 11.18.6.5 11.18.4.9
python -m src.run_pipeline --top 5                 # top-N ranked candidates
python -m src.run_pipeline --verify-only           # no LLM: re-check every model with a .cfg

# Verify one model (SANY -> TLC under budget -> auto-decompose if it explodes)
python -m src.verify tla_models/core_4.20.3_session/PAFTPSessionNaive.tla
python -m src.verify Model.tla --max-states 200000 --timeout 300
python -m src.verify Model.tla --compare           # full AND decomposed, diffed (losslessness check)

# Tests (test_decomposition / test_generation_pipeline need java; no API key needed)
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

## Modelling and verification stages

`src/run_pipeline.py` chains everything after the corpus, per target section, writing to `tla_models/generated/<section_id>/` (context, `behaviour.json`, `<Module>.tla/.cfg`, `provenance.json` with requested/actual model ids and prompt versions, `verification/`). Cached stage outputs are reused unless `--regenerate`, so LLM calls are never repeated by accident; a hand-written `.cfg` next to a generated module always wins.

- **`generation/`** — port of the Colab notebook (`Untitled19.ipynb`, cells 33–61). `context.py` (parent + target + one-hop refs + optional chosen second hop), `behaviour.py` (prompt `behavior_extraction_v1`, JSON/field/source-id validation, unclear → `requires_context_verification`), `tla_generation.py` (prompt `tla_code_v2`, verbatim from the notebook; plus a NEW `tlc_cfg_v1` call for the TLC config, which the notebook never needed). `llm.py` uses OpenRouter with a fixed model (`nvidia/nemotron-3-super-120b-a12b:free`), temperature 0, reasoning disabled — the configuration that first produced a complete module (progress log §28). Generated TLA+ is not hand-corrected before SANY/TLC.
- **`verify.py`** — SANY, then TLC on the whole model under a budget (`--max-states`, `--timeout`, JVM heap via `TLC_HEAP`). Only if TLC does not finish is the model decomposed. TLC runs with `-continue` (all violations, not just the first) and with every INVARIANT also added as a CONSTRAINT, so each reported violation is *primary* (the step that breaks an invariant from a good state). Findings are keyed by (invariant, violating action, hub/control-variable values before the step) — i.e. "(state, event) is unhandled".
- **`tla/`** — `tools.py` (SANY/TLC runners; the state budget is an `Assert(TLCGet("distinct") <= N)` CONSTRAINT in a wrapper module), `cfg.py`, `sany_ast.py` (SANY's XML export → semantic AST with exact source spans; all analysis is on this, never on regexes over TLA+ text).
- **`decomposition/`** — automatic decomposition, general over any TLA+ style (house style or LLM-generated):
  - `footprint.py`: per-action read/write sets (UNCHANGED / `x' = x` are frames, not writes; helper operators expanded).
  - `planner.py`: picks *hub* variables (shared by every piece, e.g. `phase`, `pendingEvent`) and partitions the rest into groups that no action couples by data flow. On `PAFTPSessionNaive` it finds the hand split of SESSION_LOG §6.3 and splits SDU further (send queue vs. reassembly).
  - `abstraction.py`: per group, rewrites the original module in place so other groups' variables are existentially abstracted (hidden atoms → TRUE/FALSE by polarity, or a free `abs__hN` boolean; frames drop hidden vars). Every piece *over-approximates* the full model, so it cannot miss a violation. Hidden data flowing into kept variables (`y' = x`) is refused, never guessed.
  - `replay.py`: every piece counterexample is re-executed on the *full* model with the piece's variables pinned per step (strict round, then permissive). Replayed → `confirmed` (with a concrete full trace); not replayed → `unconfirmed` (kept and flagged, never dropped).
  - Deadlock is not checked on pieces (whole-model property). Temporal PROPERTYs, INSTANCE and tab-indented sources are refused.
- Losslessness is tested in `tests/test_decomposition.py` (full vs. decomposed findings must match exactly) on `PAFTPSessionNaive.tla` and on `tests/fixtures/llm_style/FailSafeContext.tla` (an LLM-style fixture, not a real Matter model).

Verification outputs (`verification/` dirs) are gitignored; generated models under `tla_models/generated/` are research artifacts and are not.

The README's repository-structure diagram also lists `storage/corpus_store.py` (SQLite read/write) and `validate/sample_check.py` (manual-review sampling) — these are aspirational/not yet implemented; there is no `src/storage/` or `src/validate/` directory in this checkout.

## Provenance note

A recurring pattern in this codebase (see comments in `section_splitter.py`, `dependency_graph.py`, `candidate_ranker.py`): logic was ported over or reconstructed after a **thesis collaborator's independent parser**, run on the full 1335-page Matter 1.6 Core Specification, caught bugs this codebase's smaller/snippet-tested version missed (appendix-boundary bleed, appendix header grammar, missing flow-control vocabulary in ranking, footer-boilerplate leaking into `full_text`). When touching these modules, check the regression tests in `tests/test_section_splitter.py` first — they encode those specific real-world failure cases, not just synthetic examples.
