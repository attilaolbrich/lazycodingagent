# 007 — Painted nav rail button

**Depends on:** [006 — Painted button](006-painted-button.md)

## Goal

Nav rail cell control with parity to [`TLcaNavRailButton`](../../../packages/LcaDesignSystem/src/LcaNavRailButton.pas): `NavCaption`, `Active` state, themed icon/caption paint on the shared stack.

## Scope

- New type (e.g. `TLcaPaintNavRailButton`) on `TLcaThemedControl` or shared button paint helpers from 006.
- Designer-visible default appearance when `csDesigning`.
- Published: `ThemeKind`, `NavCaption`, `Active`.
- Keep `TLcaNavRailButton` on [`mainunit.lfm`](../../../mainunit.lfm) until step 012.
- **Palette icon:** for the new nav rail class per [PALETTE-ICONS.md](PALETTE-ICONS.md).

## Out of scope

- Wiring main form navigation tags / `TNavigationItem` map.
- Replacing `TSpeedButton` elsewhere.

## Touch list

- New unit under `packages/LcaDesignSystem/src/`
- `LcaDesignReg.pas`

## Verification

1. Test form: toggle `Active`; dark/light theme.
2. Designer: readable on dark-first `.lfm` backgrounds.
3. Click raises `OnClick` reliably.
4. **LCA Design** palette shows custom icon for the new nav rail component.

## Done when

Nav rail painted control matches existing nav button UX closely enough for migration in step 012; palette icon present and distinct from `TLcaNavRailButton`.
