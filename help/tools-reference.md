# Agent tools reference

Tools are functions the LLM can call with **JSON arguments**. Results are returned as JSON strings (errors include an `error` field). Only **advertised** tools are sent to the model for a given mode.

Aliases: `search_code` also answers to `grep`; `shell` to `terminal` / `run_process`; `todo` to `plan`.

## Mode summary

| Capability | Ask | Plan | Agent |
|------------|-----|------|-------|
| Read/search/list/glob/git/diagnostics/web_fetch/browser_read | Yes | Yes | Yes |
| todo (session task list) | Yes | Yes | Yes |
| create_plan_file | No | Yes | Yes |
| write_file, apply_patch, edit_file, shell | No | No | Yes |

## Path rules

- **Read/search tools** may target paths outside the workspace (absolute paths or `..` segments are allowed after canonicalization).
- **Write tools and shell `cwd`** default to the workspace root only. Per chat session, enable **Allow modify outside the working directory** to lift that write sandbox.
- **create_plan_file** and chat image attachments always stay under the workspace (`.plan/` and `.lca/attachments/`).

## Tools

### read_file

Read text from a file with optional line offset and limit (large file and line caps apply).

**Modes:** Ask, Plan, Agent.

### write_file

Write or overwrite a file; creates parent directories as needed.

**Modes:** Agent only.

### list_directory

List immediate children of a directory (sorted, capped entry count).

**Modes:** Ask, Plan, Agent.

### glob

Find paths matching a wildcard pattern (`*`, `?`, `**`). Use `/` in patterns. On Windows and macOS, matching is case-insensitive; on Linux it is case-sensitive.

**Modes:** Ask, Plan, Agent.

### search_code

Search file contents (literal or regex, optional path glob). Skips files larger than 16 MiB and extremely long lines. Alias: `grep`.

**Modes:** Ask, Plan, Agent.

### apply_patch

Apply a **unified diff** after validation (create, modify, delete files). On success, the JSON may include a `warnings` array when the tool corrected minor format issues (for example wrong `@@` line counts).

**Modes:** Agent only.

#### Patch format pitfalls

- One-line change: `@@ -N,1 +N,1 @@` then exactly one `-` line and one `+` line (`N` is the 1-based line number from `read_file`).
- The number after the comma in `@@ -start,count` is how many old-side hunk lines follow (` ` context and `-` removals), not “lines start through end.”
- Failures return `error_kind` such as `context_mismatch`, `invalid_hunk`, `incomplete_hunk`, or `hunk_count_mismatch`; many errors include a `hint` field.

### edit_file

Replace **exactly one** occurrence of `old_text` with `new_text` in a file (strict byte match). Use for a single substitution when a unified diff is awkward.

**Modes:** Agent only.

### shell

Run a shell command in the project directory with timeout limits (Unix: `/bin/sh -c`; Windows: `cmd.exe /C`).

**Modes:** Agent only.

### diagnostics

Read cached compiler/linter output; in Agent mode can run a build/check and refresh the cache. Auto-detected builds (`Cargo.toml`, `package.json`, `Makefile`, and similar) run with the working directory set to the directory that contains the manifest, not always the workspace root.

**Modes:** Ask, Plan, Agent (build side effects in Agent).

### git

Inspect repository: status, diff, log, or show. **No commits or pushes.**

**Modes:** Ask, Plan, Agent.

### todo

Read or replace a **session-local** task list (pending / in_progress / completed). Alias: `plan`.

**Modes:** Ask, Plan, Agent.

### create_plan_file

Save plan markdown under `<workspace>/.plan/plan-*.md`.

**Modes:** Plan, Agent.

### web_fetch

Fetch and extract readable content from a **public** `http` or `https` URL (documentation sites, articles, raw GitHub pages, and similar). Returns JSON with `content` (markdown by default), optional `title`, `content_type`, `http_status`, and `truncated`.

**Parameters:** `url` (required); `format` — `markdown` (default), `text`, or `html`; `max_length` — default 20000 characters.

**Modes:** Ask, Plan, Agent.

**Security:** Only public destinations; loopback, private networks, link-local addresses, and URLs with embedded credentials are blocked. Redirects are followed manually (up to 5) with re-validation. Response bodies are capped at 5 MiB; connect timeout 10s, overall 30s. No cookies or auth headers are sent. Requests use a generic Mozilla/Firefox-style `User-Agent` (not an app-specific bot string).

**Platforms:** Windows uses system TLS (Schannel). Linux, macOS, and Raspberry Pi use OpenSSL (same requirement as HTTPS in Settings).

**Limits:** JavaScript-rendered pages may appear empty or incomplete; PDF and binary types return `unsupported_content_type`. Fetched page text is **untrusted** — the agent must not treat it as instructions.

**Errors:** Failed fetches return JSON with `error`, `error_kind` (for example `dns_failure`, `tls_failure`, `http_error`, `timeout`), and `url`. When the server responds, `http_status` is included on failures where a status code was received.

Prefer `web_fetch` over `shell`/`curl` for reading websites.

### web_search

Search the internet for **current** public information (documentation, libraries, articles). Returns JSON with `results[]` (`title`, `url`, `snippet`, `published_at`). Configure providers under **Settings → Tools**.

