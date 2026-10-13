"""
CLI: generate a TLA+ model for one ranked-candidate unit, via a chosen LLM
provider, then immediately validate it with SANY — automating the exact
manual loop (write .tla -> run SANY -> check output) done by hand earlier.

Usage (free tier, testing the plumbing with no API cost):
    python -m src.generation.generate_tla \\
        --unit-id core_11.10.7.2 \\
        --provider mock --model mock \\
        --corpus-dir data/processed/core \\
        --tla-tools tla2tools.jar

Usage (real generation, once you have a key):
    export OPENROUTER_API_KEY=sk-...
    python -m src.generation.generate_tla \\
        --unit-id core_11.10.7.2 \\
        --provider openrouter --model "nvidia/nemotron-3-super-49b-a12b:free" \\
        --corpus-dir data/processed/core \\
        --tla-tools tla2tools.jar

Swapping providers later is just --provider/--model — nothing else changes.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from src.generation.llm_providers import get_provider, LLMProviderError
from src.generation.prompt_template import build_prompt


def load_corpus(corpus_dir: Path):
    sections = json.load(open(corpus_dir / "sections.json", encoding="utf-8"))
    graph = json.load(open(corpus_dir / "dependency_graph.json", encoding="utf-8"))
    smap = {s["id"]: s for s in sections}
    return smap, graph


def assemble_context(unit_id: str, smap: dict, graph: dict, max_refs: int = 5) -> str:
    """
    1-hop reference closure text for this unit, concatenated (each referenced
    section truncated to keep the prompt a sane size). Capped at max_refs
    sections — revisit this cap if truncation turns out to lose real content
    for a densely cross-referenced unit like commissioning.
    """
    refs = graph.get(unit_id, {}).get("references", [])
    chunks = []
    for ref_id in refs[:max_refs]:
        sec = smap.get(ref_id)
        if sec:
            chunks.append(f"[{ref_id}] {sec['title']}\n{sec['full_text'][:1000]}")
    return "\n\n".join(chunks)


def sanitize_module_name(unit_id: str) -> str:
    """TLA+ module names must be valid identifiers: no dots, no leading digit."""
    name = re.sub(r'[^A-Za-z0-9_]', '_', unit_id)
    if name[0].isdigit():
        name = "M_" + name
    return name


def extract_tla_code(raw_response: str) -> str:
    """Strips a markdown code fence if the model wrapped its output in one."""
    match = re.search(r"```(?:tla\+?|tlaplus)?\s*\n(.*?)```", raw_response, re.DOTALL | re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return raw_response.strip()


def extract_declared_module_name(tla_code: str, fallback: str) -> str:
    """
    TLA+ requires the file name to exactly match the module name declared
    inside it (---- MODULE X ---- means the file must be X.tla). Real LLMs
    don't always follow the requested module name exactly, so rather than
    trust what we ASKED for, this parses what the model actually wrote and
    uses that for the saved filename - avoiding a guaranteed, misleading
    SANY failure that isn't actually about the model's logic at all.
    """
    match = re.search(r'-{2,}\s*MODULE\s+(\w+)\s*-{2,}', tla_code)
    if match:
        return match.group(1)
    return fallback


# Built-in TLA+ keywords/reserved words that are never "declared" but are
# always legal to use as-is. Not exhaustive of every stdlib operator (Len,
# Head, Append, Cardinality, etc.) - just enough to keep the common case
# from generating noisy false positives below.
_TLA_RESERVED_WORDS = {
    "MODULE", "EXTENDS", "CONSTANT", "CONSTANTS", "VARIABLE", "VARIABLES",
    "ASSUME", "ASSUMPTION", "THEOREM", "IF", "THEN", "ELSE", "ELSIF",
    "LET", "IN", "CASE", "OTHER", "UNCHANGED", "EXCEPT", "DOMAIN",
    "SUBSET", "UNION", "ENABLED", "LAMBDA", "TRUE", "FALSE", "BOOLEAN",
    "Naturals", "Integers", "Sequences", "FiniteSets", "TLC", "Nat", "Int",
    "Seq", "Len", "Head", "Tail", "Append", "SubSeq", "Cardinality", "Print",
    "PrintT", "Assert", "LOCAL", "INSTANCE", "WITH",
}


def find_undeclared_identifiers(tla_code: str) -> list:
    """
    Heuristic (regex-based, NOT a real TLA+ parser) scan for identifiers that
    are used in the body but never declared as CONSTANTS/VARIABLES nor
    defined with "Name == ...", "Name(args) == ..." or "LET Name == ...".
    Also treats quantifier/function-domain binders (x \\in S, \\A x \\in S,
    \\E x \\in S, [x \\in S |-> ...]) and operator parameters as declared,
    since those are legitimately locally scoped.

    This exists to catch the common failure mode seen in practice: the model
    references a plausible-sounding name (a helper it never defined, an
    "ambient" attribute/constant it assumed exists) that SANY will reject as
    an "Unknown operator". Running this first gives a single deduplicated,
    readable list instead of wading through dozens of near-duplicate SANY
    error blocks - but it is NOT a substitute for SANY: it can both miss real
    problems (e.g. genuine scoping issues) and flag rare false positives
    (e.g. unusual multi-line declarations this regex doesn't anticipate).
    Treat its output as a fast first pass, not ground truth.
    """
    # Strip comments FIRST. The prompt asks for a "\\* SOURCE: ..." comment above
    # every action quoting the spec text, so without this the scan reports every
    # English word in those quotes - "SHALL", "the", "message", "spec" - and
    # buries the handful of genuinely undeclared names under ~120 false
    # positives, making the whole precheck useless.
    tla_code = re.sub(r"\(\*.*?\*\)", " ", tla_code, flags=re.DOTALL)
    tla_code = re.sub(r"\\\*[^\n]*", " ", tla_code)

    declared = set(_TLA_RESERVED_WORDS)

    # Module's own name is always legal to reference (e.g. in ASSUME/recursion).
    mod_match = re.search(r'-{2,}\s*MODULE\s+(\w+)\s*-{2,}', tla_code)
    if mod_match:
        declared.add(mod_match.group(1))

    # CONSTANTS / VARIABLES blocks (one or more lines, comma-separated names,
    # possibly split across several CONSTANTS/VARIABLES statements).
    for block_match in re.finditer(
        r'^(?:CONSTANTS?|VARIABLES?)\s+(.+(?:\n\s+,.*)*)', tla_code, re.MULTILINE
    ):
        names_text = re.split(r'\\\*', block_match.group(1))[0]  # drop trailing comment
        for name in re.findall(r'[A-Za-z_]\w*', names_text):
            declared.add(name)

    # Top-level operator definitions: "Name == ..." or "Name(a, b, ...) == ...",
    # including LET-bound definitions. Captures both the operator name and any
    # parameter names (parameters are locally scoped but we don't track scope
    # precisely, so we add them globally - safe direction: fewer false positives).
    for def_match in re.finditer(r'^\s*(?:LET\s+)?([A-Za-z_]\w*)\s*(\(([^)]*)\))?\s*==', tla_code, re.MULTILINE):
        declared.add(def_match.group(1))
        if def_match.group(3):
            for param in re.findall(r'[A-Za-z_]\w*', def_match.group(3)):
                declared.add(param)

    # Any "name \in ..." binds `name` as a local variable: quantifiers
    # (\A x \in S, \E x \in S), set-builder/function-domain constructs
    # ({x \in S : P(x)}, [x \in S |-> ...]).
    for bind_match in re.finditer(r'([A-Za-z_]\w*)\s*\\in', tla_code):
        declared.add(bind_match.group(1))

    # Mask out string literal contents (e.g. "BusyWithOtherAdmin") so words
    # inside them aren't mistaken for operator references - they're just
    # data values, not names needing declaration.
    scan_text = re.sub(r'"[^"]*"', lambda m: '"' + (' ' * (len(m.group(0)) - 2)) + '"', tla_code)

    # Now scan for identifier uses and flag anything not in `declared`.
    # Skip: record/EXCEPT field access (".Field" or "!.Field" - field names,
    # not operator references) and backslash-prefixed TLA+ tokens (\A, \E,
    # \in, \notin, \cup, etc. - the backslash isn't a word char, so without
    # this exclusion "\E" and "\in" would wrongly surface as bare "E"/"in").
    undeclared = set()
    for use_match in re.finditer(r'(?<![.\w!\\])([A-Za-z_]\w*)', scan_text):
        name = use_match.group(1)
        start = use_match.start()
        preceding = scan_text[max(0, start - 2):start]
        if preceding.endswith('.') or preceding.endswith('!'):
            continue
        if name in declared:
            continue
        undeclared.add(name)

    return sorted(undeclared)


def run_sany(tla_path: Path, tla_tools_jar: Path) -> dict:
    """Runs SANY on the generated file and reports pass/fail with raw output."""
    # Resolve to an absolute path BEFORE changing the subprocess's working
    # directory below - otherwise a relative --tla-tools path (the normal
    # way someone would pass it) silently stops resolving once cwd changes
    # to the output folder, and Java fails with a confusing
    # "ClassNotFoundException: tla2sany.SANY" that looks like a missing/
    # corrupt jar rather than what it actually is: a broken relative path.
    tla_tools_jar = Path(tla_tools_jar).resolve()
    if not tla_tools_jar.exists():
        return {"passed": False, "error": f"tla2tools.jar not found at resolved path: {tla_tools_jar}"}

    try:
        result = subprocess.run(
            ["java", "-cp", str(tla_tools_jar), "tla2sany.SANY", tla_path.name],
            cwd=str(tla_path.parent),
            capture_output=True,
            text=True,
            timeout=60,
        )
    except FileNotFoundError:
        return {"passed": False, "error": "java not found - is a JRE installed and on PATH?"}
    except subprocess.TimeoutExpired:
        return {"passed": False, "error": "SANY timed out after 60s"}

    combined = result.stdout + result.stderr
    passed = result.returncode == 0 and "error" not in combined.lower()
    return {"passed": passed, "returncode": result.returncode, "output": combined}


def generate_for_unit(
    unit_id: str,
    provider_name: str,
    model: str,
    corpus_dir: str,
    out_dir: str,
    tla_tools_jar: str = None,
    api_key: str = None,
) -> dict:
    corpus_path = Path(corpus_dir)
    smap, graph = load_corpus(corpus_path)

    if unit_id not in smap:
        raise ValueError(f"Unit '{unit_id}' not found in {corpus_path / 'sections.json'}")

    unit = smap[unit_id]
    context_text = assemble_context(unit_id, smap, graph)
    module_name = sanitize_module_name(unit_id)

    prompt = build_prompt(
        unit_id=unit_id,
        unit_title=unit.get("title", ""),
        unit_text=unit.get("full_text", ""),
        context_text=context_text,
        module_name=module_name,
    )

    provider = get_provider(provider_name, model=model, api_key=api_key)
    print(f"[generate] provider={provider_name} model={model} unit={unit_id}")
    try:
        raw_response = provider.generate(prompt)
    except LLMProviderError as e:
        print(f"[generate] FAILED: {e}", file=sys.stderr)
        return {"unit_id": unit_id, "provider": provider_name, "generated": False, "error": str(e)}

    tla_code = extract_tla_code(raw_response)
    declared_module_name = extract_declared_module_name(tla_code, fallback=module_name)

    out_path = Path(out_dir) / provider_name
    out_path.mkdir(parents=True, exist_ok=True)
    tla_file = out_path / f"{declared_module_name}.tla"
    tla_file.write_text(tla_code, encoding="utf-8")
    print(f"[generate] wrote {tla_file}")
    if declared_module_name != module_name:
        print(f"[generate] note: model declared module name '{declared_module_name}', "
              f"not the requested '{module_name}' - saved under the name it actually used.")

    result = {
        "unit_id": unit_id, "provider": provider_name, "model": model,
        "generated": True, "tla_path": str(tla_file),
    }

    suspect_names = find_undeclared_identifiers(tla_code)
    result["precheck_undeclared"] = suspect_names
    if suspect_names:
        print(f"[precheck] {len(suspect_names)} possibly-undeclared identifier(s) "
              f"(heuristic, not a substitute for SANY): {', '.join(suspect_names)}")
    else:
        print("[precheck] no obviously undeclared identifiers found")

    if tla_tools_jar:
        print(f"[validate] running SANY on {tla_file.name} ...")
        sany_result = run_sany(tla_file, Path(tla_tools_jar))
        result["sany"] = sany_result
        print(f"[validate] SANY: {'PASS' if sany_result['passed'] else 'FAIL'}")
        if not sany_result["passed"]:
            print(sany_result.get("output", sany_result.get("error", "")))
    else:
        print("[validate] skipped (no --tla-tools path given)")

    return result


def main():
    parser = argparse.ArgumentParser(description="Generate a TLA+ model for one unit, then validate it with SANY.")
    parser.add_argument("--unit-id", required=True, help="Section id from sections.json, e.g. core_11.10.7.2")
    parser.add_argument("--provider", required=True, choices=["mock", "vertex", "vertex-gemini", "anthropic", "openai", "openrouter", "google"])
    parser.add_argument("--model", required=True,
                         help="Model id for the chosen provider, e.g. 'mock', 'claude-sonnet-4-6', "
                              "'gpt-4o', 'nvidia/nemotron-3-super-49b-a12b:free', 'gemini-1.5-pro'.")
    parser.add_argument("--corpus-dir", default="data/processed/core")
    parser.add_argument("--out-dir", default="models/generated")
    parser.add_argument("--tla-tools", default=None,
                         help="Path to tla2tools.jar. If given, SANY runs automatically right after generation.")
    parser.add_argument("--api-key", default=None,
                         help="API key, or leave unset and export <PROVIDER>_API_KEY instead "
                              "(e.g. OPENROUTER_API_KEY, ANTHROPIC_API_KEY).")
    args = parser.parse_args()

    api_key = args.api_key or os.environ.get(f"{args.provider.upper()}_API_KEY")

    result = generate_for_unit(
        unit_id=args.unit_id,
        provider_name=args.provider,
        model=args.model,
        corpus_dir=args.corpus_dir,
        out_dir=args.out_dir,
        tla_tools_jar=args.tla_tools,
        api_key=api_key,
    )

    if not result.get("generated"):
        sys.exit(1)


if __name__ == "__main__":
    main()