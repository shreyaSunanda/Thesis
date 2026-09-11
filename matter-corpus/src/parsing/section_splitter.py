# import re
# from typing import List, Dict, Any, Union, Optional
# from src.ingestion.pdf_extractor import RichLine

# class SectionSplitter:
#     """
#     Parses a sequence of RichLines or simple dicts/strings to detect numbered
#     headers (e.g. '4.15.2 Commissioning Flow' or '11.3') and splits the document
#     into a structured hierarchical tree of sections.
#     """
#     def __init__(self, doc_name: str, min_header_font_size: float = 11.0):
#         self.doc_name = doc_name
#         self.min_header_font_size = min_header_font_size
        
#         # Regex to match numbered headers: e.g. "4.15.2 Commissioning Flow" or "11.3 State"
#         # We match numbers separated by dots (e.g. "4.15", "11.3.1.2") followed by space and the title.
#         # We also allow single digits "4. Title" if the title starts with a capital letter.
#         self.header_regex = re.compile(r'^\s*(\d+(?:\.\d+)*)\.?\s+([A-Z0-9].*)$')
        
#         # Common page header/footer patterns to skip (case-insensitive)
#         self.skip_patterns = [
#             re.compile(r'^matter\s+core\s+specification', re.IGNORECASE),
#             re.compile(r'^application\s+cluster\s+specification', re.IGNORECASE),
#             re.compile(r'^revision\s+history', re.IGNORECASE),
#             re.compile(r'^\d+\s*$', re.IGNORECASE),  # Solo page numbers
#         ]

#     def _is_skip_line(self, text: str) -> bool:
#         """Returns True if the line is likely a page header, footer, or noise."""
#         for pattern in self.skip_patterns:
#             if pattern.search(text):
#                 return True
#         return False

#     def parse_header(self, text: str, is_bold: bool, font_size: float) -> Optional[tuple]:
#         """
#         Attempts to parse a line as a section header.
#         Returns (section_num_str, title_str) if successful, otherwise None.
#         """
#         if self._is_skip_line(text):
#             return None
            
#         match = self.header_regex.match(text)
#         if not match:
#             return None
            
#         section_num, title = match.groups()
        
#         # Heuristics using styling if available (e.g., if font_size is passed)
#         # For single digit sections (e.g. "4 Title"), we strictly require bold/formatting or larger font
#         # to distinguish from a simple numbered list item (e.g. "1. Step one").
#         is_multilevel = '.' in section_num
        
#         # If we have formatting information:
#         if font_size > 0:
#             # Multi-level headers are very likely headers.
#             # Single-level need to be bold or have a larger font.
#             if not is_multilevel:
#                 if not is_bold and font_size < self.min_header_font_size:
#                     return None
#             else:
#                 # Even multi-level headers shouldn't be super tiny body text
#                 if font_size < 9.0:
#                     return None
        
#         # Header titles shouldn't be excessively long (most are under 100 chars, definitely under 150)
#         if len(title) > 150:
#             return None
            
#         return section_num, title.strip()

#     def split_sections(self, lines: Union[List[RichLine], List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
#         """
#         Processes a flat sequence of lines into a list of structured sections.
#         """
#         sections: List[Dict[str, Any]] = []
#         current_section: Optional[Dict[str, Any]] = None
        
#         # Keep track of active sections at different numbering levels to resolve hierarchy
#         # Map: section_num_tuple -> section_id
#         num_to_id_map: Dict[tuple, str] = {}
        
#         for line in lines:
#             # Handle both RichLine objects and dictionaries (useful for tests/JSON loads)
#             if isinstance(line, RichLine):
#                 text = line.text
#                 page_num = line.page_num
#                 font_size = line.font_size
#                 is_bold = line.is_bold
#             elif isinstance(line, dict):
#                 text = line.get("text", "")
#                 page_num = line.get("page_num", 1)
#                 font_size = line.get("font_size", 0.0)
#                 is_bold = line.get("is_bold", False)
#             else:
#                 # Fallback for plain string inputs (e.g. raw text lists in simple tests)
#                 text = str(line)
#                 page_num = 1
#                 font_size = 0.0
#                 is_bold = False
                
#             cleaned_text = text.strip()
#             if not cleaned_text:
#                 continue
                
#             parsed = self.parse_header(cleaned_text, is_bold, font_size)
            
#             if parsed:
#                 sec_num, sec_title = parsed
#                 sec_id = f"{self.doc_name}_{sec_num}"
                
