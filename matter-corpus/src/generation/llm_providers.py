"""
Provider-agnostic LLM abstraction for TLA+ generation.

Every provider exposes the same generate(prompt) -> str interface, so
generate_tla.py doesn't care which backend is behind it. Swapping from a
free-tier model today to a paid, pinned one later (once your supervisor
arranges access) is a one-line change on the command line:

    --provider openrouter --model "nvidia/nemotron-3-super:free"   (today)
    --provider anthropic  --model "claude-sonnet-4-6"              (later)

Nothing else in the pipeline changes.

To add a new provider: subclass LLMProvider, implement generate(), and
register it in PROVIDERS at the bottom.
"""
import json
import os
import urllib.request
import urllib.error
from abc import ABC, abstractmethod


class LLMProviderError(Exception):
    """Raised when a provider call fails (auth, network, bad response shape)."""


class LLMProvider(ABC):
    def __init__(self, model: str, api_key: str = None):
        self.model = model
        self.api_key = api_key

    @abstractmethod
    def generate(self, prompt: str) -> str:
        """Sends `prompt` to the provider and returns the raw text response."""
        raise NotImplementedError

    def _post_json(self, url: str, headers: dict, payload: dict, timeout: int = 360) -> dict:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            raise LLMProviderError(f"HTTP {e.code} from {url}: {body[:500]}") from e
        except urllib.error.URLError as e:
            raise LLMProviderError(f"Network error calling {url}: {e}") from e


class AnthropicProvider(LLMProvider):
    """Needs ANTHROPIC_API_KEY. Paid — for once the supervisor sets you up."""
    def generate(self, prompt: str) -> str:
        if not self.api_key:
            raise LLMProviderError("Missing Anthropic API key (set ANTHROPIC_API_KEY or pass --api-key).")
        result = self._post_json(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": self.api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            payload={
                "model": self.model,
                "max_tokens": 4000,
                "messages": [{"role": "user", "content": prompt}],
            },
        )
        blocks = result.get("content", [])
        return "".join(b.get("text", "") for b in blocks if b.get("type") == "text")


class OpenAIProvider(LLMProvider):
    """Needs OPENAI_API_KEY."""
    def generate(self, prompt: str) -> str:
        if not self.api_key:
            raise LLMProviderError("Missing OpenAI API key (set OPENAI_API_KEY or pass --api-key).")
        result = self._post_json(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {self.api_key}", "content-type": "application/json"},
            payload={"model": self.model, "messages": [{"role": "user", "content": prompt}]},
        )
        return result["choices"][0]["message"]["content"]


class OpenRouterProvider(LLMProvider):
    """
    Needs OPENROUTER_API_KEY. OpenRouter proxies many providers, including
    free-tier models (e.g. model="nvidia/nemotron-3-super-...:free") — this
    is the free-tier path from the earlier notebook work. Known instability
    here: routing can silently swap the underlying model, responses can get
    truncated, and some free models burn their whole budget on hidden
    reasoning tokens instead of actual output. If `generate()` returns
    something that doesn't look like a TLA+ module, check the raw response
    before assuming the prompt itself is at fault.
    """
    def generate(self, prompt: str) -> str:
        if not self.api_key:
            raise LLMProviderError("Missing OpenRouter API key (set OPENROUTER_API_KEY or pass --api-key).")
        result = self._post_json(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={"Authorization": f"Bearer {self.api_key}", "content-type": "application/json"},
            payload={"model": self.model, "messages": [{"role": "user", "content": prompt}]},
        )
        return result["choices"][0]["message"]["content"]


class GoogleProvider(LLMProvider):
    """Needs GOOGLE_API_KEY. Direct Gemini API."""
    def generate(self, prompt: str) -> str:
        if not self.api_key:
            raise LLMProviderError("Missing Google API key (set GOOGLE_API_KEY or pass --api-key).")
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self.model}:generateContent?key={self.api_key}"
        )
        result = self._post_json(url, headers={"content-type": "application/json"},
                                  payload={"contents": [{"parts": [{"text": prompt}]}]})
        candidates = result.get("candidates", [])
        if not candidates:
            raise LLMProviderError(f"No candidates in Gemini response: {result}")
        parts = candidates[0].get("content", {}).get("parts", [])
        return "".join(p.get("text", "") for p in parts)


