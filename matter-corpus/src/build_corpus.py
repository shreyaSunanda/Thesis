"""
CLI entrypoint: run the full corpus-preparation pipeline over a single Matter
spec PDF (Core or Application Cluster) end-to-end.

Usage:
    python -m src.build_corpus --pdf data/raw_pdfs/Matter-1.6-Core-Specification.pdf --doc-name core

Pipeline:
    PDF
      -> PDFExtractor          (rich lines: text + font/bold/page metadata, soft-hyphen cleanup)
      -> SectionSplitter       (hierarchical sections, appendix-aware, footer-boilerplate-aware)
      -> CrossRefExtractor     (resolve "Section X.Y" / "Table Z" / "§" refs)
      -> HeuristicTagger       (keyword tags: state, timer, commissioning, ...)
      -> DependencyGraph       (bidirectional references / referenced_by)
      -> candidate_ranker      (score + rank sections for formal modelling)

Outputs (written under --out-dir, default data/processed/<doc-name>/):
    sections.json            - full structured corpus, one record per section
                                (includes cross_refs, tags, references, referenced_by)
    dependency_graph.json    - references / referenced_by per section id, standalone
    ranked_candidates.json   - sections scoring >= threshold, sorted highest first
"""
import argparse
import json
import sys
import time
from dataclasses import asdict
from pathlib import Path

from src.ingestion.pdf_extractor import PDFExtractor
from src.parsing.section_splitter import SectionSplitter
from src.parsing.crossref_extractor import CrossRefExtractor
from src.parsing.dependency_graph import DependencyGraph, build_dependency_graph
from src.tagging.heuristic_tagger import HeuristicTagger
from src.ranking.candidate_ranker import rank_candidates, MIN_WORD_COUNT, CANDIDATE_SCORE_THRESHOLD


def build_corpus(
    pdf_path: str,
    doc_name: str,
    out_dir: str,
    min_header_font_size: float = 11.0,
    content_start_page: int = None,
) -> dict:
    t0 = time.time()

    pdf_path = Path(pdf_path)
    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF not found: {pdf_path}")

    out_path = Path(out_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    # 1. Extract rich lines (text + font/bold/page metadata), with soft-hyphen cleanup.
    print(f"[1/6] Extracting text from {pdf_path} ...")
    extractor = PDFExtractor(pdf_path=str(pdf_path))
    rich_lines = extractor.extract_rich_lines()
    print(f"      -> {len(rich_lines)} lines extracted")

    # Front matter / table-of-contents pages repeat every real section number
    # (often bold, to mimic heading style), so without a cutoff each ToC entry
    # gets misdetected as its own duplicate "section" alongside the real one
    # later in the document. This inflates the section count and pollutes the
    # dependency graph and rankings with junk duplicate ids.
    if content_start_page is not None:
        before = len(rich_lines)
        rich_lines = [l for l in rich_lines if l.page_num >= content_start_page]
        print(f"      -> skipping front matter before page {content_start_page}: "
              f"removed {before - len(rich_lines)} lines, {len(rich_lines)} remain")

    # 2. Split into hierarchical sections (numeric + appendix-aware).
    print("[2/6] Splitting into sections ...")
    splitter = SectionSplitter(doc_name=doc_name, min_header_font_size=min_header_font_size)
    sections = splitter.split_sections(rich_lines)
    print(f"      -> {len(sections)} sections found")

    # 3. Extract and resolve cross-references.
    print("[3/6] Resolving cross-references ...")
    crossref_extractor = CrossRefExtractor(doc_name=doc_name)
    sections = crossref_extractor.resolve_corpus_references(sections)

    # 4. Apply heuristic keyword tags.
    print("[4/6] Applying heuristic tags ...")
    tagger = HeuristicTagger()
    sections = tagger.tag_sections(sections)

    # 5. Build the bidirectional dependency graph and attach it to sections.
    print("[5/6] Building dependency graph ...")
    graph = build_dependency_graph(sections)
    sections = DependencyGraph.attach_to_sections(sections, graph)

    # 6. Rank candidates for formal modelling.
    print("[6/6] Ranking candidates ...")
    candidates = rank_candidates(sections)
    print(f"      -> {len(candidates)} candidates scored >= {CANDIDATE_SCORE_THRESHOLD} "
          f"(min {MIN_WORD_COUNT} words)")

    # --- Write outputs ---
    sections_path = out_path / "sections.json"
    with open(sections_path, "w", encoding="utf-8") as f:
        json.dump(sections, f, indent=2, ensure_ascii=False)

    graph_path = out_path / "dependency_graph.json"
    with open(graph_path, "w", encoding="utf-8") as f:
        json.dump(graph.to_dict(), f, indent=2, ensure_ascii=False)

    ranked_path = out_path / "ranked_candidates.json"
    with open(ranked_path, "w", encoding="utf-8") as f:
        json.dump([asdict(c) for c in candidates], f, indent=2, ensure_ascii=False)

    elapsed = time.time() - t0
    print(f"\nDone in {elapsed:.1f}s. Wrote:")
    print(f"  {sections_path}")
    print(f"  {graph_path}")
    print(f"  {ranked_path}")

    if candidates:
        print("\nTop 10 ranked candidates:")
        for c in candidates[:10]:
            print(f"  {c.final_score:>7.2f}  {c.id:<20} {c.title}")

    return {
        "sections_path": str(sections_path),
        "graph_path": str(graph_path),
        "ranked_path": str(ranked_path),
        "num_sections": len(sections),
        "num_candidates": len(candidates),
        "elapsed_seconds": elapsed,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Build a structured, cross-referenced Matter spec corpus from a PDF."
    )
    parser.add_argument("--pdf", required=True,
                         help="Path to the source spec PDF (Core or Application Cluster).")
    parser.add_argument("--doc-name", required=True,
                         help="Short doc identifier used as the id prefix for every section, "
                              "e.g. 'core' or 'app_cluster'.")
    parser.add_argument("--out-dir", default=None,
                         help="Output directory (default: data/processed/<doc-name>/).")
    parser.add_argument("--min-header-font-size", type=float, default=11.0,
                         help="Minimum font size (points) for a single-level numeric header "
                              "to be accepted without being bold. Default 11.0 — raise this if "
                              "body text is getting misdetected as headers, lower it if real "
                              "headers are being missed.")
    parser.add_argument("--content-start-page", type=int, default=None,
                         help="Skip all lines before this 1-based page number before parsing "
                              "sections, to exclude front matter / table-of-contents pages "
                              "(each ToC entry otherwise gets misdetected as its own duplicate "
                              "section). A collaborator's independently-built parser found page "
                              "39 to be the right cutoff for this exact spec version (Matter 1.6 "
                              "Core) — try --content-start-page 39 first and compare section "
                              "counts before and after.")
    args = parser.parse_args()

    out_dir = args.out_dir or f"data/processed/{args.doc_name}"

    try:
        build_corpus(
            pdf_path=args.pdf,
            doc_name=args.doc_name,
            out_dir=out_dir,
            min_header_font_size=args.min_header_font_size,
            content_start_page=args.content_start_page,
        )
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
