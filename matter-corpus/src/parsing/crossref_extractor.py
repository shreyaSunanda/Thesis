# import re
# from typing import List, Dict, Any, Set, Optional

# class CrossRefExtractor:
#     """
#     Extracts cross-references (Sections, Tables, § symbols) and unmatched 'see' phrases
#     from section text, resolving references to known IDs when possible.
#     """
#     def __init__(self, doc_name: str, known_section_ids: Optional[Set[str]] = None):
#         self.doc_name = doc_name
#         self.known_section_ids = known_section_ids or set()
        
#         # Section pattern (case-insensitive): Group 1 = section number, Group 2 = optional quoted title
#         self.section_pattern = re.compile(
#             r'\bSection\s+(\d+(?:\.\d+)*)\b(?:\s*,\s*["\u201c\u201d]([^"\u201d\u201c]+)["\u201d\u201c])?',
#             re.IGNORECASE
#         )
        
#         # Table pattern (case-insensitive): Group 1 = table number, Group 2 = optional quoted title
#         self.table_pattern = re.compile(
#             r'\bTable\s+(\d+(?:\.\d+)*)\b(?:\s*,\s*["\u201c\u201d]([^"\u201d\u201c]+)["\u201d\u201c])?',
#             re.IGNORECASE
#         )
        
#         # § pattern: Group 1 = section number
#         self.section_symbol_pattern = re.compile(
#             r'§\s*(\d+(?:\.\d+)*)\b'
#         )
        
#         # 'see' pattern to catch everything starting with "see"
#         self.see_pattern = re.compile(
#             r'\bsee\s+([^,.;\n\(\)]+)',
#             re.IGNORECASE
#         )

#     def extract_from_text(self, text: str) -> Dict[str, Any]:
#         """
#         Extracts references from text.
#         Returns a dict containing:
#           - "cross_refs": List[Dict[str, Any]] (resolved/unresolved sections/tables)
#           - "unmatched_see_refs": List[str] (unmatched 'see' mentions)
#         """
#         cross_refs = []
#         unmatched_see_references = []
        
#         # Keep track of spans of text already matched by Section, Table, or §
#         matched_spans = []

#         # 1. Section pattern
#         for match in self.section_pattern.finditer(text):
#             matched_spans.append(match.span())
#             raw_match_text = match.group(0)
#             sec_num = match.group(1)
#             title = match.group(2) if match.group(2) else None
            
#             # Resolve section ID
#             candidate_id = f"{self.doc_name}_{sec_num}"
#             resolved = candidate_id if candidate_id in self.known_section_ids else None
            
#             cross_refs.append({
#                 "type": "section",
#                 "raw": raw_match_text,
#                 "number": sec_num,
#                 "title": title,
#                 "resolved": resolved
#             })

#         # 2. Table pattern
#         for match in self.table_pattern.finditer(text):
#             matched_spans.append(match.span())
#             raw_match_text = match.group(0)
#             table_num = match.group(1)
#             title = match.group(2) if match.group(2) else None
            
#             # Table ID namespace
#             resolved = f"{self.doc_name}_table_{table_num}"
            
#             cross_refs.append({
#                 "type": "table",
#                 "raw": raw_match_text,
#                 "number": table_num,
#                 "title": title,
#                 "resolved": resolved
#             })

#         # 3. § symbol pattern
#         for match in self.section_symbol_pattern.finditer(text):
#             matched_spans.append(match.span())
#             raw_match_text = match.group(0)
#             sec_num = match.group(1)
            
#             candidate_id = f"{self.doc_name}_{sec_num}"
#             resolved = candidate_id if candidate_id in self.known_section_ids else None
            
#             cross_refs.append({
#                 "type": "section",
#                 "raw": raw_match_text,
#                 "number": sec_num,
#                 "title": None,
#                 "resolved": resolved
#             })

#         # 4. 'see' pattern for unmatched see references
#         for match in self.see_pattern.finditer(text):
#             span_start, span_end = match.span()
#             # Check if this "see" overlaps with any of our matched Section, Table, or § references
#             # We check if the span of the "see" match overlaps or encapsulates, OR if the matched
#             # Section/Table/§ starts shortly after "see" (within the captured see text).
#             overlap = False
#             for m_start, m_end in matched_spans:
#                 # If a matched section reference falls within or right after the "see" text
#                 if (m_start >= span_start and m_start <= span_end) or (span_start >= m_start and span_start <= m_end):
#                     overlap = True
#                     break
            
#             if not overlap:
#                 raw_see_phrase = match.group(0).strip()
#                 # Clean up the trailing space/punctuation if any
#                 cleaned_phrase = re.sub(r'\s+', ' ', raw_see_phrase)
#                 unmatched_see_references.append(cleaned_phrase)

#         return {
#             "cross_refs": cross_refs,
#             "unmatched_see_refs": unmatched_see_references
#         }

#     def resolve_corpus_references(self, sections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
#         """
#         Takes a list of sections, extracts references, updates the known section IDs,
#         and re-resolves them dynamically.
#         """
#         # Step 1: Gather all section IDs in the corpus
#         all_ids = {s["id"] for s in sections}
#         self.known_section_ids.update(all_ids)
        
