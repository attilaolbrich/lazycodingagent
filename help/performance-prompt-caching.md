# Prompt caching

LazyCodingAgent can use **provider-side prompt caching** when your LLM endpoint supports it. Caching is transparent to the agent: conversation content and tool behavior are unchanged.

## Settings

Open **Settings → Performance → Prompt Caching**.

- **Enable prompt caching** — turns automatic or explicit caching on (or off).
- **Mode** — *Automatic* relies on stable prompt prefixes; *Explicit* adds provider cache breakpoints where supported (direct Anthropic API).
- **Cache retention** — when the provider supports it (e.g. extended TTL on Anthropic).
- **Cacheable content** — which logical sections may participate in caching.

Cache hits are **not guaranteed**. Routing changes (e.g. OpenRouter backends) can invalidate reuse.

## Metrics

When the provider returns cache usage fields, statistics appear under **Cache statistics**. Missing fields are shown as unknown, not zero.

Estimated dollar savings are not shown unless reliable model pricing is configured.

## Provider notes

| Provider | Behavior |
|----------|----------|
| OpenAI / OpenRouter (OpenAI-compatible) | Automatic prefix caching; reads `cached_tokens` when returned |
| Anthropic (direct `api.anthropic.com`) | Native Messages API with optional explicit breakpoints |
| Gemini | Implicit caching via stable `generateContent` payloads |
| Ollama / local | Stable prefixes; no cloud cache billing metrics |

## Limitations

- No streaming-specific cache API yet (chat uses full responses).
- OS-specific shell hints in the system prompt differ between Windows and Unix builds.
- Context summarization replaces part of history and may invalidate provider cache for earlier turns.
