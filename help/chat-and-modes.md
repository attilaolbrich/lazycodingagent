# Chat, sessions, and modes

## Multiple sessions

Each workspace can run **several chat sessions** in parallel:

- Every session has its own conversation and **agent engine**.
- Switching sessions or workspaces does **not** stop a run in another session; it continues in the background.
- Switch sessions from the **tab strip inside the Chat page** (one tab per active chat) or from **Sessions** in the nav rail; the active session name also appears in the **Session:** label on the Chat page.

Create sessions from **Sessions** (**+ New Chat Session**) or click **+** on the **session tab strip** at the top of the Chat page (same action). **✕** on a session tab archives that chat (restore from **Sessions**). In the **Sessions** nav view, use **Archive Session** / **Restore Session** (button below the list), **right-click** a row (**Archive Session**, **Restore Session**, or **Permanently Delete...**), or press **Delete** to permanently remove the selected session. Permanent delete removes chat history from app config only; your project folder on disk is unchanged. Archiving is not a permanent delete until you permanently delete from the list.

## Composer modes

| Mode | Purpose |
|------|---------|
| **Ask** | Q&A and exploration. Read-only tools (files, search, git inspect, `web_fetch`, `browser_read`). No writes or shell. |
| **Plan** | Design and specs. Can save plan markdown under `.plan/`. No arbitrary file writes or shell. |
| **Agent** | Full coding autopilot: patches, writes, shell, builds. Default for implementation work. |

The mode applies to the **next run** and is sent with the system prompt so the model knows which tools exist.

Pick **Ask**, **Plan**, or **Agent** from the **mode** combo at the left of the composer footer.

## Writes outside the working directory

Each chat session has its own **Allow modify outside the working directory** checkbox in the composer footer (default off). When off, Agent mode can still **read** files anywhere, but write tools and shell working directories must stay inside the open workspace folder. When on, that session may modify files and run shell commands with cwd outside the workspace—use only when you intend it.

Starting **Build** on the **Plan** utility tab opens a confirmation dialog with the same option before a new Agent session is created to implement the plan.

## Image attachments (vision)

You can attach **screenshots and mockups** so a **vision-capable model** can see them (configure one in Settings, e.g. GPT-4o, Claude 3.x via OpenRouter, or a local Ollama vision model).

- Click **Attach image** in the composer footer, or **Ctrl+V** in the prompt box when the clipboard holds a picture.
- Supported types: **PNG, JPEG, WebP, GIF**. Up to **4** images per message, **5 MiB** each (large images may be downscaled to 2048 px on the longest edge).
- Files are copied into **`.lca/attachments/`** under the workspace; session history stores paths only, not embedded binary.
- Text-only models ignore image bytes poorly or return errors—pick a model that supports vision for image-heavy prompts.

## Model selection

The **model** combo lists models you configured in Settings. The choice is kept with the workspace and shown on the status bar when relevant.

## LLM provider and endpoint

**Settings → Provider** offers a fixed catalog of hosted inference providers plus **Custom**. For catalog providers, the app **prefills a default Base API Endpoint** (OpenAI-compatible `/v1` style for most entries). You can edit that URL—for example for a proxy or staging endpoint. Use **Open provider portal** for signup links when available.

**Custom** is a single profile: set a **display name**, endpoint URL, API key, and saved models like any other provider. Per-provider API keys and URLs are stored separately so you can switch providers without retyping.

On the same **Agent** tab, **Native tool calling**, **Text tool-call compatibility**, and **Streaming completions** control how tool schemas and responses are exchanged with OpenAI-compatible APIs (see **How the agent works**).

## Debugging mode vs live trace

In **Settings → Agent Behavior**, enable **Debugging mode** to show **full tool results** in the chat transcript. When disabled, successful tool JSON stays out of chat; **errors** still appear.

With debugging off, you still get a readable run in chat:

- Muted tool-activity lines when each tool starts (leading **-**, tool name, and a short summary of its inputs — for example **read_file · mainunit.pas** or **shell · git status**). Not part of saved conversation history.
- A small italic **Thinking…** line while the model is working (also ephemeral; cleared when the next message or tool line appears).
- **Tools & Logs** in the nav rail plus **Execution Detail** in the utility panel for full prompts, tool arguments, and outputs.

Open **Tools & Logs** and **Execution Detail** yourself anytime to inspect a run. Click an older log row to **pin** the inspector on that step; click the **latest** row to follow the live trace again.

## Learn mode

In **Settings → Agent Behavior**, enable **Learn mode** when you want a guided tour of each agent run (off by default for everyday coding).

When **Learn mode** is on, sending a prompt:

- Switches the nav rail to **Tools & Logs**
- Opens the utility panel on **Execution Detail**
- **Follows** new log steps in the inspector until you select an older row (click the latest row again to resume follow)

**Learn mode** controls where the UI goes during a run. **Debugging mode** controls whether full tool JSON appears in chat—they are independent.

## Step limit

**Max steps** in Settings caps how many LLM round-trips one send can take (default **200**). The status bar shows the current step during a run. If the cap is hit while the model still requested tools, the assistant adds a brief step-limit message instead of ending silently.

## Max output tokens and truncation

**Max Output Tokens** in **Settings → Agent Behavior** limits how much the model can generate in one completion (default **8192** for new installs). Agent runs that emit large tool-call JSON or long replies need enough headroom; values below about **2048** often truncate tool arguments and break the loop.

## LLM HTTP timeouts

Each chat completion, model list fetch, and context summarization call uses one HTTPS request. On **Settings → Agent Behavior** you can set:

- **LLM connect timeout (sec)** — DNS, TCP, and TLS handshake (default **60**; minimum **60**)
- **LLM response read timeout (sec)** — waiting for the provider to return the response body (default **600**; minimum **60**)

These apply on Windows, Linux, and macOS. They do not limit total agent run time—only a single HTTP round-trip. Tool HTTP (web search, web fetch, browser) uses separate timeouts.

**LLM HTTP retries on failure** (default **3**) controls how many **extra** attempts follow a failed request (timeouts, connection errors, HTTP 429/502/503/504). Set **0** to disable retries. Waits between attempts increase exponentially starting at **1 second** (1s, 2s, 4s, …). Client errors such as 401 are not retried.

When a completion is cut off (`finish_reason` length), the agent **retries once or twice** with a temporarily higher output budget (up to 16384) before accepting the result. Final assistant text may include a short note if output was still incomplete.

## Context summarization

Enable **Auto-summarize when nearing context limit** (on by default) to compress **older** chat turns into a summary message while keeping recent turns verbatim. This runs **before** a step when estimated prompt size crosses your threshold, or **reactively** when the provider returns a context-length error.

Optional fields on the same tab:

- **Context window (tokens)** — model context size used for proactive threshold (default 128000 for long-context models).
- **Summarize threshold** — fraction of usable prompt budget before summarizing (default 0.85).

When summarization runs, chat shows a brief assistant note: *Context summarized to continue the conversation.*

## Copying text from chat

Click and drag in the **conversation history** to select rendered text (what you see on screen, not raw Markdown markers). **Double-click** selects a word. **Ctrl+C** copies the selection; **Ctrl+A** selects the full history. Selection clears when new content is appended during a streaming reply. The same selection and shortcuts work in **plan**, **help**, and **Markdown preview** panes that use the canvas Markdown view.

## Cancel and exit

Use **Stop** / cancel in the chat UI to abort an active run. Quitting the app with runs in progress should prompt to stop them cleanly.
