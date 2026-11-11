#!/usr/bin/env python3
"""Generate Tools/Performance tab snippets for frmSettings.lfm from frame LFMs.

Legacy: source frame LFMs were removed after flattening. Do not patch frmSettings.lfm
from this script unless you restore fraWebSearchSettings.lfm / fraPromptCacheSettings.lfm.

After any .lfm merge, run:
  python scripts/validate-form-stream.py --fix-pas
  python scripts/validate-form-stream.py
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

WS_RENAMES = {
    "scrWebSearch": "scrToolsTab",
    "pnlWebSearchContent": "pnlToolsContent",
    "pnlWebSearchHeader": "pnlToolsHeader",
    "pnlConnections": "pnlToolsConnections",
    "pnlWebSearchFooter": "pnlToolsFooter",
    "pnlConnButtons": "pnlToolsConnButtons",
    "lblWebSearchTitle": "wsLblWebSearchTitle",
    "chkWebSearchEnabled": "wsChkWebSearchEnabled",
    "lblWebSearchEnabled": "wsLblWebSearchEnabled",
    "lblMaxResults": "wsLblMaxResults",
    "edtMaxResults": "wsEdtMaxResults",
    "lblTotalTimeout": "wsLblTotalTimeout",
    "edtTotalTimeoutSec": "wsEdtTotalTimeoutSec",
    "chkAutoFallback": "wsChkAutoFallback",
    "lblAutoFallback": "wsLblAutoFallback",
    "chkFallbackEmpty": "wsChkFallbackEmpty",
    "lblFallbackEmpty": "wsLblFallbackEmpty",
    "chkAllowPrivateInstances": "wsChkAllowPrivateInstances",
    "lblAllowPrivateInstances": "wsLblAllowPrivateInstances",
    "lblConnections": "wsLblConnections",
    "lvConnections": "wsLvConnections",
    "btnAddConn": "wsBtnAddConn",
    "btnEditConn": "wsBtnEditConn",
    "btnRemoveConn": "wsBtnRemoveConn",
    "btnTestConn": "wsBtnTestConn",
    "btnMoveUp": "wsBtnMoveUp",
    "btnMoveDown": "wsBtnMoveDown",
    "lblTestNote": "wsLblTestNote",
    "memoConnStatus": "wsMemoConnStatus",
}

WS_HANDLERS = {
    "lblToggleCheckClick": "wsLblToggleCheckClick",
    "btnAddConnClick": "wsBtnAddConnClick",
    "btnEditConnClick": "wsBtnEditConnClick",
    "btnRemoveConnClick": "wsBtnRemoveConnClick",
    "btnTestConnClick": "wsBtnTestConnClick",
    "btnMoveUpClick": "wsBtnMoveUpClick",
    "btnMoveDownClick": "wsBtnMoveDownClick",
    "lvConnectionsResize": "wsLvConnectionsResize",
}

PC_RENAMES = {
    "scrPromptCache": "scrPerformanceTab",
    "pnlContent": "pnlPerformanceContent",
    "lblTitle": "pcLblTitle",
    "lblHint": "pcLblHint",
    "chkEnabled": "pcChkEnabled",
    "lblEnabled": "pcLblEnabled",
    "grpMode": "pcGrpMode",
    "rbAutomatic": "pcRbAutomatic",
    "lblRbAutomatic": "pcLblRbAutomatic",
    "rbExplicit": "pcRbExplicit",
    "lblRbExplicit": "pcLblRbExplicit",
    "rbDisabled": "pcRbDisabled",
    "lblRbDisabled": "pcLblRbDisabled",
    "lblRetention": "pcLblRetention",
    "cboRetention": "pcCboRetention",
    "grpContent": "pcGrpContent",
    "chkSystem": "pcChkSystem",
    "lblChkSystem": "pcLblChkSystem",
    "chkTools": "pcChkTools",
    "lblChkTools": "pcLblChkTools",
    "chkProject": "pcChkProject",
    "lblChkProject": "pcLblChkProject",
    "chkHistory": "pcChkHistory",
    "lblChkHistory": "pcLblChkHistory",
    "grpStats": "pcGrpStats",
    "lblInputTokens": "pcLblInputTokens",
    "lblCachedTokens": "pcLblCachedTokens",
    "lblHitRatio": "pcLblHitRatio",
    "lblSavings": "pcLblSavings",
    "btnResetStats": "pcBtnResetStats",
}

PC_HANDLERS = {
    "lblToggleCheckClick": "pcLblToggleCheckClick",
    "lblSelectRadioClick": "pcLblSelectRadioClick",
    "btnResetStatsClick": "pcBtnResetStatsClick",
}

SCALE_PROPS = {
    "Left",
    "Top",
    "Width",
    "Height",
    "ClientHeight",
    "ClientWidth",
    "ItemHeight",
    "Font.Height",
}


def scale_line(line: str, factor: int) -> str:
    for prop in SCALE_PROPS:
        m = re.search(rf"(\s+{re.escape(prop)}\s*=\s*)(-?\d+)", line)
        if m:
            val = int(m.group(2)) * factor
            line = line[: m.start(2)] + str(val) + line[m.end(2) :]
    return line


def extract_scroll_subtree(lfm_text: str, scroll_name: str) -> str:
    """Return the scroll box object subtree (including its line)."""
    lines = lfm_text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if re.match(rf"\s*object\s+{scroll_name}:\s", line):
            start = i
            break
    if start is None:
        raise SystemExit(f"scroll object {scroll_name} not found")
    depth = 0
    out = []
    for line in lines[start:]:
        if re.match(r"\s*object\s+", line):
            depth += 1
        out.append(line)
        if line.strip() == "end":
            depth -= 1
            if depth == 0:
                break
    return "\n".join(out)


def indent_block(text: str, spaces: int) -> str:
    pad = " " * spaces
    return "\n".join(pad + line if line.strip() else line for line in text.splitlines())


def rename_objects(text: str, renames: dict) -> str:
    lines = []
    for line in text.splitlines():
        m = re.match(r"(\s*object\s+)(\w+)(:\s+\S+)", line)
        if m and m.group(2) in renames:
            line = m.group(1) + renames[m.group(2)] + m.group(3)
        for old, new in renames.items():
            line = re.sub(rf"\bOnClick\s*=\s*{old.replace('Click', '')}Click\b", f"OnClick = {new}", line)
        for old_h, new_h in renames.items():
            pass
        lines.append(line)
    return "\n".join(lines)


def apply_handlers(text: str, handlers: dict) -> str:
    for old, new in handlers.items():
        text = text.replace(f"OnClick = {old}", f"OnClick = {new}")
        text = text.replace(f"OnResize = {old}", f"OnResize = {new}")
    return text


def transform_ws(src: str) -> str:
    inner = extract_scroll_subtree(src, "scrWebSearch")
    lines = []
    for line in inner.splitlines():
        line = scale_line(line, 2)
        m = re.match(r"(\s*object\s+)(\w+)(:\s+\S+)", line)
        if m and m.group(2) in WS_RENAMES:
            line = m.group(1) + WS_RENAMES[m.group(2)] + m.group(3)
        lines.append(line)
    text = "\n".join(lines)
    text = apply_handlers(text, WS_HANDLERS)
    text = text.replace("Width = 1440", "Width = 1068")
    text = text.replace("ClientWidth = 1440", "ClientWidth = 1068")
    return text


def transform_pc(src: str) -> str:
    inner = extract_scroll_subtree(src, "scrPromptCache")
    lines = []
    for line in inner.splitlines():
        # prompt cache frame already ~192; nudge left margin 24->32
        line = scale_line(line, 1)
        if re.search(r"\s+Left = 24\b", line):
            line = re.sub(r"(\s+Left = )24\b", r"\g<1>32", line)
        m = re.match(r"(\s*object\s+)(\w+)(:\s+\S+)", line)
        if m and m.group(2) in PC_RENAMES:
            line = m.group(1) + PC_RENAMES[m.group(2)] + m.group(3)
        if "Caption = 'Mode'" in line or 'Caption = \'Mode\'' in line:
            line = "        Caption = ''"
        if "Caption = 'Cacheable content'" in line:
            line = "        Caption = ''"
        if "Caption = 'Cache statistics (session cumulative)'" in line:
            line = "        Caption = ''"
        lines.append(line)
    text = "\n".join(lines)
    text = apply_handlers(text, PC_HANDLERS)
    # Insert section labels before group boxes
    section_mode = """      object lblPcSectionMode: TLabel
        Left = 32
        Height = 36
        Top = 160
        Width = 120
        Caption = 'Mode'
      end
