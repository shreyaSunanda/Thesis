"""
One-shot connectivity check for Claude on Google Vertex AI.

Run this BEFORE spending real generation calls — it verifies, in order:
ADC credentials exist, the project/region are set, the Vertex AI API is
enabled, and the Claude model in Model Garden actually answers.

    export ANTHROPIC_VERTEX_PROJECT_ID=<your-gcp-project-id>
    export CLOUD_ML_REGION=global
    python check_vertex.py                 # defaults to claude-opus-5
    python check_vertex.py claude-sonnet-5-5
"""
import os
import sys

from src.generation.llm_providers import get_provider, LLMProviderError


def main():
    model = sys.argv[1] if len(sys.argv) > 1 else "gemini-3.1-pro-preview"
    project = os.environ.get("ANTHROPIC_VERTEX_PROJECT_ID")
    region = os.environ.get("CLOUD_ML_REGION", "global")
    print(f"project={project!r} region={region!r} model={model!r}")
    if not project:
        print("FAIL: ANTHROPIC_VERTEX_PROJECT_ID is not set.")
        return 1

    provider = get_provider(os.environ.get("VERTEX_PROVIDER", "vertex-gemini"), model=model)
    try:
        reply = provider.generate(
            "Reply with exactly one word: OK. Then stop."
        )
    except LLMProviderError as e:
        print(f"FAIL: {e}")
        return 1
    print(f"OK — model replied: {reply.strip()[:200]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
