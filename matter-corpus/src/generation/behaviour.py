"""
Stage 1 of generation: spec context -> structured behavioural JSON.

Prompt and validation are ported from the Colab notebook (cells 46-48,
prompt version "behavior_extraction_v1"); only the hard-coded target was
turned into a parameter. Validation checks, as in the notebook:
  * the reply parses as JSON (Markdown fences tolerated),
  * all eight top-level fields are present,
  * every cited `source_sections` id exists in the corpus (hallucination check),
and re-labels every `unclear_behaviour` item as
"requires_context_verification" / confirmed_underspecification = False
(progress log §16: unclear is not yet underspecified).
"""
import json
import re
from typing import Dict, List

from src.generation.context import bare
from src.generation.llm import LLMClient

PROMPT_VERSION = "behavior_extraction_v1"

REQUIRED_FIELDS = [
    "state_variables", "states", "events", "guards", "transitions",
    "timers_counters", "error_behaviour", "unclear_behaviour",
]


def instruction(target_section: str, target_title: str) -> str:
    return f"""
You are analysing the Matter 1.6 specification for formal protocol modelling.

Target:
Section {target_section}, {target_title}.

Your task is NOT to generate TLA+ yet.

Using only the supplied Matter specification context, extract a structured behavioural model.

Do not invent behavior that is not supported by the specification.

Return valid JSON only with these keys:

{{
  "state_variables": [],
  "states": [],
  "events": [],
  "guards": [],
  "transitions": [],
  "timers_counters": [],
  "error_behaviour": [],
  "unclear_behaviour": []
}}

For every extracted rule, include the supporting Matter section ID.

For each transition, include where possible:
- current_state
- event
- guard
- next_state
- side_effects
- response_or_status
- source_sections

If the specification does not clearly define something, place it under "unclear_behaviour" rather than making an assumption.
"""


def strip_fences(text: str) -> str:
    t = text.strip()
    t = re.sub(r"^```[a-zA-Z+]*\s*", "", t)
    return re.sub(r"\s*```$", "", t)


def _collect_sources(obj, out: List[str]):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "source_sections" and isinstance(v, list):
                out.extend(str(x) for x in v)
            else:
                _collect_sources(v, out)
    elif isinstance(obj, list):
        for x in obj:
            _collect_sources(x, out)


def extract_behaviour(client: LLMClient, context_text: str, target_section: str,
                      target_title: str, corpus_ids: set, max_tokens: int = 8000) -> Dict:
    prompt = instruction(target_section, target_title) + "\n\nSPECIFICATION CONTEXT:\n\n" + context_text
    resp = client.complete(prompt, max_tokens=max_tokens)
    raw = strip_fences(resp.text)
    try:
        model = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"behavioural extraction is not valid JSON: {e}") from e

    missing = [f for f in REQUIRED_FIELDS if f not in model]
    sources: List[str] = []
    _collect_sources(model, sources)
    sources = list(dict.fromkeys(sources))
    valid_bare = {bare(i) for i in corpus_ids}
    invalid = [s for s in sources if bare(s) not in valid_bare]

    for item in model.get("unclear_behaviour", []) or []:
        if isinstance(item, dict):
            item["classification"] = "requires_context_verification"
            item["confirmed_underspecification"] = False

    return {
        "target_section": target_section,
        "target_title": target_title,
        "matter_version": "1.6",
        "requested_model": resp.requested_model,
        "actual_model": resp.actual_model,
        "finish_reason": resp.finish_reason,
        "prompt_version": PROMPT_VERSION,
        "validation": {
            "json_valid": True,
            "missing_required_fields": missing,
            "cited_source_sections": sources,
            "invalid_source_sections": invalid,
        },
        "behavioral_model": model,
    }