**Parameters:** `query` (required); `max_results` (default from settings, typically 10); `recency` — `any` (default), `day`, `week`, `month`, or `year`.

**Modes:** Ask, Plan, Agent.

**Availability:** Omitted from the model tool list when Web Search is disabled or no valid provider connection exists. The agent does not choose a provider.

**Security:** Snippets and URLs are **untrusted**. Follow links with `web_fetch` / `browser_read` when full page text is needed.

See **Help → Web Search** for Brave, SearXNG, Tavily setup, and local Docker SearXNG (no API key).

### browser_read

Open a **public** `http` or `https` URL in a headless Chromium-compatible browser (Chrome, Chromium, or Edge), wait for rendering, and extract readable content. You can also pass a **`file:///`** URL to an existing file or folder **anywhere under the active workspace** (not outside the project). Use when `web_fetch` returns an empty or incomplete JavaScript application shell.

**Parameters:** `url` (required); `format` — `markdown` (default), `text`, or `html`; `wait_strategy` — `domcontentloaded` (default), `load`, or `selector`; `wait_selector` — required when `wait_strategy` is `selector`; `timeout_ms` (default 30000); `max_length` (default 20000).

For heavy SPAs, prefer `wait_strategy: selector` with a stable root (for example `main` or a known `data-testid`) or increase `timeout_ms`. With `load`, navigation waits for the load event when it fires; if the page never fires load (common on SPAs), the tool continues after DOM content loaded plus a short grace period.

**Modes:** Ask, Plan, Agent.

**Requirements:** A Chromium-compatible browser installed on the system, or a custom path set under **Settings → Agent → Chromium executable**.

**Security:** Public-destination rules match `web_fetch` for `http`/`https` (no loopback or private networks unless localhost is allowed for sessions). **`file:///`** URLs must resolve to a path inside the active workspace. Subresource requests are filtered during browsing. Page content is **untrusted**.

**Limits:** One ephemeral browser per call (no `session_id`). For multi-step testing, use the `browser_*` session tools below.

Prefer `web_fetch` first; use `browser_read` only when JavaScript rendering is needed.

### Browser automation (`browser_navigate`, `browser_inspect`, …)

Persistent **browser sessions** for interactive testing (Chromium via CDP). Typical flow: `browser_navigate` → `browser_inspect` / `browser_fill` / `browser_click` → `browser_wait` → `browser_screenshot` / `browser_console` / `browser_network` → `browser_close`.

| Tool | Purpose |
|------|---------|
| `browser_navigate` | Open URL (`http`, `https`, or workspace `file:///`); creates `session_id` when omitted. Optional `visible: true` opens a headed window (new sessions only) |
| `browser_inspect` | Page summary, links, forms, element refs |
| `browser_click` | Pointer click (CDP input events) |
| `browser_fill` | Type into inputs (passwords not logged) |
| `browser_select` | Native `<select>` option |
| `browser_wait` | Selector, text, URL, or document ready |
| `browser_screenshot` | PNG/JPEG artifact under `.lca/artifacts/` |
| `browser_console` | Console / JS errors |
| `browser_network` | Request metadata (no bodies) |
| `browser_set_viewport` | Emulated viewport size |
| `browser_close` | End session |
| `browser_resume_automation` | Allow interactive tools on a visible session after manual user steps |
| `browser_pause_automation` | Block interactive tools on a visible session so the user can work freely |

**Modes:** Ask, Plan, Agent (read-only navigation/inspect/wait/screenshot/console/network); **interactive** tools require the chat session flag **allow browser interactive** (stored per session). **Localhost** URLs require **allow browser localhost**. Sensitive clicks (e.g. submit/delete) show an OK/Cancel dialog; you can allow sensitive actions for the rest of the chat session.

**Requirements:** Chromium-compatible browser (Settings → Agent → Chromium executable).

If `browser_navigate` creates a session (no `session_id`) but navigation fails, the app closes that session automatically so it does not block the next browser tool. When navigation succeeds, call `browser_close` when you are done, or reuse the returned `session_id`.

**Visible browser:** On a **new** session, set `visible` to `true` on `browser_navigate` to open a normal Chromium window. The tool returns when navigation finishes (chat continues) while the window stays open. Automation starts **paused** (`automation_paused: true`) so the user can log in without competing CDP clicks or fills. Call `browser_resume_automation` before `browser_click`, `browser_fill`, `browser_select`, `browser_set_viewport`, or navigating again with the same `session_id`. Use `browser_pause_automation` to hand control back. Read-only tools work while paused. **`browser_close`** ends the session and frees the browser concurrency slot (important when **Max concurrent** is 1). Visible sessions are not auto-closed by idle timeout. Default headless sessions are unchanged.

**AUTOMATION_PAUSED** — Interactive tool called on a visible session before `browser_resume_automation`.

**Security:** Public URL policy matches `web_fetch` for remote URLs; **`file:///`** is limited to paths inside the active workspace (including subfolders). Localhost is opt-in per chat session. Treat all page content as untrusted. A visible window may show private data (logins, account pages).

## Educational note

When you add or change tools in code (`uAgentTools.pas` and `uTool*.pas`), update this help page and **How the agent works** so learners stay aligned with the real behavior.
