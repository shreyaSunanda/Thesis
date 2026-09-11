import re
from typing import List, Dict, Any, Set

class HeuristicTagger:
    """
    Applies keyword/regex-based heuristic tags to sections.
    Designed to identify state-based sections, timers, events, and other
    patterns relevant to formal modeling of the Matter specification.
    """
    
    def __init__(self):
        # Define tag patterns: tag_name -> list of regex patterns
        self.tag_patterns = {
            "state": [
                r'\bstate\b',
                r'\bstate\s+machine\b',
                r'\bstate\s+transition\b',
                r'\bcurrent\s+state\b',
                r'\bstate\s+variable\b',
            ],
            "timer": [
                r'\btimer\b',
                r'\btimeout\b',
                r'\btime\s+out\b',
                r'\bdelay\b',
                r'\binterval\b',
                r'\bduration\b',
                r'\bexpir\w*\b',
            ],
            "event": [
                r'\bevent\b',
                r'\btrigger\b',
                r'\bcallback\b',
                r'\bnotification\b',
                r'\bindication\b',
                r'\bhandler\b',
            ],
            "command": [
                r'\bcommand\b',
                r'\bcommand\s+handler\b',
                r'\binvoke\b',
                r'\bexecute\b',
            ],
            "attribute": [
                r'\battribute\b',
                r'\battribute\s+value\b',
                r'\battribute\s+report\b',
                r'\battribute\s+write\b',
                r'\battribute\s+read\b',
            ],
            "commissioning": [
                r'\bcommission\w*\b',
                r'\bpairing\b',
                r'\bonboarding\b',
                r'\bsetup\s+code\b',
                r'\bqr\s+code\b',
                r'\bpasscode\b',
            ],
            "security": [
                r'\bsecurity\b',
                r'\bencrypt\w*\b',
                r'\bdecrypt\w*\b',
                r'\bauthenticat\w*\b',
                r'\bcertificat\w*\b',
                r'\bkey\b',
                r'\bsign\w*\b',
                r'\bverify\w*\b',
            ],
            "network": [
                r'\bnetwork\b',
                r'\bmesh\b',
                r'\brout\w*\b',
                r'\bendpoint\b',
                r'\bnode\b',
                r'\bdevice\b',
                r'\bcluster\b',
            ],
            "matter": [
                r'\bmatter\b',
                r'\bcore\s+specification\b',
                r'\bapplication\s+cluster\b',
                r'\bspecification\b',
            ],
        }
        
        # Compile all patterns for efficiency
        self.compiled_patterns: Dict[str, List[re.Pattern]] = {}
        for tag, patterns in self.tag_patterns.items():
            self.compiled_patterns[tag] = [re.compile(p, re.IGNORECASE) for p in patterns]
    
    def tag_section(self, section: Dict[str, Any]) -> List[str]:
        """
        Apply heuristic tags to a single section based on its title and full_text.
        Returns a list of tag strings.
        """
        text_to_search = f"{section.get('title', '')} {section.get('full_text', '')}"
        tags: Set[str] = set()
        
        for tag, patterns in self.compiled_patterns.items():
            for pattern in patterns:
                if pattern.search(text_to_search):
                    tags.add(tag)
                    break  # One match per tag is enough
        
        return sorted(tags)
    
    def tag_sections(self, sections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Apply heuristic tags to a list of sections.
        Modifies sections in-place by adding/updating the 'tags' field.
        Returns the modified list for chaining.
        """
        for section in sections:
            section['tags'] = self.tag_section(section)
        return sections
    
    def add_custom_pattern(self, tag: str, pattern: str) -> None:
        """
        Add a custom regex pattern for an existing or new tag.
        """
        if tag not in self.compiled_patterns:
            self.compiled_patterns[tag] = []
            self.tag_patterns[tag] = []
        
        self.tag_patterns[tag].append(pattern)
        self.compiled_patterns[tag].append(re.compile(pattern, re.IGNORECASE))
    
    def get_available_tags(self) -> List[str]:
        """Return list of all available tag names."""
        return sorted(self.compiled_patterns.keys())


def tag_sections(sections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Convenience function to tag sections using default HeuristicTagger.
    """
    tagger = HeuristicTagger()
    return tagger.tag_sections(sections)