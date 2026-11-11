# Getting started

LazyCodingAgent is a desktop AI coding workspace. You open a **project folder** as a workspace, chat with an LLM in multiple **sessions**, and (in Agent mode) let the assistant read and change files under that folder using **tools**.

On launch, a **branded splash image** appears while the app loads (about one second after loading finishes). Window chrome follows your saved theme (dark by default, or light if you chose **View → Toggle Light / Dark Theme** last time).

LazyCodingAgent does **not** register a project folder automatically. On a fresh install you can have **zero workspaces** until you add one.

## Open or create a workspace

1. Use **File → Open Project Folder** to point at an existing code tree, or **File → New Workspace** (or **Home → + New Workspace**) to create one.
2. After you select a workspace, the status bar and chat hero show its name.
3. Panel layout, theme, and dock state are saved in application settings.

## Remove a workspace from the list

To stop showing a project in LazyCodingAgent without deleting anything on disk:

- **Home** (Workspaces panel): select a workspace, then **Remove from List** or press **Delete**.
- **File → Remove Workspace from List…** removes the active workspace, the only listed workspace, or the row selected on Home when several are registered.

You may remove **every** workspace from the list. The Home panel then shows **No workspace yet — create or open a project folder**, the status bar shows **Workspace: (none)**, and chat stays hidden until you use **File → Open Project Folder** or **+ New Workspace**.

The app only updates its workspace list and related settings. Your **project folder is not modified or deleted**. **Chat session history** stays in application config; if you open the same folder again later, sessions can reappear.

If a listed folder was moved or deleted on disk, selecting it (or opening it on startup) prompts you to **remove it from the list** so you are not stuck on a broken entry.

## Settings you need first

Open **Settings** from the menu (or when prompted):

- **LLM provider** — API key, base URL if needed, and default model.
- **Fetch Models** — loads model IDs from your provider (requires working HTTPS).
- **Agent Behavior** — optional **Debugging mode** to show full tool JSON in chat.

Save settings before starting a long agent run.

**Optional: web search** — No search API key? See **Help → Web Search** → **Local SearXNG with Docker**.

## Building from source (developers)

From the repository root, install Lazarus packages once per machine (`scripts/install-lca-lazarus` on your OS), then:

```bash
lazbuild lazycodingagent.lpi
./scripts/post-build.sh
```

That copies **help/** and **assets/** (splash image) next to the executable so **Help → User Guide** and the startup splash work outside the IDE. See the project **README** for Windows commands and CI details.

## HTTPS and OpenSSL (Linux / Raspberry Pi)

Chat, **Fetch Models**, and the agent need **HTTPS**. On Linux the app uses the system **OpenSSL 3** libraries.

- **arm64 `.deb` (Raspberry Pi OS, Debian, Ubuntu):** Installing the release package should pull in **`libssl3`** automatically. If HTTPS still fails after an upgrade, run `sudo apt install libssl3` (on some distros the package is named `libssl3t64`).
- **Built from source on the Pi:** Install the runtime before using AI features: `sudo apt install libssl3`. You do not need the `-dev` package to run the app.

Chat and **Fetch Models** show a clear error instead of crashing when OpenSSL is missing on Linux. Saving API keys in **Settings** does not require OpenSSL on any platform.

## Your first chat

1. In the left rail, open **Agents** and choose **+ New Chat Session** (or use **+** on the chat session tab strip).
2. Pick a **mode** in the composer footer (Ask, Plan, or Agent).
3. Choose a **model** from the combo beside it.
4. Type a prompt and send.

Use **Ask** for questions without file writes. Use **Agent** when you want the assistant to edit the project.

## Where to learn more

- **Workspace layout and panels** — navigation, center tabs, utility panel, terminal.
- **Chat, sessions, and modes** — parallel sessions, archive, mode differences.
- **How the agent works** — what happens after you press Send (educational overview).
