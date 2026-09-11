import json
from src.ingestion.pdf_extractor import PDFExtractor
from src.parsing.section_splitter import SectionSplitter
from src.parsing.crossref_extractor import CrossRefExtractor
from src.tagging.heuristic_tagger import HeuristicTagger

# 1. Configuration
PDF_PATH = "data/raw_pdfs/chapter_snippet.pdf"
DOC_NAME = "core"  # Use 'core' or 'app_cluster'

# 2. Extract rich lines (text + font sizes + coordinates)
print(f"Extracting lines from {PDF_PATH}...")
extractor = PDFExtractor(pdf_path=PDF_PATH)
rich_lines = extractor.extract_rich_lines()

# 3. Parse headers and split lines into hierarchical sections
print("Splitting sections based on numbered headers...")
splitter = SectionSplitter(doc_name=DOC_NAME)
sections = splitter.split_sections(rich_lines)

# 4. Extract and resolve cross-references ('Section X.Y', 'Table Z', '§')
print("Resolving cross-references...")
crossref_extractor = CrossRefExtractor(doc_name=DOC_NAME)
sections = crossref_extractor.resolve_corpus_references(sections)

# 5. Apply state machine, timer, and security heuristic tags
print("Applying heuristic tags...")
tagger = HeuristicTagger()
sections = tagger.tag_sections(sections)

# 6. Preview results & Save to JSON
print(f"\nExtracted {len(sections)} sections successfully!\n")
for s in sections[:3]:
    print(f"[{s['id']}] {s['title']} (Pages: {s['page_start']}-{s['page_end']})")
    print(f"  Parent: {s['parent_id']}")
    print(f"  Tags: {s['tags']}")
    print(f"  Refs: {len(s['cross_refs'])} found\n")

# Save output
output_path = "data/processed/snippet_sections.json"
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(sections, f, indent=2, ensure_ascii=False)

print(f"Saved structured sections to {output_path}")