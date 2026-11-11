# How the agent works

This section is for learning how LazyCodingAgent ties together the LLM, tools, and UI. The implementation lives mainly in `uAgentEngine`, `uAgentTools`, and `uChatSessionHub`.

## What runs when you send a message

1. Your prompt is attached to the **current chat session**.
2. That session owns one **agent engine** instance (conversation history + tool registry).
3. A **background thread** runs the agent loop so the UI stays responsive.
4. The UI receives events for new messages, tool calls, and state (thinking, executing tools, finished, error).

You can start runs in multiple sessions; each engine is independent.

## The ReAct loop (reason + act)

After you send a message, the engine roughly does:

1. Build or refresh the **system prompt** (mode, workspace path, tool list, project rules).
2. Append your message to the conversation (including **image attachments** as metadata under `.lca/attachments/` when you attach screenshots in chat).
3. Optionally **compact history** when auto-summarize is enabled and the prompt is near the configured context window (`uChatContextManager`).
4. Call the **LLM** with the message list and tool definitions. User turns with images are sent as **multimodal** content (text plus image URLs) to OpenAI-compatible APIs; **tools remain text/JSON only**. If output is truncated by **Max Output Tokens**, the engine may retry with a higher temporary limit before continuing.
5. If the model returns **tool calls**, run each tool locally and append **tool result** messages (including JSON with an `error` field when a tool fails).
6. Repeat steps 3–5 until the model answers **without** tool calls, you **cancel**, or a **step limit** is reached (default 200 steps).

Unexpected tool exceptions are caught at the tool boundary, converted to the same error JSON shape, and returned to the model so the loop can continue instead of stopping under the debugger.

This pattern is often called **ReAct**: the model reasons in natural language, then acts via tools, then reasons again on the results.

```
You → system + history → (optional summarize) → LLM → (optional tools) → LLM → … → final reply
```

## What goes into the system prompt

- **Workspace mode** (Ask / Plan / Agent) — controls which tools are advertised.
- **Workspace root** — all file paths are resolved relative to this folder.
- **Tool guidance** — when **Native tool calling** is on and the provider API accepts a native `tools` array, tool **schemas are not repeated** in the system message (only in the HTTP `tools` field). If native tool calling is off, the system prompt includes full parameter JSON for each allowed tool.
- **Project rules** — combined text from `<workspace>/.rules/*.md`.

The model only sees tools that are **allowed in the current mode**.

**Host vs opened project:** LazyCodingAgent is a Lazarus desktop app, but the folder you open may be any stack (HTML, Python, Go, Pascal, and so on). In **Agent** mode, the system prompt tells the model to match the languages and formats already in that workspace—not to default to Free Pascal. Use **Project Rules** (`.rules/*.md`) to state primary languages, test commands, and style (for example static site HTML/CSS/JS and how to run site checks).

## Modes vs file changes

| Mode | Typical use | Mutations |
|------|-------------|-----------|
| Ask | Explain code, search, read | No writes, patch, or shell |
| Plan | Specs and checklists | Can write `.plan/plan-*.md` only |
| Agent | Implement and fix | Writes, patches, shell, builds |

Plan and Ask still use read/search/git tools to understand the tree.

## What you see in the UI

- **Assistant messages** — model text and (in debugging mode) full tool JSON in chat.
- **Live tool trace** — while a run is in progress, chat shows muted lines starting with **-**, then the tool name and a short summary of its arguments (for example **read_file · src/foo.pas** or **git · status**) when the model invokes a tool (display only; not sent back to the model). An ephemeral **Thinking…** line may appear while waiting on the model. Neither trace nor thinking lines are kept when the transcript is reloaded from saved messages.
- **State** — idle, thinking, executing tool, finished, or error. During a run the status bar includes **step N/M** (for example `Thinking... (step 2/200)`), where **M** is **Max steps** from Settings.
- **Execution log** (navigation **Tools & Logs**) — per-step trace with plain captions (`User:`, `Step N/M · Model:`, `Step N/M · tool_name(...)`). Click a row to inspect it in the utility **Execution Detail** panel. With **Learn mode** enabled in Settings, new log rows **follow** into Execution Detail during a run unless you click an older row (click the latest row again to resume follow).
- **Step limit** — if the loop uses all allowed steps and the model still wanted tools, the assistant posts a short note that the step limit was reached (configure **Max steps** in Settings).
- **Tool Errors** — failed tools for the session, plus a shared `tool-errors.log` file under your user config folder.

With **Learn mode** enabled in Settings, sending a prompt switches to **Tools & Logs**, opens the **utility panel** on **Execution Detail**, and follows each step so you can watch the enriched prompt and tool I/O during a demo or learning session. The inspector shows that content as readable plain text in the themed Markdown view. Learn mode also records **LLM wire** rows: redacted outgoing request JSON, incoming response JSON, parsed tool calls, and parse notes (API keys are not logged).

## LLM tool calling (Settings → Agent)

| Setting | Default | Purpose |
|---------|---------|---------|
| **Native tool calling** | On | Sends OpenAI-compatible `tools` + `tool_choice: auto` on `/chat/completions`. |
| **Text tool-call compatibility** | Off | Treats a **single** strict `{ "name", "arguments" }` JSON object in assistant **text** as one tool call (for some local models). Never parses JSON inside prose or examples. |
| **Streaming completions** | Off | Experimental SSE streaming for OpenAI-compatible APIs; tool-call fragments are accumulated before execution. |

For **Ollama** and similar hosts, enable text compatibility if the model prints tool JSON in chat instead of native `tool_calls`.

## Safety and sandboxing

- **Reads:** inspection tools (`read_file`, `list_directory`, `glob`, `search_code`, and similar) may use paths **outside** the workspace when you pass an absolute path or a relative path that leaves the project folder.
- **web_search:** finds current public information when enabled in Settings → Tools (provider choice is internal; the model only passes a query).
- **web_fetch:** retrieves public web pages only (SSRF-safe). Prefer it over shell/curl for static pages.
- **browser_read:** headless Chromium for JavaScript-rendered pages when `web_fetch` is insufficient. Requires a local Chrome/Chromium/Edge install.
- Web tool content is shown to the model as tool JSON — it is **not** trusted like the system prompt or project rules; the model is instructed to ignore instructions embedded in pages.
- **Writes:** by default, write tools (`write_file`, `edit_file`, `apply_patch`), plan saves under `.plan/`, chat image attachments, and shell **cwd** values must stay inside the **workspace root**. Enable **Allow modify outside the working directory** on the chat composer (per session) to permit writes and shell cwd outside the project for that chat only.
- The **git** tool is **read-only** (status, diff, log, show).
- **Shell** runs with a timeout cap; use Agent mode only when you trust the workspace and model.

## Learn more

See **Agent tools reference** for each tool name, what it does, and which modes allow it.
