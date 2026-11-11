# 011 — Painted nav list

**Depends on:** [005](005-scroll-host.md), [006](006-painted-button.md)

## Goal

Replace or supplement navigation **`TListBox`** (`lstNavFile`, `lstNavLog`, `lstNavErrors` in [`mainunit.lfm`](../../../mainunit.lfm)) with a painted list control (+ optional `TLcaScrollHost`).

## Scope

- New list component: items, selection, owner-draw rows using nav list metrics from [`LcaTheme.pas`](../../../packages/LcaDesignSystem/src/LcaTheme.pas) (`ThemedListBoxDrawItem` behavior as reference).
- Keyboard: up/down, enter if applicable.
- Hook points compatible with [`uNavigationPanel.pas`](../../../uNavigationPanel.pas) bindings (may require thin adapter in same step or minimal panel unit changes).
- Register on **LCA Design** palette with **palette icon** per [PALETTE-ICONS.md](PALETTE-ICONS.md).

## Out of scope

- File tree (`TTreeView`) replacement.
- Full main form migration (step 012).

## Touch list

- New list unit(s) under `packages/LcaDesignSystem/src/`
- Possibly `uNavigationPanel.pas` for binding API only—avoid layout `SetBounds` fights

## Verification

1. Nav lists show files/logs/errors with correct selection color (accent).
2. Scroll long file list via LCA scrollbars.
3. Resize nav panel; no bounds loop.
4. Dark/light theme.
5. **LCA Design** palette shows custom icon for the painted nav list class.

## Done when

Painted nav list is available and wired for at least one nav list in a test or feature branch build (full swap in 012 if not done here—document which in commit); palette icon present and distinct.
