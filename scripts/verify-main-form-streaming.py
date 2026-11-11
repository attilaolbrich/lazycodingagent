#!/usr/bin/env python3
"""Verify mainunit.pas published fields match mainunit.lfm depth-first order."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LFM = ROOT / "mainunit.lfm"
PAS = ROOT / "mainunit.pas"


def lfm_dfs(path: Path) -> list[str]:
    names: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"\s*object\s+(\w+):\s", line)
        if m:
            names.append(m.group(1))
            continue
        m = re.match(r"\s*inline\s+(\w+):\s", line)
        if m:
            names.append(m.group(1))
    # First object is the form; published fields skip it.
    if names and names[0] == "LazyCodingAgentForm":
        return names[1:]
    return names


def pas_published_fields(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    names: list[str] = []
    in_pub = False
    for line in text.splitlines():
        if re.match(r"\s*published\s*$", line):
            in_pub = True
            continue
        if in_pub and re.match(
            r"\s*(private|public|protected|strict private|strict protected)\s", line
        ):
            break
        if in_pub and re.match(r"\s*procedure\s", line):
            break
        if in_pub:
            m = re.match(r"\s*(\w+):\s", line)
            if m:
                names.append(m.group(1))
    return names


def main() -> int:
    lfm = lfm_dfs(LFM)
    pas = pas_published_fields(PAS)
    ok = True
    if len(lfm) != len(pas):
        ok = False
        print(f"Count mismatch: LFM={len(lfm)} PAS={len(pas)}")
    lfm_set, pas_set = set(lfm), set(pas)
    only_lfm = sorted(lfm_set - pas_set)
    only_pas = sorted(pas_set - lfm_set)
    if only_lfm:
        ok = False
        print("In LFM only:", only_lfm)
    if only_pas:
        ok = False
        print("In PAS only:", only_pas)
    mismatches = [(i, a, b) for i, (a, b) in enumerate(zip(lfm, pas)) if a != b]
    if mismatches:
        ok = False
        print(f"Order mismatches ({len(mismatches)}):")
        for i, a, b in mismatches[:20]:
            print(f"  [{i}] lfm={a!r} pas={b!r}")
        if len(mismatches) > 20:
            print(f"  ... and {len(mismatches) - 20} more")
    if ok:
        print(f"OK: {len(lfm)} published fields match LFM DFS order.")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
