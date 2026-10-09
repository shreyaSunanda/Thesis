"""
End-to-end pipeline: Matter spec -> TLA+ -> SANY -> TLC (-> decomposition).

    [corpus]      src.build_corpus            PDF -> sections / dependency graph / ranking
    [context]     src.generation.context      target + parent + one-hop refs (+ chosen 2nd hop)
    [behaviour]   src.generation.behaviour    LLM -> structured behavioural JSON, validated
    [tla]         src.generation.tla_generation  LLM -> TLA+ module (+ TLC config)
    [verify]      src.verify                  SANY -> TLC under a budget -> automatic
                                              decomposition if the state space explodes

The generation stages are the Colab notebook's cells (same prompts, same
OpenRouter configuration), parameterised by section instead of hard-coded
to ArmFailSafe and chained without manual upload/download between cells.

Usage:
    export OPENROUTER_API_KEY=...
    # one section (the notebook's pilot, with its hand-picked second hop)
    python -m src.run_pipeline --sections core_11.10.7.2 \\
        --second-hop 4.11.1.1 11.18.6.5 11.18.4.9
    # the top-N ranked candidates
    python -m src.run_pipeline --top 5
    # rebuild the corpus from the PDF first
    python -m src.run_pipeline --pdf data/raw_pdfs/Matter-1.6-Core-Specification.pdf \\
        --content-start-page 39 --top 5
    # no LLM: re-verify every existing model (hand-written or generated) under tla_models/
    python -m src.run_pipeline --verify-only

Per-section artifacts go to tla_models/generated/<section_id>/: context.*,
behaviour.json, <Module>.tla/.cfg, provenance.json and verification/.
A stage whose output already exists is reused unless --regenerate is given,
so an expensive LLM call is never repeated by accident; a hand-edited .cfg
next to a generated module is always kept.
"""
import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

from src.generation.behaviour import extract_behaviour
from src.generation.context import build_context, load_sections, save_context
from src.generation.llm import LLMClient, LLMError, OpenRouterClient
from src.generation.tla_generation import generate_cfg, generate_tla, module_name_for
from src.tla.sany_ast import SanyError, load_model
from src.tla.tools import run_sany
from src.verify import DEFAULT_MAX_STATES, DEFAULT_TIMEOUT, verify_model

REPO = Path(__file__).resolve().parents[1]
GENERATED_DIR = REPO / "tla_models" / "generated"


