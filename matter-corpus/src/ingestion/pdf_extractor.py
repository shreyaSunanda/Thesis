# import fitz  # PyMuPDF
# from typing import List, Dict, Any, Tuple
# from dataclasses import dataclass, asdict

# @dataclass
# class RichLine:
#     text: str
#     page_num: int  # 1-based index
#     font_name: str
#     font_size: float
#     is_bold: bool
#     bbox: Tuple[float, float, float, float]  # (x0, y0, x1, y1)

# class PDFExtractor:
#     """
#     Layout-aware PDF Extractor that preserves font sizes, positions,
#     and styling (boldness) to enable reliable section header detection.
#     """
#     def __init__(self, pdf_path: str):
#         self.pdf_path = pdf_path

#     def extract_rich_lines(self) -> List[RichLine]:
#         """
#         Extracts all text lines from the PDF, preserving their metadata
#         such as page number, font name, font size, boldness, and bounding box.
#         """
#         rich_lines: List[RichLine] = []
#         doc = fitz.open(self.pdf_path)
        
#         for page_idx in range(len(doc)):
#             page_num = page_idx + 1
#             page = doc[page_idx]
            
#             # Use page.get_text("dict") to get structural font and layout info
#             page_dict = page.get_text("dict")
            
#             for block in page_dict.get("blocks", []):
#                 # We only care about text blocks (type 0)
#                 if block.get("type") != 0:
#                     continue
                
#                 for line in block.get("lines", []):
#                     line_text = ""
#                     font_sizes = []
#                     font_names = []
#                     bold_flags = []
                    
#                     # Compute line bounding box
#                     lx0, ly0, lx1, ly1 = line.get("bbox", (0.0, 0.0, 0.0, 0.0))
                    
#                     for span in line.get("spans", []):
#                         span_text = span.get("text", "")
#                         line_text += span_text
                        
#                         # Store font size and name for determining the dominant styles
#                         font_sizes.append(span.get("size", 10.0))
#                         font_names.append(span.get("font", ""))
                        
#                         # Check flags for bold (usually bit 4 of flags is bold, or name contains Bold)
#                         flags = span.get("flags", 0)
#                         is_bold_flag = bool(flags & 2**4)
#                         font_name_lower = span.get("font", "").lower()
#                         is_bold_name = "bold" in font_name_lower or "black" in font_name_lower or "heavy" in font_name_lower
#                         bold_flags.append(is_bold_flag or is_bold_name)
                    
#                     # Clean the line text
#                     cleaned_text = line_text.strip()
#                     if not cleaned_text:
#                         continue
                    
#                     # Determine dominant font size, font name, and boldness for the line
#                     dominant_font_size = max(font_sizes) if font_sizes else 10.0
#                     dominant_font_name = font_names[0] if font_names else ""
#                     # If any part of the line is bold, or we classify it as bold, treat the line as bold
#                     is_bold = any(bold_flags) if bold_flags else False
                    
#                     rich_lines.append(RichLine(
#                         text=cleaned_text,
#                         page_num=page_num,
#                         font_name=dominant_font_name,
#                         font_size=dominant_font_size,
#                         is_bold=is_bold,
#                         bbox=(lx0, ly0, lx1, ly1)
#                     ))
                    
#         doc.close()
#         return rich_lines

#     def to_dict_list(self, rich_lines: List[RichLine]) -> List[Dict[str, Any]]:
#         """Utility to serialize rich lines to a JSON-compatible format."""
#         return [asdict(rl) for rl in rich_lines]




import fitz  # PyMuPDF
from typing import List, Dict, Any, Tuple
from dataclasses import dataclass, asdict

SOFT_HYPHEN = "\u00ad"


@dataclass
class RichLine:
    text: str
    page_num: int  # 1-based index
    font_name: str
    font_size: float
    is_bold: bool
    bbox: Tuple[float, float, float, float]  # (x0, y0, x1, y1)


