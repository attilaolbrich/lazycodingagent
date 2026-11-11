# 004 — Window chrome button base

**Depends on:** [001](001-themed-control-base.md), [002](002-layout-metrics-tokens.md)

## Goal

Refactor [`TLcaThemedWindowButton`](../../../packages/LcaDesignSystem/src/LcaThemedWindowButton.pas) to use the shared themed control base and layout metrics **without changing** minimize/maximize/close behavior or title bar layout.

## Scope

- Inherit from `TLcaThemedControl` (or shared mixin helpers) instead of duplicating theme/scale logic.
- `ScaledWindowChromeButtonWidth` should use step 002 helpers where appropriate.
- Preserve published properties and `.lfm` compatibility for [`LcaThemedTitleBar`](../../../packages/LcaDesignSystem/src/LcaThemedTitleBar.pas).

## Out of scope

- Title bar layout changes.
- New button roles.
- **Palette icons:** none unless a new palette class is registered (`TLcaThemedWindowButton` is not on the public palette today; see [PALETTE-ICONS.md](PALETTE-ICONS.md)).

## Touch list

- `packages/LcaDesignSystem/src/LcaThemedWindowButton.pas`
- Possibly `LcaThemedControl.pas`, `LcaTheme.pas`

## Verification

1. Build app with custom title bar (if enabled on your platform).
2. Hover/press min/max/close; window actions still work.
3. Toggle dark/light; button glyphs and hover fills match prior behavior.
4. High-DPI or fractional scaling: button width still scales predictably.

## Done when

Window chrome buttons share the painted-control foundation with no functional regression.
