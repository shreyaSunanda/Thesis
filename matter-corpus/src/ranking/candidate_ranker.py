"""
Heuristic candidate ranking for prioritizing sections for formal (TLA+) modelling.

Implements the scoring shape validated on the full Matter 1.6 corpus:

    final_score = 0.6 * density_score + 0.4 * raw_score + dependency_bonus

  - raw_score:        total weighted keyword-signal hit count in the section.
  - density_score:    raw_score normalized per 100 words, so a long section
                       doesn't win purely by having more running text.
  - dependency_bonus: small bonus for sections that are frequently referenced
                       elsewhere in the corpus (structurally central sections
                       — requires DependencyGraph.attach_to_sections to have
                       populated 'referenced_by' first).

Sections shorter than MIN_WORD_COUNT are excluded as candidates outright —
too little content to support a meaningful state-machine model.

*** CALIBRATION NOTE ***
The overall formula shape (0.6/0.4 weighting + dependency bonus + min-word
floor + threshold>=20) matches what was described and validated end-to-end
on the full corpus (e.g. producing "5.5 Commissioning Flows", "11.10.7.2
ArmFailSafe Command" etc. as top candidates). The exact keyword list and
per-keyword weights below are a reconstruction from the described signal
categories (state-machine language, transition terms, timer terms,
message-processing behavior) — not the original weight table, which wasn't
shared. Before treating this module's output as canonical, run it over the
same corpus and sanity-check that known-good candidates from the original
run (5.5, 11.10.7.2, 4.19.4.8, 4.12.2.1, 9.15.1.3, etc.) still land in a
similar rank neighborhood. If they don't, swap in the original weights
rather than this reconstruction — the constants matter more than the shape
for cross-run reproducibility.
"""
import re
from typing import List, Dict, Any
from dataclasses import dataclass

MIN_WORD_COUNT = 50
CANDIDATE_SCORE_THRESHOLD = 20.0

DEPENDENCY_BONUS_PER_REFERRER = 0.5
DEPENDENCY_BONUS_CAP = 10.0

# Keyword weight groups: heavier weight = stronger signal of state-machine-relevant
# content. Grouped loosely by the categories described in the ported methodology
# (state-machine language, transitions, timers, message/command processing).
_KEYWORD_WEIGHTS: Dict[str, float] = {
    r'\bstate\s+machine\b': 5.0,
    r'\bstate\s+transition\b': 5.0,
    r'\btransition(?:s|ed|ing)?\b': 3.0,
    r'\bcurrent\s+state\b': 3.0,
    r'\bstate\b': 1.5,
    r'\btimer\b': 3.0,
    r'\btimeout\b': 3.0,
    r'\bexpir\w*\b': 2.5,
    r'\binterval\b': 1.5,
    r'\bduration\b': 1.0,
    r'\bevent\b': 1.5,
    r'\btrigger\b': 2.0,
    r'\bhandler\b': 1.5,
    r'\bcallback\b': 1.5,
    r'\bcommand\b': 1.5,
    r'\binvoke\b': 1.5,
    r'\bexecute\b': 1.0,
    r'\bguard\b': 2.0,
    r'\bshall\b': 1.0,
    r'\bmust\b': 1.0,
    r'\bmessage\b': 1.0,
    r'\bresponse\b': 1.0,
    r'\berror\b': 1.0,
    r'\bfail\w*\b': 1.5,
    # Flow-control / reliable-transport windowing vocabulary — found missing
    # after "Receive Windows" sections (4.19.4.7, 4.20.3.7) scored 6-8 against
    # a threshold of 20, despite being genuine state-machine content (a window
    # that advances on acknowledgment and retries on timeout is exactly the
    # kind of behaviour this ranker is meant to surface — the original keyword
    # list just didn't speak this vocabulary).
    r'\bwindow\b': 2.0,
    r'\bsequence\s+number\b': 2.5,
    r'\backnowledg\w*\b': 2.0,
    r'\bretransmi\w*\b': 2.5,
    r'\bunacknowledged\b': 2.0,
    r'\boutstanding\b': 1.0,
    r'\bflow\s+control\b': 2.0,
    r'\bsegment\b': 1.0,
}
_COMPILED_WEIGHTS = [(re.compile(pat, re.IGNORECASE), w) for pat, w in _KEYWORD_WEIGHTS.items()]


@dataclass
class RankedCandidate:
    id: str
    title: str
    word_count: int
    raw_score: float
    density_score: float
    dependency_bonus: float
    final_score: float


def _word_count(text: str) -> int:
    return len(re.findall(r"\S+", text))


def _raw_score(text: str) -> float:
    score = 0.0
    for pattern, weight in _COMPILED_WEIGHTS:
        hits = len(pattern.findall(text))
        score += hits * weight
    return score


def _density_score(raw_score: float, word_count: int) -> float:
    if word_count == 0:
        return 0.0
    return (raw_score / word_count) * 100.0


def _dependency_bonus(section: Dict[str, Any]) -> float:
    incoming = len(section.get("referenced_by", []))
    return min(incoming * DEPENDENCY_BONUS_PER_REFERRER, DEPENDENCY_BONUS_CAP)


def rank_candidates(
    sections: List[Dict[str, Any]],
    min_word_count: int = MIN_WORD_COUNT,
    threshold: float = CANDIDATE_SCORE_THRESHOLD,
) -> List[RankedCandidate]:
    """
    Scores every section and returns those meeting `threshold`, sorted by
    final_score descending.

    Sections should already have 'referenced_by' populated (via
    DependencyGraph.attach_to_sections) for the dependency bonus to be
    meaningful; sections missing it simply score a 0 bonus rather than
    erroring, so this still runs safely on a corpus that hasn't been through
    the dependency-graph step yet.
    """
    candidates: List[RankedCandidate] = []

    for sec in sections:
        text = sec.get("full_text", "")
        word_count = _word_count(text)
        if word_count < min_word_count:
            continue

        raw = _raw_score(text)
        density = _density_score(raw, word_count)
        dep_bonus = _dependency_bonus(sec)
        final = 0.6 * density + 0.4 * raw + dep_bonus

        if final >= threshold:
            candidates.append(RankedCandidate(
                id=sec["id"],
                title=sec.get("title", ""),
                word_count=word_count,
                raw_score=round(raw, 2),
                density_score=round(density, 2),
                dependency_bonus=round(dep_bonus, 2),
                final_score=round(final, 2),
            ))

    candidates.sort(key=lambda c: c.final_score, reverse=True)
    return candidates