class PDFExtractor:
    """
    Layout-aware PDF Extractor that preserves font sizes, positions,
    and styling (boldness) to enable reliable section header detection.
    """
    def __init__(self, pdf_path: str):
        self.pdf_path = pdf_path

    def extract_rich_lines(self) -> List[RichLine]:
        """
        Extracts all text lines from the PDF, preserving their metadata
        such as page number, font name, font size, boldness, and bounding box.

        Soft-hyphen artifacts (U+00AD, inserted by PDF producers at optional
        hyphenation points) are cleaned up as a final pass — see
        _merge_soft_hyphenated_lines for why this matters and what it does.
        """
        rich_lines: List[RichLine] = []
        doc = fitz.open(self.pdf_path)
        
        for page_idx in range(len(doc)):
            page_num = page_idx + 1
            page = doc[page_idx]
            
            # Use page.get_text("dict") to get structural font and layout info
            page_dict = page.get_text("dict")
            
            for block in page_dict.get("blocks", []):
                # We only care about text blocks (type 0)
                if block.get("type") != 0:
                    continue
                
                for line in block.get("lines", []):
                    line_text = ""
                    font_sizes = []
                    font_names = []
                    bold_flags = []
                    
                    # Compute line bounding box
                    lx0, ly0, lx1, ly1 = line.get("bbox", (0.0, 0.0, 0.0, 0.0))
                    
                    for span in line.get("spans", []):
                        span_text = span.get("text", "")
                        line_text += span_text
                        
                        # Store font size and name for determining the dominant styles
                        font_sizes.append(span.get("size", 10.0))
                        font_names.append(span.get("font", ""))
                        
                        # Check flags for bold (usually bit 4 of flags is bold, or name contains Bold)
                        flags = span.get("flags", 0)
                        is_bold_flag = bool(flags & 2**4)
                        font_name_lower = span.get("font", "").lower()
                        is_bold_name = "bold" in font_name_lower or "black" in font_name_lower or "heavy" in font_name_lower
                        bold_flags.append(is_bold_flag or is_bold_name)
                    
                    # Clean the line text
                    cleaned_text = line_text.strip()
                    if not cleaned_text:
                        continue
                    
                    # Determine dominant font size, font name, and boldness for the line
                    dominant_font_size = max(font_sizes) if font_sizes else 10.0
                    dominant_font_name = font_names[0] if font_names else ""
                    # If any part of the line is bold, or we classify it as bold, treat the line as bold
                    is_bold = any(bold_flags) if bold_flags else False
                    
                    rich_lines.append(RichLine(
                        text=cleaned_text,
                        page_num=page_num,
                        font_name=dominant_font_name,
                        font_size=dominant_font_size,
                        is_bold=is_bold,
                        bbox=(lx0, ly0, lx1, ly1)
                    ))
                    
        doc.close()
        return self._merge_soft_hyphenated_lines(rich_lines)

    @staticmethod
    def _merge_soft_hyphenated_lines(rich_lines: List[RichLine]) -> List[RichLine]:
        """
        Cleans up soft-hyphen (U+00AD) artifacts.

        Matter's spec PDFs contain soft hyphens at optional hyphenation points.
        Two cases show up in practice:

          1. A soft hyphen sitting mid-word within a single extracted line
             (the hyphenation point existed but the line didn't actually
             wrap there) — these are just stripped.
          2. A soft hyphen at the very end of one extracted line, where the
             word genuinely was broken across the page's line width and
             continues at the start of the next line (e.g. "commis\u00ad" /
             "sioning") — these two lines are merged into one word, with the
             hyphen removed, so downstream header/keyword regexes don't see
             a corrupted word ("commis" and "sioning" as two unrelated
             tokens) on either side of the break.

        Ported from an equivalent fix validated on the full Matter 1.6 corpus,
        adapted here to operate over RichLine objects instead of flat text
        (this extractor tracks per-line layout metadata, so line-end soft
        hyphens are detected structurally rather than via a page-marker /
        newline text pattern).

        Note: merging across a physical page boundary (rare, but possible for
        a word broken right at the bottom of a page) keeps the first line's
        page_num/font metadata and drops the second line's own entry.
        """
        merged: List[RichLine] = []
        i = 0
        n = len(rich_lines)
        while i < n:
            line = rich_lines[i]
            text = line.text

            if text.endswith(SOFT_HYPHEN) and i + 1 < n:
                next_line = rich_lines[i + 1]
                joined_text = text[:-len(SOFT_HYPHEN)] + next_line.text.lstrip()
                merged.append(RichLine(
                    text=joined_text,
                    page_num=line.page_num,
                    font_name=line.font_name,
                    font_size=line.font_size,
                    is_bold=line.is_bold,
                    bbox=line.bbox,
                ))
                i += 2
                continue

            if SOFT_HYPHEN in text:
                line = RichLine(
                    text=text.replace(SOFT_HYPHEN, ""),
                    page_num=line.page_num,
                    font_name=line.font_name,
                    font_size=line.font_size,
                    is_bold=line.is_bold,
                    bbox=line.bbox,
                )

            merged.append(line)
            i += 1

        return merged

    def to_dict_list(self, rich_lines: List[RichLine]) -> List[Dict[str, Any]]:
        """Utility to serialize rich lines to a JSON-compatible format."""
        return [asdict(rl) for rl in rich_lines]
