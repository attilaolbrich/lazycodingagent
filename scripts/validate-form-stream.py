#!/usr/bin/env python3
"""Verify Lazarus form .pas published field order matches .lfm depth-first stream order.

Settings designer note: empty TListView Columns with vsReport blocked the IDE; use design-time
columns in frmSettings.lfm (runtime RefreshWebSearchConnectionList replaces them).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

OBJECT_RE = re.compile(r"^\s*object\s+(\w+)\s*:\s*(\S+)")
FIELD_RE = re.compile(r"^\s+(\w+)\s*:\s*T\w+")


def lfm_dfs_component_names(lfm_path: Path) -> list[str]:
    lines = lfm_path.read_text(encoding="utf-8").splitlines()
    names: list[str] = []
    for line in lines:
        m = OBJECT_RE.match(line)
        if not m:
            continue
        name, cls = m.group(1), m.group(2)
        if cls.endswith("Form") and name.endswith("Form"):
            continue  # root form object
        names.append(name)
    return names


def pas_published_field_names(pas_path: Path, form_class: str) -> list[str]:
    text = pas_path.read_text(encoding="utf-8")
    # Find class block
    class_pat = rf"\b{re.escape(form_class)}\s*=\s*class\s*\(\s*TForm\s*\)"
    m = re.search(class_pat, text)
    if not m:
        raise SystemExit(f"Class {form_class} not found in {pas_path}")
    start = m.end()
    private_m = re.search(r"^\s+private\b", text[start:], re.MULTILINE)
    if not private_m:
        raise SystemExit(f"No private section in {form_class}")
    block = text[start : start + private_m.start()]
    block = re.sub(r"^\s*published\s*$", "", block, flags=re.MULTILINE)

    names: list[str] = []
    for line in block.splitlines():
        fm = FIELD_RE.match(line)
        if fm:
            names.append(fm.group(1))
        elif re.match(r"^\s+procedure\b", line):
            break  # event handlers follow components
    return names


def reorder_pas_published_fields(pas_path: Path, lfm_path: Path, form_class: str) -> None:
    lfm_names = lfm_dfs_component_names(lfm_path)
    text = pas_path.read_text(encoding="utf-8")
    class_pat = rf"\b{re.escape(form_class)}\s*=\s*class\s*\(\s*TForm\s*\)"
    m = re.search(class_pat, text)
    if not m:
        raise SystemExit(f"Class {form_class} not found")
    start = m.end()
    private_m = re.search(r"^\s+private\b", text[start:], re.MULTILINE)
    if not private_m:
        raise SystemExit("No private section")
    block = text[start : start + private_m.start()]
    block = re.sub(r"^\s*published\s*$", "", block, flags=re.MULTILINE)
    types: dict[str, str] = {}
    for fm in re.finditer(r"^\s+(\w+):\s*(T\S+);", block, re.MULTILINE):
        types[fm.group(1)] = fm.group(2)
    missing = [n for n in lfm_names if n not in types]
    if missing:
        raise SystemExit(f"Published fields missing in .pas: {', '.join(missing)}")
    new_fields = "  published\n" + "\n".join(f"    {n}: {types[n]};" for n in lfm_names) + "\n\n"
    proc_m = re.search(r"^\s+procedure\b", block, re.MULTILINE)
    if not proc_m:
        raise SystemExit("No published procedures in form class")
    tail = block[proc_m.start() :]
    new_block = "\n" + new_fields + tail
    new_text = text[:start] + new_block + text[start + private_m.start() :]
    pas_path.write_text(new_text, encoding="utf-8")


def validate_pair(pas_path: Path, lfm_path: Path, form_class: str) -> int:
    lfm_names = lfm_dfs_component_names(lfm_path)
    pas_names = pas_published_field_names(pas_path, form_class)
    if lfm_names == pas_names:
        print(f"OK: {pas_path.name} published order matches {lfm_path.name} ({len(lfm_names)} components)")
        return 0
    print(f"MISMATCH: {pas_path.name} vs {lfm_path.name}", file=sys.stderr)
    n = max(len(lfm_names), len(pas_names))
    for i in range(n):
        a = lfm_names[i] if i < len(lfm_names) else "<missing>"
        b = pas_names[i] if i < len(pas_names) else "<missing>"
        mark = " " if a == b else "!"
        print(f"  {mark} [{i}] LFM={a}  PAS={b}", file=sys.stderr)
    return 1


def main(argv: list[str]) -> int:
    fix_pas = "--fix-pas" in argv
    args = [a for a in argv if a != "--fix-pas"]
    if len(args) >= 3:
        pas_path = Path(args[1])
        lfm_path = Path(args[2])
        form_class = args[3] if len(args) >= 4 else pas_path.stem.replace("frm", "") + "Form"
        if form_class == "SettingsForm" or pas_path.stem == "frmSettings":
            form_class = "TSettingsForm"
        elif not form_class.startswith("T"):
            form_class = "T" + form_class
    else:
        pas_path = ROOT / "frmSettings.pas"
        lfm_path = ROOT / "frmSettings.lfm"
        form_class = "TSettingsForm"
    if not pas_path.is_file() or not lfm_path.is_file():
        print(
            "Usage: validate-form-stream.py [--fix-pas] [unit.pas unit.lfm [TFormClass]]",
            file=sys.stderr,
        )
        return 2
    if fix_pas:
        reorder_pas_published_fields(pas_path, lfm_path, form_class)
        print(f"Reordered published fields in {pas_path.name}")
    return validate_pair(pas_path, lfm_path, form_class)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
