# 002 — Layout metrics tokens

**Depends on:** [001 — Themed control base](001-themed-control-base.md)

## Goal

Centralize **fixed layout metrics** (scrollbar thickness, tab/button padding, default chrome heights) and scaling helpers so painted controls do not depend on native widget preferred sizes.

## Scope

- Extend [`LcaTheme.pas`](../../../packages/LcaDesignSystem/src/LcaTheme.pas) (or a small companion unit included by the package) with named constants and functions such as:
  - Scrollbar thickness (logical px, scaled)
  - Standard button/tab vertical metrics
  - Reuse or align with existing `ScaledThemedTabMetric` / `ScaledWindowChromeButtonWidth` patterns in [`LcaThemedWindowButton.pas`](../../../packages/LcaDesignSystem/src/LcaThemedWindowButton.pas)
- Document in code comments: **geometry owner** = streamed `.lfm` sizes + these tokens; theme routines must not fight layout (per workspace LCL layout rules).
- No visual change to the shipping app required in this step.
- **Palette icons:** none in this step unless a new component class is registered (see [PALETTE-ICONS.md](PALETTE-ICONS.md)).

## Out of scope

- New palette components.
- Replacing `EffectiveThemedComboBoxHeight` behavior for stock combos (until step 009).

## Touch list

- `packages/LcaDesignSystem/src/LcaTheme.pas` (and/or new `LcaLayoutMetrics.pas`)

## Verification

1. Package builds cleanly.
2. Existing app builds unchanged.
3. Spot-check: scaled metrics return consistent values at 96 DPI and after `ChangeScale` on a test control.

## Done when

Descendants can call shared metric helpers for step 005+ without duplicating magic numbers.