class VertexProvider(LLMProvider):
    """
    Claude on Google Vertex AI — the paid path the supervisor's Google Cloud
    account gives access to (Model Garden -> publishers/anthropic/models/...).

    No Anthropic API key: auth is Google Application Default Credentials, set
    up once with `gcloud auth application-default login`. Two settings are
    read from the environment (or passed in):

        ANTHROPIC_VERTEX_PROJECT_ID   GCP project id, e.g. gen-lang-client-0500261051
        CLOUD_ML_REGION               "global" (recommended), or e.g. us-east5

    Model ids on Vertex carry no "anthropic/" prefix — use the plain id shown
    in Model Garden, e.g. "claude-opus-5".

    Unlike the other providers here this one goes through the official
    anthropic SDK rather than raw urllib, because Vertex requests have to be
    signed with a refreshed Google OAuth token on every call.
    """

    def __init__(self, model: str, api_key: str = None, project_id: str = None,
                 region: str = None, max_tokens: int = 32000, effort: str = "high"):
        super().__init__(model=model, api_key=api_key)
        self.project_id = project_id or os.environ.get("ANTHROPIC_VERTEX_PROJECT_ID")
        self.region = region or os.environ.get("CLOUD_ML_REGION", "global")
        self.max_tokens = max_tokens
        self.effort = effort

    def generate(self, prompt: str) -> str:
        try:
            from anthropic import AnthropicVertex
        except ImportError as e:
            raise LLMProviderError(
                'Vertex provider needs the Anthropic SDK: pip install "anthropic[vertex]"'
            ) from e
        if not self.project_id:
            raise LLMProviderError(
                "Missing GCP project id (set ANTHROPIC_VERTEX_PROJECT_ID)."
            )
        client = AnthropicVertex(project_id=self.project_id, region=self.region)
        try:
            # Streaming, because a full TLA+ module can take minutes at a large
            # max_tokens and a non-streaming request would hit the HTTP timeout.
            with client.messages.stream(
                model=self.model,
                max_tokens=self.max_tokens,
                output_config={"effort": self.effort},
                messages=[{"role": "user", "content": prompt}],
            ) as stream:
                message = stream.get_final_message()
        except Exception as e:
            raise LLMProviderError(f"Vertex call failed ({type(e).__name__}): {e}") from e
        if message.stop_reason == "refusal":
            raise LLMProviderError(f"Model declined the request: {message.stop_details}")
        return "".join(b.text for b in message.content if b.type == "text")


class VertexGeminiProvider(LLMProvider):
    """
    Gemini on Vertex AI — the only high-quality family actually usable on the
    supervisor's GCP project. Every anthropic-claude-* base model there has a
    quota of 0 (see VertexProvider's docstring), so Claude 429s regardless of
    region; Gemini runs on dynamic shared quota and answers immediately.

    Not the same thing as GoogleProvider above: that one talks to the Gemini
    *Developer* API (generativelanguage.googleapis.com, API-key auth, personal
    quota). This one talks to Vertex, authenticated with the same Google ADC
    credentials as VertexProvider and billed to the supervisor's project.

    Model ids are the plain Model Garden ids, e.g. "gemini-3.1-pro-preview".
    """

    def __init__(self, model: str, api_key: str = None, project_id: str = None,
                 region: str = None, max_tokens: int = 32768):
        super().__init__(model=model, api_key=api_key)
        self.project_id = project_id or os.environ.get("ANTHROPIC_VERTEX_PROJECT_ID")
        self.region = region or os.environ.get("CLOUD_ML_REGION", "global")
        self.max_tokens = max_tokens

    def _access_token(self) -> str:
        try:
            import google.auth
            import google.auth.transport.requests
        except ImportError as e:
            raise LLMProviderError(
                'Vertex Gemini needs Google auth libs: pip install "anthropic[vertex]"'
            ) from e
        try:
            creds, _ = google.auth.default(
                scopes=["https://www.googleapis.com/auth/cloud-platform"]
            )
            creds.refresh(google.auth.transport.requests.Request())
        except Exception as e:
            raise LLMProviderError(
                f"No usable Google credentials ({e}). "
                "Run: gcloud auth application-default login"
            ) from e
        return creds.token

    def generate(self, prompt: str) -> str:
        if not self.project_id:
            raise LLMProviderError(
                "Missing GCP project id (set ANTHROPIC_VERTEX_PROJECT_ID)."
            )
        host = ("aiplatform.googleapis.com" if self.region == "global"
                else f"{self.region}-aiplatform.googleapis.com")
        url = (f"https://{host}/v1/projects/{self.project_id}/locations/"
               f"{self.region}/publishers/google/models/{self.model}:generateContent")
        result = self._post_json(
            url,
            headers={
                "Authorization": f"Bearer {self._access_token()}",
                "content-type": "application/json",
            },
            payload={
                "contents": [{"role": "user", "parts": [{"text": prompt}]}],
                "generationConfig": {"maxOutputTokens": self.max_tokens},
            },
        )
        candidates = result.get("candidates", [])
        if not candidates:
            raise LLMProviderError(f"No candidates in Vertex Gemini response: {result}")
        cand = candidates[0]
        parts = cand.get("content", {}).get("parts", [])
        text = "".join(p.get("text", "") for p in parts)
        if not text:
            # A thinking-heavy model that hits the cap can return zero visible
            # text; surfacing finishReason beats handing back an empty module.
            raise LLMProviderError(
                f"Empty response (finishReason={cand.get('finishReason')}). "
                "Try raising max_tokens."
            )
        return text


class MockProvider(LLMProvider):
    """
    No network call, no API key, no cost. Returns a fixed placeholder module.
    Use this to test everything ELSE in the pipeline — context assembly, file
    writing, SANY validation wiring — before spending a single real API call.
    This is exactly how this script was tested before being handed to you.
    """
    def generate(self, prompt: str) -> str:
        return (
            "---- MODULE Mock ----\n"
            "EXTENDS Naturals\n"
            "VARIABLES state\n"
            "Init == state = \"Init\"\n"
            "Next == state' = state\n"
            "===="
        )


PROVIDERS = {
    "anthropic": AnthropicProvider,
    "vertex": VertexProvider,
    "vertex-gemini": VertexGeminiProvider,
    "openai": OpenAIProvider,
    "openrouter": OpenRouterProvider,
    "google": GoogleProvider,
    "mock": MockProvider,
}


def get_provider(name: str, model: str, api_key: str = None) -> LLMProvider:
    if name not in PROVIDERS:
        raise ValueError(f"Unknown provider '{name}'. Choices: {list(PROVIDERS)}")
    return PROVIDERS[name](model=model, api_key=api_key)