#         # Step 2: Extract and resolve references for each section
#         for sec in sections:
#             ext = self.extract_from_text(sec["full_text"])
#             sec["cross_refs"] = ext["cross_refs"]
#             sec["unmatched_see_refs"] = ext["unmatched_see_refs"]
            
#         return sections


import re
from typing import List, Dict, Any, Set, Optional

class CrossRefExtractor:
    """
    Extracts cross-references (Sections, Tables, § symbols) and unmatched 'see' phrases
    from section text, resolving references to known IDs when possible.
    """
    def __init__(self, doc_name: str, known_section_ids: Optional[Set[str]] = None):
        self.doc_name = doc_name
        self.known_section_ids = known_section_ids or set()
        
        # Section pattern (case-insensitive): Group 1 = section number, Group 2 = optional quoted title
        self.section_pattern = re.compile(
            r'\bSection\s+(\d+(?:\.\d+)*)\b(?:\s*,\s*["\u201c\u201d]([^"\u201d\u201c]+)["\u201d\u201c])?',
            re.IGNORECASE
        )
        
        # Table pattern (case-insensitive): Group 1 = table number, Group 2 = optional quoted title
        self.table_pattern = re.compile(
            r'\bTable\s+(\d+(?:\.\d+)*)\b(?:\s*,\s*["\u201c\u201d]([^"\u201d\u201c]+)["\u201d\u201c])?',
            re.IGNORECASE
        )
        
        # § pattern: Group 1 = section number
        self.section_symbol_pattern = re.compile(
            r'§\s*(\d+(?:\.\d+)*)\b'
        )
        
        # 'see' pattern to catch everything starting with "see"
        self.see_pattern = re.compile(
            r'\bsee\s+([^,.;\n\(\)]+)',
            re.IGNORECASE
        )

    def extract_from_text(self, text: str) -> Dict[str, Any]:
        """
        Extracts references from text.
        Returns a dict containing:
          - "cross_refs": List[Dict[str, Any]] (resolved/unresolved sections/tables)
          - "unmatched_see_refs": List[str] (unmatched 'see' mentions)
        """
        cross_refs = []
        unmatched_see_references = []
        
        # Keep track of spans of text already matched by Section, Table, or §
        matched_spans = []

        # 1. Section pattern
        for match in self.section_pattern.finditer(text):
            matched_spans.append(match.span())
            raw_match_text = match.group(0)
            sec_num = match.group(1)
            title = match.group(2) if match.group(2) else None
            
            # Resolve section ID
            candidate_id = f"{self.doc_name}_{sec_num}"
            resolved = candidate_id if candidate_id in self.known_section_ids else None
            
            cross_refs.append({
                "type": "section",
                "raw": raw_match_text,
                "number": sec_num,
                "title": title,
                "resolved": resolved
            })

        # 2. Table pattern
        for match in self.table_pattern.finditer(text):
            matched_spans.append(match.span())
            raw_match_text = match.group(0)
            table_num = match.group(1)
            title = match.group(2) if match.group(2) else None
            
            # Table ID namespace
            resolved = f"{self.doc_name}_table_{table_num}"
            
            cross_refs.append({
                "type": "table",
                "raw": raw_match_text,
                "number": table_num,
                "title": title,
                "resolved": resolved
            })

        # 3. § symbol pattern
        for match in self.section_symbol_pattern.finditer(text):
            matched_spans.append(match.span())
            raw_match_text = match.group(0)
            sec_num = match.group(1)
            
            candidate_id = f"{self.doc_name}_{sec_num}"
            resolved = candidate_id if candidate_id in self.known_section_ids else None
            
            cross_refs.append({
                "type": "section",
                "raw": raw_match_text,
                "number": sec_num,
                "title": None,
                "resolved": resolved
            })

        # 4. 'see' pattern for unmatched see references
        for match in self.see_pattern.finditer(text):
            span_start, span_end = match.span()
            # Check if this "see" overlaps with any of our matched Section, Table, or § references
            # We check if the span of the "see" match overlaps or encapsulates, OR if the matched
            # Section/Table/§ starts shortly after "see" (within the captured see text).
            overlap = False
            for m_start, m_end in matched_spans:
                # If a matched section reference falls within or right after the "see" text
                if (m_start >= span_start and m_start <= span_end) or (span_start >= m_start and span_start <= m_end):
                    overlap = True
                    break
            
            if not overlap:
                raw_see_phrase = match.group(0).strip()
                # Clean up the trailing space/punctuation if any
                cleaned_phrase = re.sub(r'\s+', ' ', raw_see_phrase)
                unmatched_see_references.append(cleaned_phrase)

        return {
            "cross_refs": cross_refs,
            "unmatched_see_refs": unmatched_see_references
        }

    def resolve_corpus_references(self, sections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Takes a list of sections, extracts references, updates the known section IDs,
        and re-resolves them dynamically.
        """
        # Step 1: Gather all section IDs in the corpus
        all_ids = {s["id"] for s in sections}
        self.known_section_ids.update(all_ids)
        
        # Step 2: Extract and resolve references for each section
        for sec in sections:
            ext = self.extract_from_text(sec["full_text"])
            sec["cross_refs"] = ext["cross_refs"]
            sec["unmatched_see_refs"] = ext["unmatched_see_refs"]
            
        return sections
