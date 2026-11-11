# Browser automation

Lazy Coding Agent drives Chromium (Chrome, Chromium, or Edge) through the Chrome DevTools Protocol (CDP). Sessions are **headless by default**; use `browser_navigate` with **`visible: true`** when you need a real browser window. Use automation to verify web apps you build in the workspace.

## Setup

1. Install a Chromium-compatible browser (Google Chrome, Chromium, or Edge).
2. Set **Settings → Agent → Chromium executable** if auto-discovery fails. On Linux, if `/usr/bin/google-chrome` is a wrapper script, try `/opt/google/chrome/google-chrome` explicitly.
3. For **localhost** dev servers, enable browser localhost permission for the chat session (stored in session metadata as `allowBrowserLocalhost`).
4. For **clicks and form fills**, enable interactive browser permission (`allowBrowserInteractive`).

## Workflow example

1. Start your dev server with `shell` (Agent mode).
2. `browser_navigate` to `http://127.0.0.1:3000/` (with localhost allowed).
3. `browser_inspect` to find selectors or `ref` values.
4. `browser_fill` / `browser_click` / `browser_wait`.
5. `browser_console` and `browser_network` for failures.
6. `browser_screenshot` for visual evidence (saved under `.lca/artifacts/`).
7. `browser_close` when finished.

## Visible browser (login and paired review)

When the user must **see** the page or **interact** before the agent continues (sign-in, MFA, exploring UX while the agent watches):

1. `browser_navigate` with `visible: true` and the URL (omit `session_id` to create a session). A Chromium window opens; the response includes `session_id`, `visible: true`, and `automation_paused: true`.
2. The user works in that window without the agent sending clicks or fills (`browser_click`, `browser_fill`, `browser_select`, and re-navigation are blocked until automation resumes).
3. While paused, the agent may still use read-only tools: `browser_inspect`, `browser_screenshot`, `browser_wait`, `browser_console`, `browser_network`.
4. When the user is ready, the agent calls `browser_resume_automation` with the same `session_id`, then may use interactive tools. The user can still watch and use the window; call `browser_pause_automation` to yield control back to the user.
5. `browser_close` when finished.

**Network / login:** Browser sessions use a CDP network guard (same URL policy as `web_fetch`). A background CDP pump continues paused requests while you use the window, so login and API calls should not hang. If login calls a **localhost** or **private** API, enable **allow browser localhost** for the chat session so those subrequests are allowed.

**Notes:** Agent tools target the tab created for the session. If the user opens another tab and switches to it, the agent does not automatically follow—stay on the original tab or start a new session. Visible sessions are not dropped by idle timeout while the window is open; headless sessions still time out after inactivity.

## Screenshots and models

Screenshot tools return `artifact_path` in JSON. Image-capable models may receive the attachment on the tool result; text-only models should read the path.

## Troubleshooting

- **BROWSER_NOT_FOUND** — Install Chrome/Chromium/Edge or set the executable path.
- **CDP_CONNECTION_FAILED** — Headless Chrome started but the app could not open the DevTools WebSocket (message may include details such as `Sec-WebSocket-Accept mismatch` or `TCP connect failed`). Check: browser runs from a terminal (`google-chrome --headless=new --remote-debugging-port=9222 --remote-allow-origins=* about:blank` then `curl http://127.0.0.1:9222/json/version`); set the real binary in Settings (not a distro wrapper); avoid Snap-only Chromium unless it supports remote debugging.
- **ACCESS_DENIED** — URL blocked (private network) or localhost/interactive permission missing.
- **AUTOMATION_PAUSED** — Interactive tool on a visible session while paused; call `browser_resume_automation` first.
- **SESSION_NOT_FOUND** — Wrong `session_id` or session idle-timed out; navigate again.
- **AMBIGUOUS_SELECTOR** — CSS matched multiple elements; narrow the selector.
