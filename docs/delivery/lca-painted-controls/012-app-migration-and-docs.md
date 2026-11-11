# 012 — App migration and docs

**Depends on:** [003](003-paint-surface.md) through [011](011-painted-nav-list.md)

## Goal

Incrementally migrate **pilot** UI on the main form to painted components where ready, and document the **native island** policy (editor, terminal, prompt memo).

## Scope

- [`mainunit.lfm`](../../../mainunit.lfm) / helpers: swap selected controls (e.g. surfaces, nav rail, buttons, combos, lists, markdown host) per prior steps—**minimal diff**, designer-owned layout.
- Update [`packages/LcaDesignSystem/README.md`](../../../packages/LcaDesignSystem/README.md) palette table for new types.
- User help per workspace rule: [`help/index.json`](../../../help/index.json) and relevant topics (e.g. UI/overview) — note painted chrome vs native editor/terminal.
- README cross-platform note: painted scrollbars/chrome; Qt5 Linux recommended.
- **Palette icon backfill:** Add dedicated glyphs for all **pre-existing** LCA Design classes that still use default IDE icons (see list in [PALETTE-ICONS.md](PALETTE-ICONS.md)); wire `res/glyphs/`, `lazres`, and design package resources. Document **Palette icons** in [`packages/LcaDesignSystem/README.md`](../../../packages/LcaDesignSystem/README.md) with link to [PALETTE-ICONS.md](PALETTE-ICONS.md) and rebuild-IDE note.

## Out of scope

- `TSynEdit`, `TLcaTerminalPanel`, `memChatPrompt` replacement.
- Removing legacy `TLcaThemedButton` / `TLcaSurfacePanel` unless all call sites migrated.

## Touch list

- `mainunit.lfm`, `uChatPanel.pas`, `uNavigationPanel.pas` (as needed)
- `packages/LcaDesignSystem/README.md`
- `packages/LcaDesignSystem/res/glyphs/`, `LcaDesignSystemDesign.lpk`, `LcaDesignReg.pas` (glyph resources)
- `help/*.md`, `help/index.json`

## Verification

1. `lazbuild --widgetset=qt5 lazycodingagent.lpi` succeeds.
2. Full manual pass: nav, chat scroll, composer combos/buttons, utility tabs, theme toggle, resize, detach panels if used.
3. Help menu: new/updated topic renders in preview.
4. No `ChangeBounds loop detected` during normal use.
5. Lazarus **LCA Design** palette: **every** registered class (legacy + new painted types) shows a **custom** icon per [PALETTE-ICONS.md](PALETTE-ICONS.md).

## Done when

Main app uses painted stack for agreed pilot areas; docs describe what remains native and how delivery gates worked on `feature/lca-painted-controls`; **all** LCA Design palette entries have dedicated IDE icons (including backfill).