def run_section(section_id: str, sections: dict, client: Optional[LLMClient], *,
                second_hop: Optional[List[str]] = None, out_root: Path = GENERATED_DIR,
                regenerate: bool = False, verify_kwargs: Optional[dict] = None) -> dict:
    out = out_root / section_id
    out.mkdir(parents=True, exist_ok=True)
    prov_path = out / "provenance.json"
    prov = json.loads(prov_path.read_text()) if prov_path.exists() and not regenerate else {}
    prov.setdefault("section_id", section_id)
    prov.setdefault("stages", {})

    def stamp(stage: str, **info):
        prov["stages"][stage] = {"at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                                 **info}
        prov_path.write_text(json.dumps(prov, indent=2), encoding="utf-8")

    summary = {"section": section_id, "module": None, "outcome": None, "findings": None,
               "decomposed": False, "error": None}

    # [context]
    bundle = build_context(sections, section_id, second_hop)
    ctx_path = save_context(bundle, out)
    stamp("context", sections=bundle["context_section_ids"],
          words=len(ctx_path.read_text(encoding="utf-8").split()))
    title = bundle["target_title"]
    module = module_name_for(title)
    summary["module"] = module

    # [behaviour]
    beh_path = out / "behaviour.json"
    if regenerate or not beh_path.exists():
        if client is None:
            summary["error"] = "no LLM client (OPENROUTER_API_KEY unset?) and no cached behaviour.json"
            return summary
        print(f"[{section_id}] behavioural extraction ...")
        rec = extract_behaviour(client, ctx_path.read_text(encoding="utf-8"),
                                bundle["target_section"], title, set(sections))
        beh_path.write_text(json.dumps(rec, indent=2, ensure_ascii=False), encoding="utf-8")
        stamp("behaviour", requested_model=rec["requested_model"],
              actual_model=rec["actual_model"], prompt_version=rec["prompt_version"],
              validation=rec["validation"])
    behaviour = json.loads(beh_path.read_text(encoding="utf-8"))

    # [tla]
    tla_path, cfg_path = out / f"{module}.tla", out / f"{module}.cfg"
    if regenerate or not tla_path.exists():
        if client is None:
            summary["error"] = f"no LLM client and no cached {tla_path.name}"
            return summary
        print(f"[{section_id}] TLA+ generation ...")
        gen = generate_tla(client, behaviour["behavioral_model"], module,
                           bundle["target_section"], title)
        tla_path.write_text(gen["tla"], encoding="utf-8")
        (out / f"{module}.raw_response.txt").write_text(gen["raw_response"], encoding="utf-8")
        stamp("tla", requested_model=gen["requested_model"], actual_model=gen["actual_model"],
              finish_reason=gen["finish_reason"], prompt_version=gen["prompt_version"],
              cleanup_notes=gen["cleanup_notes"])

    if not cfg_path.exists():
        sany = run_sany(tla_path)
        if sany.ok and client is not None:
            try:
                consts = sorted(load_model(tla_path).constants.values())
            except SanyError:
                consts = []
            print(f"[{section_id}] TLC config generation ...")
            c = generate_cfg(client, tla_path.read_text(encoding="utf-8"), consts)
            cfg_path.write_text(c["cfg"], encoding="utf-8")
            stamp("cfg", requested_model=c["requested_model"], actual_model=c["actual_model"],
                  prompt_version=c["prompt_version"], missing_constants=c["missing_constants"])

    # [verify] -- SANY errors are reported by verify itself, unmodified.
    rep = verify_model(tla_path, cfg_path if cfg_path.exists() else None,
                       out / "verification" / module, **(verify_kwargs or {}))
    stamp("verify", outcome=rep["outcome"], findings=len(rep["findings"]),
          decomposed=rep["decomposition"] is not None)
    summary.update(outcome=rep["outcome"], findings=len(rep["findings"]),
                   decomposed=rep["decomposition"] is not None
                   and not (rep["decomposition"] or {}).get("error"))
    return summary


def verify_existing(root: Path, verify_kwargs: dict) -> List[dict]:
    """Every <M>.tla with a sibling <M>.cfg under `root`, plus the
    repo-root ArmFailSafe.tla (generated pieces, replay modules and
    verification outputs excluded)."""
    out = []
    for tla in sorted(root.rglob("*.tla")) + sorted(REPO.glob("*.tla")):
        if "verification" in tla.parts or tla.stem.endswith(("__Budget", "__Replay")) \
                or "__part" in tla.stem:
            continue
        cfg = tla.with_suffix(".cfg")
        if not cfg.exists():
            continue
        rep = verify_model(tla, cfg, tla.parent / "verification" / tla.stem, **verify_kwargs)
        out.append({"section": str(tla.relative_to(REPO)), "module": tla.stem,
                    "outcome": rep["outcome"], "findings": len(rep["findings"]),
                    "decomposed": bool(rep["decomposition"]) and not rep["decomposition"].get("error"),
                    "error": None})
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description="Matter spec -> TLA+ -> SANY/TLC with decomposition")
    ap.add_argument("--corpus", default="data/processed/core",
                    help="directory with sections.json / ranked_candidates.json")
    ap.add_argument("--pdf", help="rebuild the corpus from this PDF first")
    ap.add_argument("--doc-name", default="core")
    ap.add_argument("--content-start-page", type=int)
    ap.add_argument("--sections", nargs="*", default=[], help="section ids, e.g. core_11.10.7.2")
    ap.add_argument("--top", type=int, default=0, help="also run the top-N ranked candidates")
    ap.add_argument("--second-hop", nargs="*", default=[],
                    help="extra context sections (bare numbers, e.g. 4.11.1.1); only "
                         "meaningful with a single target section")
    ap.add_argument("--model", help="OpenRouter model id (default: OPENROUTER_MODEL or "
                                    "nvidia/nemotron-3-super-120b-a12b:free)")
    ap.add_argument("--regenerate", action="store_true", help="redo LLM stages even if cached")
    ap.add_argument("--verify-only", action="store_true",
                    help="no generation: verify every model with a .cfg under tla_models/")
    ap.add_argument("--max-states", type=int, default=DEFAULT_MAX_STATES)
    ap.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    ap.add_argument("--decompose", choices=["auto", "always", "never"], default="auto")
    a = ap.parse_args(argv)
    vk = {"max_states": a.max_states, "timeout": a.timeout, "decompose": a.decompose}
    t0 = time.time()

    if a.verify_only:
        results = verify_existing(REPO / "tla_models", vk)
    else:
        corpus = Path(a.corpus)
        if a.pdf:
            from src.build_corpus import build_corpus
            build_corpus(a.pdf, a.doc_name, str(corpus), content_start_page=a.content_start_page)
        sections = load_sections(corpus / "sections.json")
        targets = list(a.sections)
        if a.top:
            ranked = json.loads((corpus / "ranked_candidates.json").read_text(encoding="utf-8"))
            targets += [c["id"] for c in ranked[:a.top] if c["id"] not in targets]
        if not targets:
            ap.error("give --sections and/or --top (or --verify-only)")
        if a.second_hop and len(targets) > 1:
            ap.error("--second-hop is per target; run one section at a time with it")
        try:
            client = OpenRouterClient(model=a.model)
        except LLMError as e:
            print(f"[pipeline] LLM unavailable ({e}); only cached generations will be used")
            client = None
        results = []
        for sid in targets:
            try:
                results.append(run_section(sid, sections, client, second_hop=a.second_hop,
                                           regenerate=a.regenerate, verify_kwargs=vk))
            except Exception as e:      # one bad section must not stop the batch
                results.append({"section": sid, "module": None, "outcome": "pipeline_error",
                                "findings": None, "decomposed": False, "error": str(e)})

    print(f"\n[pipeline] done in {time.time() - t0:.0f}s\n")
    print(f"{'section':<45} {'module':<28} {'outcome':<40} {'findings':>8}  decomposed")
    for r in results:
        print(f"{r['section']:<45} {str(r['module']):<28} {str(r['outcome']):<40} "
              f"{str(r['findings']):>8}  {'yes' if r['decomposed'] else 'no'}"
              + (f"\n    ! {r['error']}" if r.get("error") else ""))
    sys.exit(0 if all(r["outcome"] in ("checked_full", "checked_decomposed") for r in results) else 1)


if __name__ == "__main__":
    main()
