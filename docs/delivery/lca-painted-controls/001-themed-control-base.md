# 001 — Themed control base

**Depends on:** none (first implementation step)

## Goal

Introduce `TLcaThemedControl`, a `TCustomControl` base for all future painted LCA components: shared `ThemeKind`, `ApplyTheme`, double-buffering, DPI scaling hook, and readable design-time appearance.

## Scope

- New unit in `packages/LcaDesignSystem/src/` (e.g. `LcaThemedControl.pas`).
- Published: `ThemeKind` (default `tkDark`), standard layout properties (`Align`, `Width`, `Height`, `Anchors` as appropriate).
- `ApplyTheme` uses `ThemePalette` / `EffectiveControlTheme` from [`LcaTheme.pas`](../../../packages/LcaDesignSystem/src/LcaTheme.pas).
- `ChangeScale` delegates to inherited behavior; prepare for shared metric helpers in step 002.
- Design-time: visible fill/border so forms remain editable in the Lazarus designer (similar spirit to [`LcaNavRailButton.pas`](../../../packages/LcaDesignSystem/src/LcaNavRailButton.pas) designer paint).
- Add unit to [`LcaDesignSystem.lpk`](../../../packages/LcaDesignSystem/LcaDesignSystem.lpk).
- Register on the **LCA Design** palette only if a concrete descendant or the base itself is useful in the designer; otherwise keep base abstract and register a minimal stub—document choice in the step PR/commit message.
- **Palette icon:** If registered, add `T<ClassName>.png` and wire glyphs per [PALETTE-ICONS.md](PALETTE-ICONS.md) in the same delivery.

## Out of scope

- Migrating existing components off `TPanel` / `TButton`.
- Scrollbars, buttons, or app form changes.

## Touch list

- `packages/LcaDesignSystem/src/LcaThemedControl.pas` (new)
- `packages/LcaDesignSystem/LcaDesignSystem.lpk`
- Optionally `packages/LcaDesignSystem/src/LcaDesignReg.pas`

## Verification

1. `lazbuild --widgetset=qt5 packages/LcaDesignSystem/LcaDesignSystem.lpk` (or project-standard widgetset) succeeds.
2. If registered: component appears on **LCA Design** palette with a **custom icon** (not generic LCL glyph); can drop on a test form and save `.lfm`.
3. Toggle dark/light in a host app or test form: base control updates colors without `ChangeBounds` warnings.

## Done when

`TLcaThemedControl` compiles, is wired into the design system package, and provides the shared theme/scaling contract documented in the unit for descendants in steps 003+. If palette-registered, its icon is present and distinct per [PALETTE-ICONS.md](PALETTE-ICONS.md).
