# LCA Design — Lazarus palette icons

Every component on the **LCA Design** palette must show a **custom glyph** in the Lazarus IDE Component palette and Object Inspector tree. Generic LCL default icons are not acceptable for registered LCA types.

## When icons are required

| Situation | When to add the icon |
|-----------|----------------------|
| New painted control registered in a delivery step | Same step as `RegisterComponents` in [`LcaDesignReg.pas`](../../../packages/LcaDesignSystem/design/LcaDesignReg.pas) |
| Existing LCA types already on the palette | Step **012** backfill (see list below) |

## Asset specification

- **Size:** 24×24 px PNG (simple flat shape; readable on light and dark IDE chrome).
- **Filename:** exact Delphi class name, e.g. `TLcaPaintButton.png`.
- **Distinctness:** each LCA sibling on the palette should be visually distinguishable at palette size (button vs surface vs scroll vs list vs combo).
- **Storage (implementation):** `packages/LcaDesignSystem/res/glyphs/`.

## Build and wire-up (design-time only)

```text
PNG sources  →  lazres  →  .res resource  →  LcaDesignSystemDesign  →  IDE palette
```

1. Place PNGs under `packages/LcaDesignSystem/res/glyphs/`.
2. Build a resource file with Lazarus `lazres`, e.g. `lca_design_glyphs.res`, with resource names matching class names (same as PNG basename). Always rebuild from **all** PNGs in `res/glyphs/` (run `scripts/build-lca-glyphs.sh` / `.bat`); do not run `lazres` on a single new PNG only, or existing palette icons disappear from the `.res`.
3. Link the resource from the **design-time** package only:
   - [`LcaDesignSystemDesign.lpk`](../../../packages/LcaDesignSystem/LcaDesignSystemDesign.lpk) (include the `.res` in package files), and/or
   - `{$R lca_design_glyphs.res}` in [`LcaDesignReg.pas`](../../../packages/LcaDesignSystem/design/LcaDesignReg.pas) implementation.
4. Do **not** add `{$R ...}` glyph resources to the **runtime** [`LcaDesignSystem.lpk`](../../../packages/LcaDesignSystem/LcaDesignSystem.lpk) — icons are IDE-only.

Optional convenience (when implementing): `scripts/build-lca-glyphs.sh` that runs `lazres` over `res/glyphs/*.png`.

## IDE verification

After changing glyphs or registration:

1. Close Lazarus completely.
2. Rebuild/install: [`scripts/install-lca-lazarus.sh`](../../../scripts/install-lca-lazarus.sh) (or `.bat`) with your widgetset, including `--build-ide` when palette changes matter.
3. Open **Component** palette → **LCA Design**.
4. Confirm each listed class shows its **custom** icon.
5. Drop a control on a form; confirm the icon appears in the component selector where applicable.

## Existing palette classes — backfill in step 012

These are registered today and need dedicated icons before step 012 is complete:

- `TLcaThemedPageTabBar`
- `TLcaThemedButton`
- `TLcaThemedComboBox`
- `TLcaNavRailButton`
- `TLcaSurfacePanel`
- `TLcaMarkdownView`
- `TLcaTerminalPanel`
- `TLcaThemedMainMenu`
- `TLcaThemedMenuBar`
- `TLcaThemedTitleBar`

## New painted classes — icon in the same step as registration

| Delivery | Typical class |
|----------|----------------|
| 001 | `TLcaThemedControl` or designer-only stub, **if** registered on the palette |
| 003 | `TLcaPaintSurface` (or chosen surface class name) |
| 005 | `TLcaScrollHost` |
| 006 | `TLcaPaintButton` |
| 007 | `TLcaPaintNavRailButton` |
| 008 | `TLcaPaintPageTabBar` or updated `TLcaThemedPageTabBar` if re-registered |
| 009 | `TLcaPaintComboBox` |
| 011 | Painted nav list class (e.g. `TLcaPaintNavList`) |

Deliveries **002** and **004** do not require a new icon unless a new palette class is registered in that step.

## Documentation

Step **012** must update [`packages/LcaDesignSystem/README.md`](../../../packages/LcaDesignSystem/README.md) with a short **Palette icons** note pointing to this file and the rebuild-IDE requirement.
