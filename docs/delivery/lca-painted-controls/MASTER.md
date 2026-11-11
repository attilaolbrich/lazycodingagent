# LCA painted controls — delivery master

**Git branch:** `feature/lca-painted-controls`

Progressive delivery of theme-aware, custom-painted LCA components for consistent layout and chrome across platforms. Implementation order is fixed by difficulty and feasibility (foundation → scroll host → chrome → app migration).

## Rules

1. **One delivery per session** — An agent may implement **at most one** unchecked item in the progress list below. Do not start the next step in the same session.
2. **Stop after delivery** — When the active step’s scope is complete (per its step file), the agent must:
   - Change **only that** line in this file from `- [ ]` to `- [x]`.
   - **Stop** — no further implementation or follow-on steps until you instruct the next delivery.
3. **Manual QA gate** — You run manual testing (and optional fixes) after each step before saying “implement delivery 00N” or “next step”.
4. **Strict order** — Complete steps in numeric order unless you explicitly reprioritize and edit this file.
5. **Branch** — Keep implementation commits on `feature/lca-painted-controls` until merge.
6. **Palette icons** — Every class registered on the **LCA Design** palette must have a **dedicated Lazarus component icon** (not the generic default). Add the glyph in the **same delivery** that registers the class. See [PALETTE-ICONS.md](PALETTE-ICONS.md). **Backfill** icons for pre-existing palette types is required in step **012** before that step may be ticked complete.

## Current status

Step 012 complete. Painted-controls delivery track is finished on this branch.

## Progress

- [x] [001 — Themed control base](001-themed-control-base.md)
- [x] [002 — Layout metrics tokens](002-layout-metrics-tokens.md)
- [x] [003 — Paint surface](003-paint-surface.md)
- [x] [004 — Window chrome button base](004-window-chrome-button-base.md)
- [x] [005 — Scroll host](005-scroll-host.md)
- [x] [006 — Painted button](006-painted-button.md)
- [x] [007 — Painted nav rail button](007-painted-nav-rail-button.md)
- [x] [008 — Painted page tab bar](008-painted-page-tab-bar.md)
- [x] [009 — Painted combo box](009-painted-combo-box.md)
- [x] [010 — Markdown scroll integration](010-markdown-scroll-integration.md)
- [x] [011 — Painted nav list](011-painted-nav-list.md)
- [x] [012 — App migration and docs](012-app-migration-and-docs.md)

## Out of scope (future initiative)

- Full `TSynEdit` replacement
- Custom multiline editor (prompt `TMemo`)
- Terminal repaint (`TLcaTerminalPanel`)
- System file dialogs
