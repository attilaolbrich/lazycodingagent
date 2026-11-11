# 005 — Scroll host

**Depends on:** [001](001-themed-control-base.md), [002](002-layout-metrics-tokens.md)

## Goal

Implement **`TLcaScrollHost`**: a themed container that paints **custom scrollbars**, hosts a single viewport child, and handles wheel/trackpad scrolling with **fixed** bar thickness from layout metrics.

## Scope

- `TCustomControl` or `TLcaThemedControl` descendant.
- Viewport `ClientRect` inset by visible scrollbars; content child `Align` or explicit bounds—**one geometry owner** (no `Align` + conflicting `SetBounds` on the same control).
- Paint vertical/horizontal bars from `ThemePalette`; thumb track, drag, page click (minimum viable interaction).
- API: `Content: TControl` or require child at design time; document pattern in unit header.
- Inner scrollable hosts use `ScrollBars := ssNone` when wrapping native controls later.
- Register on **LCA Design** palette with **palette icon** per [PALETTE-ICONS.md](PALETTE-ICONS.md) (`TLcaScrollHost.png` or final class name).

## Out of scope

- Integrating markdown or lists (steps 010–011).
- Replacing `TScrollBox` app-wide.

## Touch list

- New `packages/LcaDesignSystem/src/LcaScrollHost.pas`
- `LcaDesignSystem.lpk`, `LcaDesignReg.pas`

## Verification

1. Test form: tall `TPanel` or label stack inside `TLcaScrollHost`; scroll via wheel and dragging thumb.
2. Dark/light themes: bar/track colors match palette; bar width matches metric constant on Windows and Linux (Qt5).
3. Resize host: layout stable, no `ChangeBounds` loop.
4. Rebuild IDE design package; **LCA Design** palette shows custom icon for `TLcaScrollHost`.

## Done when

`TLcaScrollHost` is on the palette with a distinct custom icon and provides cross-platform scrollbar chrome independent of GTK/Qt native bars.
