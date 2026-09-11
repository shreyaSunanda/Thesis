"""
Builds a bidirectional dependency graph over parsed Matter spec sections.

CrossRefExtractor gives each section a one-directional 'cross_refs' list —
what that section points *at*. That's not enough on its own: to study a
section "in relation to other sections that define or depend on it" (e.g.
when assembling LLM context, or when deciding which sections are
structurally central for candidate ranking), you also need the reverse edge
— what points *at* this section. This module builds both directions and
lets you compute multi-hop closures in either direction.

Ported over after a thesis-collaborator's independent implementation
(matter_dependency_graph_v3.json) demonstrated the reverse index was needed
for both context assembly and candidate ranking.
"""
from typing import List, Dict, Any, Set
from collections import defaultdict


class DependencyGraph:
    def __init__(self):
        self.references: Dict[str, Set[str]] = defaultdict(set)
        self.referenced_by: Dict[str, Set[str]] = defaultdict(set)

    def build(self, sections: List[Dict[str, Any]]) -> "DependencyGraph":
        """
        Populates the graph from a list of section dicts (as produced by
        SectionSplitter + CrossRefExtractor). Only resolved, in-corpus
        references become edges — unresolved refs (external specs, e.g.
        Thread) and self-references are skipped.
        """
        known_ids = {s["id"] for s in sections}

        for sec in sections:
            sec_id = sec["id"]
            for ref in sec.get("cross_refs", []):
                resolved = ref.get("resolved")
                if not resolved or resolved not in known_ids:
                    continue
                if resolved == sec_id:
                    # Defensive: a section citing itself (e.g. "see Section 4.13.3.1"
                    # appearing inside 4.13.3.1 itself) shouldn't create a self-loop.
                    continue
                self.references[sec_id].add(resolved)
                self.referenced_by[resolved].add(sec_id)

        return self

    def closure(
        self,
        unit_id: str,
        max_hops: int = 1,
        direction: str = "references",
    ) -> Set[str]:
        """
        BFS closure of a unit's dependencies (direction="references") or
        dependents (direction="referenced_by"), up to max_hops. Does not
        include unit_id itself.

        This is the building block for automated context assembly (Phase 1
        item: "context selection should eventually be automated or governed
        by a clearly defined reproducible selection rule" — a fixed max_hops
        cutoff is exactly that rule, made explicit and reproducible instead
        of a manual per-unit judgment call).
        """
        if direction not in ("references", "referenced_by"):
            raise ValueError("direction must be 'references' or 'referenced_by'")

        edges = self.references if direction == "references" else self.referenced_by
        frontier = {unit_id}
        visited: Set[str] = set()

        for _ in range(max_hops):
            next_frontier: Set[str] = set()
            for node in frontier:
                next_frontier |= edges.get(node, set())
            next_frontier -= visited
            next_frontier.discard(unit_id)
            if not next_frontier:
                break
            visited |= next_frontier
            frontier = next_frontier

        return visited

    def to_dict(self) -> Dict[str, Dict[str, List[str]]]:
        """Serializes the graph to a plain dict, sorted for reproducible diffs."""
        all_ids = set(self.references.keys()) | set(self.referenced_by.keys())
        return {
            uid: {
                "references": sorted(self.references.get(uid, set())),
                "referenced_by": sorted(self.referenced_by.get(uid, set())),
            }
            for uid in sorted(all_ids)
        }

    @staticmethod
    def attach_to_sections(
        sections: List[Dict[str, Any]], graph: "DependencyGraph"
    ) -> List[Dict[str, Any]]:
        """
        Writes 'references' and 'referenced_by' id lists directly onto each
        section dict in-place, and returns the list for chaining. Sections
        with no edges in either direction get empty lists rather than being
        left unset, so downstream code (e.g. candidate_ranker) can rely on
        the keys always being present.
        """
        graph_dict = graph.to_dict()
        for sec in sections:
            entry = graph_dict.get(sec["id"], {"references": [], "referenced_by": []})
            sec["references"] = entry["references"]
            sec["referenced_by"] = entry["referenced_by"]
        return sections


def build_dependency_graph(sections: List[Dict[str, Any]]) -> DependencyGraph:
    """Convenience wrapper: build() + return, for one-line pipeline use."""
    return DependencyGraph().build(sections)
