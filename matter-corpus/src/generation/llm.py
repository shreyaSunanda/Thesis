"""
OpenRouter access (OpenAI-compatible API), as set up in the Colab notebook
(progress log §13, §28, §36).

Defaults reproduce the configuration that produced the first complete TLA+
module: a FIXED model id (not "openrouter/free", whose routing changes run to
run -- progress log §14), temperature 0, and reasoning explicitly disabled
(§28: with reasoning on, the hidden reasoning consumed the whole completion
budget and `content` came back None).

The API key is read from OPENROUTER_API_KEY; it is never written to disk.
Every call returns the *actual* routed model id alongside the text, and the
callers record it in the run's provenance file.
"""
import os
from dataclasses import dataclass
from typing import Optional, Protocol

DEFAULT_MODEL = "nvidia/nemotron-3-super-120b-a12b:free"
OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"


@dataclass
class LLMResponse:
    text: str
    requested_model: str
    actual_model: Optional[str]
    finish_reason: Optional[str]


class LLMError(RuntimeError):
    pass


class LLMClient(Protocol):
    def complete(self, prompt: str, *, max_tokens: int) -> LLMResponse: ...


class OpenRouterClient:
    def __init__(self, model: Optional[str] = None, disable_reasoning: bool = True,
                 temperature: float = 0.0):
        try:
            from openai import OpenAI
        except ImportError as e:     # pragma: no cover - environment issue
            raise LLMError("the `openai` package is required: pip install -r requirements.txt") from e
        key = os.environ.get("OPENROUTER_API_KEY")
        if not key:
            raise LLMError("OPENROUTER_API_KEY is not set")
        self.model = model or os.environ.get("OPENROUTER_MODEL", DEFAULT_MODEL)
        self.disable_reasoning = disable_reasoning
        self.temperature = temperature
        self._client = OpenAI(base_url=OPENROUTER_BASE_URL, api_key=key)

    def complete(self, prompt: str, *, max_tokens: int) -> LLMResponse:
        extra = {"reasoning": {"enabled": False}} if self.disable_reasoning else None
        resp = self._client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=self.temperature,
            max_tokens=max_tokens,
            extra_body=extra,
        )
        if not resp.choices:
            raise LLMError(f"no choices returned (error: {getattr(resp, 'error', None)})")
        choice = resp.choices[0]
        text = choice.message.content
        if text is None:
            raise LLMError(f"content is None (finish_reason={choice.finish_reason}); "
                           "if reasoning is enabled it may have consumed the token budget")
        return LLMResponse(text=text, requested_model=self.model,
                           actual_model=getattr(resp, "model", None),
                           finish_reason=choice.finish_reason)
