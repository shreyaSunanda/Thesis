"""
Stage 2 of generation: behavioural JSON -> TLA+ module (+ TLC config).

The module prompt is the notebook's "tla_code_v2" (cell 58) with the
hard-coded target turned into parameters; it is the prompt that produced
the first complete ArmFailSafe module (progress log §29). As in the
notebook, the generated module is *not* hand-corrected before the tool
check: SANY/TLC results measure the LLM output as-is.

The TLC config is NEW (prompt version "tlc_cfg_v1"): the notebook stopped
before TLC, so it never needed one. Constants need concrete small values
for TLC, which only someone reading the module can choose, so the same LLM
is asked in a second, separate call; the result is checked to assign every
declared CONSTANT. Unlike the module, nothing here is a research artifact
-- it is plumbing, and a hand-written .cfg next to the module always wins.
"""
import re
from typing import Dict, List

from src.generation.behaviour import strip_fences
from src.generation.llm import LLMClient
from src.tla.cfg import parse_cfg

TLA_PROMPT_VERSION = "tla_code_v2"
CFG_PROMPT_VERSION = "tlc_cfg_v1"


def module_name_for(title: str) -> str:
    """'ArmFailSafe Command' -> 'ArmFailSafeCommand' (a valid TLA+ module / file name)."""
    words = re.findall(r"[A-Za-z0-9]+", title)
    name = "".join(w[:1].upper() + w[1:] for w in words) or "Model"
    return name if name[0].isalpha() else f"M{name}"


def tla_instruction(module_name: str, target_section: str, target_title: str) -> str:
    return f"""
You are a formal-methods engineer.

Generate a complete TLA+ specification for the structured behavioural
model supplied below.

Target:
Matter 1.6 Section {target_section}
{target_title}

STRICT RULES:

1. Use ONLY information present in the supplied behavioural JSON.
2. Do NOT invent unspecified Matter behaviour.
3. Do NOT resolve unclear behaviour by assumption.
4. Do NOT add Undefined or Contradictory states yet.
5. Preserve relevant Matter section IDs as TLA+ comments.
6. Use finite abstractions suitable for TLC model checking.
7. Represent timers abstractly rather than modelling real wall-clock time.
8. Include:
   - module declaration
   - EXTENDS
   - VARIABLES
   - vars tuple
   - Init
   - transition/action operators
   - Next
   - TypeInvariant
   - Spec
9. Every state variable in an action must either receive a primed value
   or appear in UNCHANGED.
10. The result must be syntactically valid TLA+.

OUTPUT RULE:

Return ONLY the complete TLA+ source code.

Start exactly with:

---- MODULE {module_name} ----

End exactly with:

====

Do not output JSON.
Do not output Markdown fences.
Do not explain your reasoning.
Do not include prose before or after the TLA+ module.
"""


CFG_INSTRUCTION = """
You are a formal-methods engineer preparing a TLC model-checking configuration.

Write the TLC .cfg file for the TLA+ module below:

1. Use: SPECIFICATION Spec
2. Assign EVERY constant declared in the module's CONSTANT(S) section a
   small, finite value suitable for exhaustive model checking (for example
   2 or 3 for numeric bounds, small sets for set-valued constants, and model
   values written as `C = C` for opaque identifiers).
3. If the module defines TypeInvariant, add: INVARIANT TypeInvariant
4. Add no other invariants, properties or constraints.

Return ONLY the .cfg contents. No Markdown fences, no prose.
"""


def clean_module(text: str, module_name: str) -> Dict:
    """Strip fences/prose around the module and force the header to match the
    file name (SANY requires it). Every change is recorded, never silent."""
    notes: List[str] = []
    t = strip_fences(text)
    start = re.search(r"-{4,}\s*MODULE\s+(\w+)\s*-{4,}", t)
    if not start:
        raise ValueError("generated text contains no `---- MODULE ... ----` header")
    if start.start() > 0:
        notes.append("removed text before the module header")
        t = t[start.start():]
        start = re.search(r"-{4,}\s*MODULE\s+(\w+)\s*-{4,}", t)
    if start.group(1) != module_name:
        notes.append(f"renamed module {start.group(1)} -> {module_name} to match the file name")
        t = t[:start.start(1)] + module_name + t[start.end(1):]
    end = re.search(r"^={4,}\s*$", t, flags=re.M)
    if end:
        if t[end.end():].strip():
            notes.append("removed text after the closing ====")
        t = t[:end.end()]
    else:
        notes.append("added missing closing ====")
        t = t.rstrip() + "\n===="
    if "\t" in t:
        notes.append("expanded tab characters to spaces")
        t = t.expandtabs(4)
    return {"text": t.rstrip() + "\n", "notes": notes}


def generate_tla(client: LLMClient, behavioural_model: dict, module_name: str,
                 target_section: str, target_title: str, max_tokens: int = 5000) -> Dict:
    import json
    prompt = (tla_instruction(module_name, target_section, target_title)
              + "\n\nSTRUCTURED BEHAVIOURAL MODEL:\n\n"
              + json.dumps(behavioural_model, ensure_ascii=False, indent=2))
    resp = client.complete(prompt, max_tokens=max_tokens)
    cleaned = clean_module(resp.text, module_name)
    return {
        "module_name": module_name,
        "tla": cleaned["text"],
        "cleanup_notes": cleaned["notes"],
        "raw_response": resp.text,
        "requested_model": resp.requested_model,
        "actual_model": resp.actual_model,
        "finish_reason": resp.finish_reason,
        "prompt_version": TLA_PROMPT_VERSION,
    }


def generate_cfg(client: LLMClient, tla_text: str, declared_constants: List[str],
                 max_tokens: int = 800) -> Dict:
    resp = client.complete(CFG_INSTRUCTION + "\n\nTLA+ MODULE:\n\n" + tla_text, max_tokens=max_tokens)
    text = strip_fences(resp.text).strip() + "\n"
    cfg = parse_cfg(text)
    assigned = set(re.findall(r"^\s*([A-Za-z_]\w*)\s*(?:=|<-)", cfg.constants_text, flags=re.M))
    missing = [c for c in declared_constants if c not in assigned]
    return {
        "cfg": text,
        "missing_constants": missing,
        "requested_model": resp.requested_model,
        "actual_model": resp.actual_model,
        "prompt_version": CFG_PROMPT_VERSION,
    }