"""
    section_content = """      object lblPcSectionContent: TLabel
        Left = 32
        Height = 36
        Top = 412
        Width = 280
        Caption = 'Cacheable content'
      end
"""
    section_stats = """      object lblPcSectionStats: TLabel
        Left = 32
        Height = 36
        Top = 628
        Width = 520
        Caption = 'Cache statistics (session cumulative)'
      end
"""
    text = text.replace(
        "      object pcGrpMode: TGroupBox",
        section_mode + "      object pcGrpMode: TGroupBox",
    )
    text = text.replace(
        "      object pcGrpContent: TGroupBox",
        section_content + "      object pcGrpContent: TGroupBox",
    )
    text = text.replace(
        "      object pcGrpStats: TGroupBox",
        section_stats + "      object pcGrpStats: TGroupBox",
    )
    # Shift group tops down for section labels
    text = text.replace("object pcGrpMode: TGroupBox\n        Left = 32\n        Height = 140\n        Top = 168",
                        "object pcGrpMode: TGroupBox\n        Left = 32\n        Height = 140\n        Top = 200")
    text = text.replace("object pcGrpContent: TGroupBox\n        Left = 32\n        Height = 200\n        Top = 420",
                        "object pcGrpContent: TGroupBox\n        Left = 32\n        Height = 200\n        Top = 452")
    text = text.replace("object pcGrpStats: TGroupBox\n        Left = 32\n        Height = 220\n        Top = 636",
                        "object pcGrpStats: TGroupBox\n        Left = 32\n        Height = 220\n        Top = 668")
    text = text.replace("Width = 780", "Width = 1068")
    text = text.replace("ClientWidth = 780", "ClientWidth = 1068")
    text = text.replace("Width = 800", "Width = 1068")
    text = text.replace("ClientWidth = 800", "ClientWidth = 1068")
    return text


def patch_frm_settings_lfm(tools_tab: str, perf_tab: str) -> None:
    """Replace tsTools..tsPerformance sections inside pgcSettings (keeps 6-space tab indent)."""
    frm = ROOT / "frmSettings.lfm"
    text = frm.read_text(encoding="utf-8")
    start = text.index("      object tsTools: TTabSheet")
    end = text.index("      object tsWorkspace: TTabSheet")
    if not tools_tab.strip().startswith("object tsTools:"):
        raise SystemExit("tools_tab must start with '      object tsTools'")
    new_body = tools_tab.rstrip() + "\n" + perf_tab.rstrip() + "\n"
    frm.write_text(text[:start] + new_body + text[end:], encoding="utf-8")


def run_form_stream_validator() -> None:
    script = ROOT / "scripts" / "validate-form-stream.py"
    for cmd in (
        [sys.executable, str(script), "--fix-pas"],
        [sys.executable, str(script)],
    ):
        subprocess.run(cmd, cwd=ROOT, check=True)


def main():
    ws_lfm = ROOT / "fraWebSearchSettings.lfm"
    pc_lfm = ROOT / "fraPromptCacheSettings.lfm"
    if not ws_lfm.is_file() or not pc_lfm.is_file():
        print(
            "Frame LFMs not found; flatten is complete. Edit frmSettings.lfm in the IDE "
            "or restore frame LFMs to regenerate.",
            file=sys.stderr,
        )
        raise SystemExit(1)
    ws_body = transform_ws(ws_lfm.read_text(encoding="utf-8"))
    pc_body = transform_pc(pc_lfm.read_text(encoding="utf-8"))
    ws_ind = indent_block(ws_body, 8)
    pc_ind = indent_block(pc_body, 8)
    tools_tab = f"""      object tsTools: TTabSheet
        Caption = 'Tools'
        ClientHeight = 1032
        ClientWidth = 1068
{ws_ind}
      end
"""
    perf_tab = f"""      object tsPerformance: TTabSheet
        Caption = 'Performance'
        ClientHeight = 1032
        ClientWidth = 1068
{pc_ind}
      end
"""
    out = ROOT / "scripts" / "_settings_tabs_generated.lfm"
    out.write_text(tools_tab + "\n" + perf_tab, encoding="utf-8")
    print(f"Wrote {out}")
    if "--patch" in sys.argv:
        patch_frm_settings_lfm(tools_tab, perf_tab)
        print("Patched frmSettings.lfm")
        run_form_stream_validator()


if __name__ == "__main__":
    main()
