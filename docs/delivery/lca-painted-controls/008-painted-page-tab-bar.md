# 008 — Painted page tab bar

**Depends on:** [002](002-layout-metrics-tokens.md), [006](006-painted-button.md)

## Goal

Align [`TLcaThemedPageTabBar`](../../../packages/LcaDesignSystem/src/LcaThemedPageTabBar.pas) tab strip painting with centralized metrics and the painted-control patterns (or introduce `TLcaPaintPageTabBar` and keep the old component until migration).

## Scope

- Tab height, padding, active/inactive colors from `ThemePalette` + layout tokens.
- Still drives a `TPageControl` with `ShowTabs = False` via existing `PageControl` property pattern.
- No change to tab sheet content layout (`Align = alClient` on sheets).
- **Palette icon:** if a new tab bar class is registered, add glyph per [PALETTE-ICONS.md](PALETTE-ICONS.md); if only refactoring `TLcaThemedPageTabBar`, add/update `TLcaThemedPageTabBar.png` in this step or defer to 012 backfill if the class name is unchanged.

## Out of scope

- Custom-drawing `TPageControl` pages.
- Center/utility tab content restructure.

## Touch list

- `LcaThemedPageTabBar.pas` and/or new paint tab bar unit
- `LcaDesignReg.pas` if new type

## Verification

1. Main or test form: switch center/utility tabs; active tab indicator correct.
2. Resize: tab strip height stable per metrics.
3. Dark/light toggle.
4. **LCA Design** palette shows a custom icon for the tab bar component class.

## Done when

Tab strip metrics and paint are independent of native tab widget theming on Linux/macOS; palette icon present and distinct.
