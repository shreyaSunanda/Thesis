"""
Context assembly for one target section: the text bundle handed to the LLM.

Ported from the Colab notebook (cells 33 and 36, "ArmFailSafe_final_context"):
parent section + target + its direct (one-hop, resolved, in-corpus)
references + optionally a hand-picked list of second-hop sections. The
notebook hard-coded the target ("11.10.7.2") and the second-hop list; here
both are parameters, and the corpus is this repo's sections.json (ids carry
the doc prefix, e.g. "core_11.10.7.2").

The rendered text keeps the notebook's exact layout ("SECTION 11.10.7.2:
...", bare section numbers) so prompts stay comparable with the notebook
runs already reported in the progress log.
"""
import json
from pathlib import Path
from typing import Dict, List, Optional


def load_sections(path) -> Dict[str, dict]:
    with open(path, encoding="utf-8") as f:
        return {s["id"]: s for s in json.load(f)}


def bare(section_id: str) -> str:
    """'core_11.10.7.2' -> '11.10.7.2' (the form the prompts and the LLM use)."""
    return section_id.split("_", 1)[1] if "_" in section_id else section_id


def qualify(number: str, doc_name: str) -> str:
    return number if number.startswith(f"{doc_name}_") else f"{doc_name}_{number}"


def build_context(sections: Dict[str, dict], target_id: str,
                  second_hop: Optional[List[str]] = None) -> dict:
    if target_id not in sections:
        raise KeyError(f"section {target_id} not in corpus")
    target = sections[target_id]
    doc = target.get("doc_name") or target_id.split("_", 1)[0]

    ids: List[str] = []
    parent = target.get("parent_id")
    if parent and parent in sections:
        ids.append(parent)
    ids.append(target_id)
    ids += [r for r in target.get("references", []) if r in sections]
    ids += [qualify(s, doc) for s in (second_hop or []) if qualify(s, doc) in sections]
    ids = list(dict.fromkeys(ids))

    return {
        "matter_version": "1.6",
        "target_section": bare(target_id),
        "target_id": target_id,
        "target_title": target["title"],
        "context_strategy": {"parent": True, "direct_dependencies": True,
                             "selected_second_hop": list(second_hop or [])},
        "context_section_ids": [bare(i) for i in ids],
        "sections": [
            {
                "section_id": bare(i),
                "title": sections[i]["title"],
                "parent": bare(sections[i]["parent_id"]) if sections[i].get("parent_id") else None,
                "start_page": sections[i].get("page_start"),
                "end_page": sections[i].get("page_end"),
                "references": [bare(r) for r in sections[i].get("references", [])],
                "text": sections[i].get("full_text", ""),
            }
            for i in ids
        ],
    }


def render_context(bundle: dict) -> str:
    """Same text layout as the notebook's ArmFailSafe_final_context.txt."""
    out = ["Matter Specification Version 1.6\n",
           f"Target Section: {bundle['target_section']}\n",
           f"Target Title: {bundle['target_title']}\n\n"]
    for s in bundle["sections"]:
        out.append("=" * 80 + "\n")
        out.append(f"SECTION {s['section_id']}: {s['title']}\n")
        out.append(f"PDF pages: {s['start_page']} - {s['end_page']}\n")
        out.append("References: " + ", ".join(s["references"]) + "\n")
        out.append("=" * 80 + "\n\n")
        out.append(s["text"])
        out.append("\n\n")
    return "".join(out)


def save_context(bundle: dict, out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "context.json").write_text(json.dumps(bundle, indent=2, ensure_ascii=False),
                                          encoding="utf-8")
    p = out_dir / "context.txt"
    p.write_text(render_context(bundle), encoding="utf-8")
    return p
