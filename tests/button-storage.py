#!/usr/bin/env python3
"""収納binの実STLで26穴、3mm面、連続底、積み重ねを確認する。"""

from itertools import combinations
from math import hypot
from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, inside, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/leverless/button_storage.scad"

with tempfile.TemporaryDirectory(prefix="button-storage-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "button_storage.scad is missing"
    upper, lower = work / "upper.stl", work / "lower.stl"
    render(SOURCE, upper, ('part="upper"',), binary=True)
    render(SOURCE, lower, ('part="lower"',), binary=True)
    near(bounds(closed_mesh(upper)), (-73.25, 73.25, 0, 209.5, 0, 11.4))
    near(bounds(closed_mesh(lower)), (-73.25, 73.25, 0, 209.5, 0, 25.4))

    # 中心は形状から抽出し、穴の全周を測る。echoやSCADの座標表は信用しない。
    loops = section(upper, work, "z", 1.5)
    assert len(loops) == 27, "need one joined base and 26 holes"
    holes = []
    for loop in loops:
        x0, x1, y0, y1 = bounds(loop)
        if x1 - x0 > 40:
            continue
        x, y = (x0 + x1) / 2, (y0 + y1) / 2
        d = 24.4 if x1 - x0 < 28 else 30.4
        near((x1 - x0, y1 - y0), (d, d))
        assert all(abs(hypot(px - x, py - y) - d / 2) < 0.02 for px, py in loop)
        holes.append((x, y, d, 29 if d == 24.4 else 34))
    assert sum(d == 24.4 for _, _, d, _ in holes) == 24
    assert sum(d == 30.4 for _, _, d, _ in holes) == 2
    for a, b in combinations(holes, 2):
        assert hypot(a[0] - b[0], a[1] - b[1]) >= (a[3] + b[3]) / 2 - 0.005, "flanges overlap"
    for x, y, d, flange in holes:
        assert -70.25 < x - flange / 2 < x + flange / 2 < 70.25
        assert 3 < y - flange / 2 < y + flange / 2 < 206.5
    near((max(x + f / 2 for x, y, d, f in holes) - min(x - f / 2 for x, y, d, f in holes),
          max(y + f / 2 for x, y, d, f in holes) - min(y - f / 2 for x, y, d, f in holes)),
         (130.5, 185.037946))
    for z in (0.05, 2.99):
        loops = section(upper, work, "z", z)
        assert len(loops) == 27, "cell seams must be filled"
        assert inside(loops, (66, 41.75)), "base disconnected at cell seam"
        assert all(not inside(loops, (x, y)) for x, y, _, _ in holes)
    for z in (3.01, 6, 10):
        loops = section(upper, work, "z", z)
        assert len(loops) == 2 and not inside(loops, (66, 41.75)), "plate thicker than 3mm"
    assert len(section(lower, work, "z", 2)) == 20, "lower needs 20 grid feet including half cells"
    assert inside(section(lower, work, "z", 5.94), (0, 104.75))
    assert not inside(section(lower, work, "z", 5.96), (0, 104.75))

    # 最小立方体だけが残れば、実形状の上下には体積交差がない。
    source, target = work / "fit.scad", work / "fit.stl"
    source.write_text(f'translate([200,0,0]) cube(1);\nintersection() {{ import("{lower}"); translate([0,0,21.1]) import("{upper}"); }}\n')
    render(source, target, binary=True)
    near(bounds(closed_mesh(target)), (200, 201, 0, 1, 0, 1))

    # 公式寸法図: フランジ下面から17mm、上面側4.2mm。本体径23.6/29.5。
    # 縁は公式図の26/32より大きい依頼値29/34で包絡する。
    buttons = "\n".join(
        f'translate([{x},{y},7.1]) cylinder(d={23.6 if d == 24.4 else 29.5},h=16.99,$fn=96);'
        f'translate([{x},{y},24.11]) cylinder(d={f - 0.01},h=4.19,$fn=96);'
        for x, y, d, f in holes)
    source.write_text(f'translate([200,0,0]) cube(1);\nintersection() {{ union() {{ import("{lower}"); translate([0,0,21.1]) import("{upper}"); }} union() {{ {buttons} }} }}\n')
    render(source, target, binary=True)
    near(bounds(closed_mesh(target)), (200, 201, 0, 1, 0, 1))
    print("button-storage: 26 through holes, flange spacing, 3mm joined plate, standard lower bin and stack clearance passed")
