# Matter Smart-Home Specification Corpus Builder

This codebase scaffolds a data-preparation pipeline to process the **Matter Core Specification** and **Application Cluster Specification** PDFs into a structured, cross-referenced, and queryable corpus of sections. It is designed to prepare data for downstream LLM-based formal modeling of underspecified clauses.

## Repository Structure

```
matter-corpus/
├── data/
│   ├── raw_pdfs/            # Source PDFs go here (gitignored)
│   └── processed/           # Output JSON/SQLite corpus (gitignored)
├── src/
│   ├── ingestion/
│   │   └── pdf_extractor.py     # Layout-aware PDF -> text extraction (PyMuPDF)
│   ├── parsing/
│   │   ├── section_splitter.py  # Detect numbered headers, build section tree
│   │   └── crossref_extractor.py # Regex-extract "see Section X.Y" style refs
│   ├── tagging/
│   │   └── heuristic_tagger.py  # Keyword/regex tagging for state-based sections
│   ├── storage/
│   │   └── corpus_store.py      # Write/read corpus to SQLite with a clear schema
│   └── validate/
│       └── sample_check.py      # Pull N random sections for manual review, print diffs
├── tests/
│   └── test_section_splitter.py # Unit tests using a small known-good PDF excerpt
├── requirements.txt
├── .gitignore
└── README.md
```

## Section Schema

The structured corpus is stored in SQLite (and can be exported/viewed as JSON). Each section contains:

| Field | Type | Description |
|---|---|---|
| `id` | TEXT / VARCHAR | Unique Section Identifier (e.g., `core_4.15.2` or `app_cluster_11.3`) |
| `doc_name` | TEXT | Document name: `core` (Matter Core Spec) or `app_cluster` (Application Cluster Spec) |
| `title` | TEXT | Title of the section (e.g., "Commissioning Flow") |
| `full_text` | TEXT | Full extracted textual content of the section, preserving formatting and sequence |
| `page_start` | INTEGER | Starting page number in the source PDF (1-based) |
| `page_end` | INTEGER | Ending page number in the source PDF (1-based) |
| `parent_id` | TEXT / NULL | Unique ID of the parent section, establishing a hierarchy |
| `cross_refs` | TEXT (JSON array) | List of resolved and unresolved section IDs referenced within this section |
| `tags` | TEXT (JSON array) | Heuristic-based classification tags (e.g. `["state", "timer"]`) |

## Quick Start

### Installation
Ensure you have Python installed, then install the dependencies:
```bash
pip install -r requirements.txt
```

### Running the Pipeline
Run the CLI entrypoint to process a specification:
```bash
python -m src.build_corpus --pdf data/raw_pdfs/Matter-1.3-Core-Specification.pdf --doc-name core
```

### Running Tests
Execute unit tests:
```bash
pytest tests/
```