#                 # Close the previous section
#                 if current_section:
#                     current_section["full_text"] = "\n".join(current_section["_temp_lines"]).strip()
#                     # Delete the temp lines
#                     del current_section["_temp_lines"]
#                     sections.append(current_section)
                
#                 # Parse section number into tuple of ints for hierarchy resolution
#                 # e.g., "4.15.2" -> (4, 15, 2)
#                 try:
#                     num_parts = tuple(int(x) for x in sec_num.split('.'))
#                 except ValueError:
#                     # Fallback in case section number contains non-digits, though rare
#                     num_parts = (sec_num,)
                
#                 # Determine parent_id by walking up the hierarchy
#                 parent_id = None
#                 if len(num_parts) > 1:
#                     for i in range(len(num_parts) - 1, 0, -1):
#                         parent_candidate = num_parts[:i]
#                         if parent_candidate in num_to_id_map:
#                             parent_id = num_to_id_map[parent_candidate]
#                             break
                
#                 # Register current section in the map
#                 num_to_id_map[num_parts] = sec_id
                
#                 current_section = {
#                     "id": sec_id,
#                     "doc_name": self.doc_name,
#                     "title": sec_title,
#                     "page_start": page_num,
#                     "page_end": page_num,
#                     "parent_id": parent_id,
#                     "cross_refs": [],  # Filled in by crossref_extractor
#                     "tags": [],        # Filled in by heuristic_tagger
#                     "_temp_lines": [cleaned_text],  # Keep header in text for completeness
#                 }
#             else:
#                 # Regular body line
#                 if current_section:
#                     if not self._is_skip_line(cleaned_text):
#                         current_section["_temp_lines"].append(cleaned_text)
#                     current_section["page_end"] = page_num
                    
#         # Close the final section
#         if current_section:
#             current_section["full_text"] = "\n".join(current_section["_temp_lines"]).strip()
#             del current_section["_temp_lines"]
#             sections.append(current_section)
            
#         return sections

import re
from typing import List, Dict, Any, Union, Optional, Tuple
from src.ingestion.pdf_extractor import RichLine


