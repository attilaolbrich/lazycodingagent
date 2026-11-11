# 003 — Paint surface

**Depends on:** [001](001-themed-control-base.md), [002](002-layout-metrics-tokens.md)

## Goal

Provide a **card surface** control on `TLcaThemedControl` with parity to [`TLcaSurfacePanel`](../../../packages/LcaDesignSystem/src/LcaSurfacePanel.pas) (background, optional accent border, themed paint).

## Scope

- New type (e.g. `TLcaPaintSurface`) inheriting `TLcaThemedControl`, or evolve surface logic into the base family without breaking existing `TLcaSurfacePanel`.
- **Keep** `TLcaSurfacePanel` on all current forms; new type is additive for migration in step 012.
- Register on **LCA Design** palette.
- **Palette icon:** `T<ClassName>.png` + design-time resource per [PALETTE-ICONS.md](PALETTE-ICONS.md).
- `Paint` uses palette `CardBg`, `Border`, `Text`; `ShowAccentBorder` or equivalent published property.

## Out of scope

- Replacing `TLcaSurfacePanel` instances in `mainunit.lfm`.
- Scroll host integration.

## Touch list

- New/updated units under `packages/LcaDesignSystem/src/`
- `LcaDesignSystem.lpk`, `LcaDesignReg.pas`

## Verification

1. Package and app build.
2. Drop `TLcaPaintSurface` on a test form: designer shows readable chrome; dark/light `ApplyTheme` works; **LCA Design** palette shows the surface’s custom icon.
3. Resize test form: no `ChangeBounds loop detected`.

## Done when

Paint surface component is palette-ready and behaviorally equivalent to `TLcaSurfacePanel` for theme/border rendering; palette icon present and distinct from sibling LCA components.
