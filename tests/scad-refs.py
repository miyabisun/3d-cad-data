#!/usr/bin/env python3
"""assets/ と modules/ の SCAD は modules/ だけを use/include する。

scad-live は modules/ の変更でだけ全 assets を作り直し、assets/ の変更ではその1ファイルだけを作り直す。
modules/ 以外への参照は、参照元の3MFを古いまま残す。
"""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MODULES = ROOT / "modules"
REF = re.compile(r"(?:use|include)\s*<([^>]+)>")

sources = sorted([*(ROOT / "assets").rglob("*.scad"), *MODULES.rglob("*.scad")])
bad = [(scad.relative_to(ROOT).as_posix(), ref)
       for scad in sources for ref in REF.findall(scad.read_text())
       if not (scad.parent / ref).resolve().is_relative_to(MODULES)]
assert not bad, bad
print(f"SCAD references: {len(sources)} files use/include only modules/ OK")
