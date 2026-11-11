# Workspace layout and panels

The main window is an IDE-style layout: navigation on the left, a tabbed center area, optional side panels, and an optional bottom terminal.

## Title bar

The main window uses a **custom title bar** (no native OS caption or window buttons) so the chrome looks the same on Windows, Linux, and macOS:

- **Owl logo** on the left (embedded in the app).
- **Application menu** (File, View, Workspace, …) in the same strip.
- **Minimize, maximize, and close** on the right, drawn by the LCA theme.
- **Drag** the title bar (logo area, menu background, or empty space to the right of the menus) to move the window. **Double-click** that area to maximize or restore.
- **Resize** by dragging the outer edge of the main window (within a few pixels of the border). On **Windows**, the OS handles this natively. On **macOS (Cocoa)**, the window uses AppKit’s resizable unified chrome (transparent title bar, custom LCA strip) so edge resize behaves like a normal desktop window; title-bar drags use AppKit window drag. On **Linux (GTK2)**, the app tracks the pointer to move or resize the frameless window; **GTK3** builds can use the toolkit’s native move/resize when available.

### Manual check (Linux / macOS)

After building on GTK2 or Cocoa, verify: drag the title bar to move; double-click the title strip to maximize/restore; use min/max/close; open a menu flyout and a keyboard shortcut; toggle light/dark theme; drag a window edge to resize. On **macOS**, also confirm the window is not stuck at a fixed size after install from a release build.
- **Detached panels** still use the normal system title bar on their floating windows.

## Navigation rail

The narrow left **activity bar** switches views:

- **Workspace** — registered workspaces list. Select one to switch the active project. **+ New Workspace** opens the new-workspace flow. **Remove from List** (or **Delete** with a row selected) drops the workspace from LazyCodingAgent only; you can remove all entries until the list is empty. The folder on disk and saved chat sessions in app config are kept.
- **Projects** — file tree for the workspace. **Right-click** a file or folder for **Open in Lazy Coding Agent** (files only; same as double-click), **Open in File Manager** (reveal in the OS file browser), or **Open with Default Application** (OS default handler). On Linux, revealing a file in the file manager uses the desktop’s FileManager1 service when available; otherwise the parent folder may open without a guaranteed selection.
- **Sessions** — chat session list (active and archived). **Right-click** a session for **Archive Session**, **Restore Session**, or **Permanently Delete...** (chat data only; project files are not touched). **Delete** with a row selected also permanently deletes that session.
- **Bots** — agent presets and prompt setups.
- **Tools & Logs** — per-step execution log for the active session: user prompts, model steps (`Step N/M · Model:`), and each tool’s input/output (`Step N/M · tool_name(...)`). Click a row to open **Execution Detail**; during an active run new rows follow into that panel until you select an older row.
- **Tasks & Plans** — session task list from the todo tool.
- **Tool Errors** — failed tool calls for the active session (click a row for full arguments and output). The subtitle shows the on-disk log path; hover for the full path.

Icons are tooltipped; the active rail button stays **down** (speed-button group).

## Roadmap setup dialogs (Workspace menu)

Four planned capabilities open as **modal setup dialogs** from the **Workspace** menu (same pattern as **Project Rules**). Each dialog shows a **COMING SOON** banner, disabled preview controls, and a read-only roadmap list. Nothing is saved and no backend runs yet.

| Menu item | Purpose |
| --- | --- |
| **Multi-Agent Workspace…** | Preview agent roles and workflow configuration. |
| **Execution Plans…** | Preview project-level numbered plans and a central tracker (not the same as **Tasks & Plans** on the nav rail, which lists live session todos from the agent todo tool). |
| **Workspace Knowledge Base…** | Preview knowledge sources and indexing. |
| **The Brain…** | Preview optional learning and memory settings. |

The **Workspace** menu also lists navigation shortcuts (Workspace, Projects, Agents, …) that switch the left panel; roadmap items above are separate configuration entry points.

### Tool error log file

