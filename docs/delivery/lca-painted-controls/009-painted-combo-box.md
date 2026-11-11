# 009 — Painted combo box

**Depends on:** [002](002-layout-metrics-tokens.md), [006](006-painted-button.md)

## Goal

**Closed field + custom dropdown popup** combo (e.g. `TLcaPaintComboBox`) to end native `TComboBox` preferred-height fights while keeping **`.lfm` `Height` / `ItemHeight`** as the geometry source of truth.

## Scope

- Painted closed state: text, chevron, focus ring (align with [`TLcaThemedComboBox`](../../../packages/LcaDesignSystem/src/LcaThemedComboBox.pas) properties where possible).
- Popup list: owner-painted items, keyboard navigation (arrows, enter, escape).
- `Items`, `ItemIndex`, `Text`, `OnChange` / `OnSelect` parity for chat mode/model use cases.
- Do not call `StyleComboBox` resizing on the new control type.
- **Palette icon:** `TLcaPaintComboBox.png` (or final class name) per [PALETTE-ICONS.md](PALETTE-ICONS.md).

## Out of scope

- Migrating chat composer combos in `mainunit` / [`uChatPanel.pas`](../../../uChatPanel.pas) (step 012).
- Editable combo (`csDropDown`) unless explicitly needed—start with drop-down list.

## Touch list

- New `LcaPaintComboBox.pas` (+ possible popup form/panel unit)
- `LcaDesignSystem.lpk`, `LcaDesignReg.pas`

## Verification

1. Test form: stream `Height`/`ItemHeight`; theme apply does not change height.
2. Open list, select item; no `ChangeBounds loop detected` on resize.
3. Dark/light; Linux Qt5 and Windows if available.
4. **LCA Design** palette shows custom icon for the paint combo class.

## Done when

Paint combo is palette-ready, satisfies the chat/settings combo layout contract from project rules, and has a distinct palette icon from `TLcaThemedComboBox`.