class SectionSplitter:
    """
    Parses a sequence of RichLines or simple dicts/strings to detect numbered
    headers (e.g. '4.15.2 Commissioning Flow' or '11.3') AND appendix headers
    (e.g. 'Appendix A: Tag-Length-Value (TLV) Encoding Format' or 'A.2.3 Some
    Subsection'), and splits the document into a structured hierarchical tree
    of sections.

    Appendix support was ported over after a thesis-collaborator's independent
    parser (run on the full Matter 1.6 Core Specification, 1335 pages) caught
    two real bugs that this parser did not originally guard against:

      1. "Appendix bleed" — without an appendix boundary pattern, the last
         numbered section before an appendix (e.g. 14.5.7.5 RemoveEndpoint
         Command) would silently swallow all appendix content that followed
         it, since nothing signalled a new section had started. This badly
         skewed downstream candidate-ranking scores for that section.
      2. Appendix top-level headings (e.g. "Appendix A: ...") don't follow
         the numeric heading grammar at all, so they were invisible to the
         original numeric-only header_regex and never became sections in
         their own right.

    See tests/test_section_splitter.py for regression tests reproducing both.
    """
    def __init__(self, doc_name: str, min_header_font_size: float = 11.0):
        self.doc_name = doc_name
        self.min_header_font_size = min_header_font_size

        # Regex to match numbered headers: e.g. "4.15.2 Commissioning Flow" or "11.3 State"
        # We match numbers separated by dots (e.g. "4.15", "11.3.1.2") followed by space and the title.
        # We also allow single digits "4. Title" if the title starts with a capital letter.
        self.header_regex = re.compile(r'^\s*(\d+(?:\.\d+)*)\.?\s+([A-Z0-9].*)$')

        # Appendix top-level heading: "Appendix A: Tag-Length-Value (TLV) Encoding Format"
        # Anchored to the whole line (via $) so it can't fire on a prose sentence that merely
        # *mentions* an appendix mid-paragraph — a real line wrapped from body text won't
        # consist of exactly "Appendix <Letter>: <title>" and nothing else.
        self.appendix_top_pattern = re.compile(
            r'^\s*Appendix\s+([A-Z]):\s*(.+?)\s*$', re.IGNORECASE
        )

        # Appendix subsection heading: "A.2.3 Some Title" or "A.2.3. Some Title"
        self.appendix_section_pattern = re.compile(
            r'^\s*([A-Z](?:\.\d+)+)\.?\s+([A-Z0-9].*)$'
        )

        # Common page header/footer patterns to skip (case-insensitive).
        # Broadened beyond the original exact-string patterns after checking real
        # extractor output against a Matter 1.6 snippet: the repeated footer block
        # ("Matter Specification R1.6" / "Connectivity Standards Alliance Document ..." /
        # "Copyright © ..." / "Page N") was NOT matching any of the original patterns
        # and was leaking straight into full_text on every section that crossed a
        # page boundary. These additions close that gap.
        self.skip_patterns = [
            re.compile(r'^matter\s+core\s+specification', re.IGNORECASE),
            re.compile(r'^application\s+cluster\s+specification', re.IGNORECASE),
            re.compile(r'^revision\s+history', re.IGNORECASE),
            re.compile(r'^\d+\s*$', re.IGNORECASE),  # Solo page numbers
            re.compile(r'^matter\s+specification\s+r?\d', re.IGNORECASE),
            re.compile(r'^connectivity\s+standards\s+alliance', re.IGNORECASE),
            re.compile(r'^copyright\s+©', re.IGNORECASE),
            re.compile(r'^page\s+\d+\s*$', re.IGNORECASE),
        ]

        # Found by running on the real 1335-page Matter 1.6 Core Specification:
        # a BOLD numbered normative list item ("3. If Msg1 contains both the
        # resumptionID and initiatorResumeMIC fields, the responder SHALL ...")
        # was passing the single-digit header check, because that check only
        # required bold-or-large-font — it had no way to tell "3 Certificate
        # Handling" (a real heading) apart from "3. If Msg1 contains ..." (a
        # bolded step inside some other section's body text). Real headings are
        # short noun phrases; normative body sentences are long and use RFC2119
        # keywords. Both signals below catch that difference.
        self._normative_keyword_pattern = re.compile(
            r'\b(SHALL(?:\s+NOT)?|MUST(?:\s+NOT)?|SHOULD(?:\s+NOT)?|MAY)\b'
        )
        self._max_header_words = 12

    def _looks_like_prose_not_header(self, title: str) -> bool:
        """
        Returns True if `title` reads like a sentence fragment rather than a
        heading — too many words, or contains an RFC2119 normative keyword
        (SHALL/MUST/SHOULD/MAY), which essentially never appears in an actual
        Matter section title but is extremely common in normative body text.
        """
        if len(title.split()) > self._max_header_words:
            return True
        if self._normative_keyword_pattern.search(title):
            return True
        return False

    def _is_skip_line(self, text: str) -> bool:
        """Returns True if the line is likely a page header, footer, or noise."""
        for pattern in self.skip_patterns:
            if pattern.search(text):
                return True
        return False

    def parse_header(self, text: str, is_bold: bool, font_size: float) -> Optional[Tuple[str, str]]:
        """
        Attempts to parse a line as a section header — numeric, appendix top-level,
        or appendix subsection. Returns (section_num_str, title_str) if successful,
        otherwise None.
        """
        if self._is_skip_line(text):
            return None

        # 1. Appendix top-level heading: "Appendix A: Title" — distinct grammar,
        #    checked first since it won't match the numeric/appendix-subsection patterns.
        appendix_top_match = self.appendix_top_pattern.match(text)
        if appendix_top_match:
            letter, title = appendix_top_match.groups()
            # Same false-positive guard as single-level numeric headers below:
            # require bold or a large-enough font so a wrapped prose line that
            # happens to start with "Appendix X:" doesn't get treated as a header.
            if font_size > 0 and not is_bold and font_size < self.min_header_font_size:
                return None
            if len(title) > 150:
                return None
            if self._looks_like_prose_not_header(title):
                return None
            return letter.upper(), title.strip()

        # 2. Appendix subsection heading: "A.2.3 Title" — treated like a multi-level
        #    numeric header (accepted without the bold/font gate, since deep numbering
        #    itself is already a strong signal), but still subject to the tiny-font guard.
        appendix_sub_match = self.appendix_section_pattern.match(text)
        if appendix_sub_match:
            sec_num, title = appendix_sub_match.groups()
            if font_size > 0 and font_size < 9.0:
                return None
            if len(title) > 150:
                return None
            if self._looks_like_prose_not_header(title):
                return None
            return sec_num.upper(), title.strip()

        # 3. Standard numeric header: "4.15.2 Title" / "4 Title"
        match = self.header_regex.match(text)
        if not match:
            return None

        section_num, title = match.groups()

        # Heuristics using styling if available (e.g., if font_size is passed)
        # For single digit sections (e.g. "4 Title"), we strictly require bold/formatting or larger font
        # to distinguish from a simple numbered list item (e.g. "1. Step one").
        is_multilevel = '.' in section_num

        # If we have formatting information:
        if font_size > 0:
            # Multi-level headers are very likely headers.
            # Single-level need to be bold or have a larger font.
            if not is_multilevel:
                if not is_bold and font_size < self.min_header_font_size:
                    return None
            else:
                # Even multi-level headers shouldn't be super tiny body text
                if font_size < 9.0:
                    return None

        # Header titles shouldn't be excessively long (most are under 100 chars, definitely under 150)
        if len(title) > 150:
            return None

        if self._looks_like_prose_not_header(title):
            return None

        return section_num, title.strip()

    @staticmethod
    def _parse_section_number(sec_num: str) -> tuple:
        """
        Parses a section-number string into a tuple usable as a hierarchy key.

        Handles both plain numeric sections ("4.15.2" -> (4, 15, 2)) and appendix
        sections whose root is a letter ("A.2.3" -> ("A", 2, 3)). The original
        implementation only handled the numeric case and fell back to treating the
        *entire string* as one opaque tuple element on ValueError — which silently
        broke hierarchy resolution for any multi-level appendix section, since
        ("A.2.3",) never matches a parent candidate like ("A", 2).
        """
        parts = sec_num.split('.')
        parsed = []
        for idx, part in enumerate(parts):
            if idx == 0 and not part.isdigit():
                # Appendix letter root (e.g. "A") — keep as-is.
                parsed.append(part.upper())
            else:
                try:
                    parsed.append(int(part))
                except ValueError:
                    parsed.append(part)
        return tuple(parsed)

    def split_sections(self, lines: Union[List[RichLine], List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
        """
        Processes a flat sequence of lines into a list of structured sections.
        """
        sections: List[Dict[str, Any]] = []
        current_section: Optional[Dict[str, Any]] = None

        # Keep track of active sections at different numbering levels to resolve hierarchy
        # Map: section_num_tuple -> section_id
        num_to_id_map: Dict[tuple, str] = {}

        for line in lines:
            # Handle both RichLine objects and dictionaries (useful for tests/JSON loads)
            if isinstance(line, RichLine):
                text = line.text
                page_num = line.page_num
                font_size = line.font_size
                is_bold = line.is_bold
            elif isinstance(line, dict):
                text = line.get("text", "")
                page_num = line.get("page_num", 1)
                font_size = line.get("font_size", 0.0)
                is_bold = line.get("is_bold", False)
            else:
                # Fallback for plain string inputs (e.g. raw text lists in simple tests)
                text = str(line)
                page_num = 1
                font_size = 0.0
                is_bold = False

            cleaned_text = text.strip()
            if not cleaned_text:
                continue

            parsed = self.parse_header(cleaned_text, is_bold, font_size)

            if parsed:
                sec_num, sec_title = parsed
                sec_id = f"{self.doc_name}_{sec_num}"

                # Close the previous section
                if current_section:
                    current_section["full_text"] = "\n".join(current_section["_temp_lines"]).strip()
                    # Delete the temp lines
                    del current_section["_temp_lines"]
                    sections.append(current_section)

                num_parts = self._parse_section_number(sec_num)

                # Determine parent_id by walking up the hierarchy
                parent_id = None
                if len(num_parts) > 1:
                    for i in range(len(num_parts) - 1, 0, -1):
                        parent_candidate = num_parts[:i]
                        if parent_candidate in num_to_id_map:
                            parent_id = num_to_id_map[parent_candidate]
                            break

                # Register current section in the map
                num_to_id_map[num_parts] = sec_id

                current_section = {
                    "id": sec_id,
                    "doc_name": self.doc_name,
                    "title": sec_title,
                    "page_start": page_num,
                    "page_end": page_num,
                    "parent_id": parent_id,
                    "cross_refs": [],  # Filled in by crossref_extractor
                    "tags": [],        # Filled in by heuristic_tagger
                    "_temp_lines": [cleaned_text],  # Keep header in text for completeness
                }
            else:
                # Regular body line
                if current_section:
                    if not self._is_skip_line(cleaned_text):
                        current_section["_temp_lines"].append(cleaned_text)
                    current_section["page_end"] = page_num

        # Close the final section
        if current_section:
            current_section["full_text"] = "\n".join(current_section["_temp_lines"]).strip()
            del current_section["_temp_lines"]
            sections.append(current_section)

        return sections