Failures are also appended to `tool-errors.log` under the same user config folder as chat sessions (`lazycodingagent` beside session storage). The path is resolved at runtime on **Windows, Linux, and macOS** (see the Tool Errors panel subtitle). The file is JSONL (one JSON object per line). Clearing the panel only clears the in-memory list for the current session; delete the file manually if you want to reset the on-disk history.

## Center area

The center header tab strip switches three **PageControl** pages (no **+** on this strip):

- **Chat** — a **session tab strip** under the page header lists every non-archived chat (**+** for new session, **✕** to archive). Below that: conversation history rendered as **Markdown** (headings, bold, code, lists — subset, not full GFM), current session label, composer, mode and model combos, Stop and Run.
- **Editor** — one `SynEdit` buffer for the file you opened from Projects (prompted to save if dirty before replacing). Font size scales with display DPI. Use normal mouse selection and **Ctrl+C** / **Ctrl+A** (and other standard SynEdit shortcuts) to copy code.
- **Markdown** — formatted preview when you open a `.md` file and choose **Preview** (same HTML renderer as chat). Choose **Source** to edit in the Editor tab.

There are **no** per-file editor tabs. Switch sessions from the Chat session tabs or **Sessions** in the nav rail; open another file from **Projects**.

## Right and utility panels

- **Guidelines / instructions** — workspace context on the right when enabled.
- **Utility panel** — `PageControl` with **Execution Detail** and **Plan**. Toggle via **Window → Panels → Utility Panel**. **Execution Detail** shows the selected log step as Markdown (section headings, fenced JSON, and prose blocks) in the same canvas Markdown view used elsewhere. **Plan** lists each open plan file as a **closable tab** (filename); switch tabs to change which plan is shown. The header shows the active plan path, a model picker, and **Build** (implements that plan in a new Agent session); the body renders the active plan as markdown.

## Panel visibility and detach

Use **✕** on navigation, guidelines, utility, or terminal panel headers, or **Window → Panels**, to show or hide those areas. The **center (chat / editor / markdown)** area has **⧉ detach** on its header but no **✕** — hide the chat panel from **Window → Panels** only. Layout and visibility persist when you restart the app.

Use **⧉** on navigation, chat, guidelines, utility, and terminal headers to **detach** the panel into a floating window (position and size are saved). Close the float window or click **⧉** again to re-dock.

## Terminal

**View → Terminal** opens a bottom dock with a real shell in the **workspace root**. Resize with the splitter above the status bar. On Linux, the embedded terminal needs PTY support (see README).

## Theme

**View → Toggle Light / Dark Theme** switches the in-app palette. The **application menu** lives in the custom title bar (`TLcaThemedTitleBar` / `TLcaThemedMenuBar`) on all platforms—not the macOS screen menu bar.

**Painted LCA chrome** on the main window (all platforms): navigation rail buttons, panel chrome buttons, chat/plan combos and send/stop buttons, navigation file/log/error lists, tab strips, and chat/plan markdown preview. Those controls use `LcaTheme` tokens and custom paint so they look the same on Windows, Linux, and macOS.

**Native islands** (stock LCL / OS styling where noted):

- **Code editor** (`TSynEdit`) — syntax colors via theme hooks; scrollbars follow the OS.
- **Chat prompt** (`TMemo`) — native text field and scrollbars.
- **Projects tree** (`TTreeView`) — native tree widget.
- **Terminal** (`TLcaTerminalPanel`) — embedded shell view; terminal scrollbars follow the OS.
- **Settings and dialogs** — use the same painted buttons and combos as the main window (`TLcaPaintButton`, `TLcaPaintComboBox`).

**Scrollbars:** Chat history, plan body, and navigation lists use **LCA-painted** scrollbars. The editor, prompt, tree, and terminal use **OS widget** scrollbars. Menu dropdowns may follow the OS theme even when the title bar is themed.

## Tips

- Use splitters between panels to resize.
- Combo **Height** is set in the Lazarus form (chat footer, plan header, Settings). Theme styling does not override that size; if a combo looks wrong after a resize, try toggling theme once.
