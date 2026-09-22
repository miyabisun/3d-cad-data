#!/usr/bin/env python3
"""アクリル穴位置ゲージのSTLから基準面・穴中心・貫通を実測する。"""

from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/steel-rack/500x400/coupon_acrylic_hole.scad"

with tempfile.TemporaryDirectory(prefix="acrylic-hole-gauge-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "acrylic hole gauge is missing"
    for offsets, diameter, defines in [
        ([14, 14.5, 15, 15.5, 16, 16.5, 17, 17.5, 18], 4.2, ()),
        ([15.8, 16, 16.2], 4.4, ("offsets=[15.8,16,16.2]", "hole_diameter=4.4")),
    ]:
        stl = work / "gauge.stl"
        render(SOURCE, stl, defines, binary=True)
        length = len(offsets) * 10
        near(bounds(closed_mesh(stl)), (0, length, -12, 24, 0, 6))
        for z in [0.1, 1.9]:
            loops = section(stl, work, "z", z)
            for i, offset in enumerate(offsets):
                x, r = 5 + 10 * i, diameter / 2
                hole = loop_at(loops, (x - r, x + r, offset - r, offset + r))
                assert all(abs(((px - x) ** 2 + (py - offset) ** 2) ** 0.5 - r) < 0.02 for px, py in hole)
        # 5mm厚の板を支える面はZ=2。そこから4mmの立ち上がりの内面Y=0が測定基準。
        for z in [2.1, 5.9]:
            loops = section(stl, work, "z", z)
            assert len(loops) == 1, "unexpected material above the seating face"
            near(bounds(loops[0]), (0, length, -3, 0))
            empty_rect(loops, (0, length, 0, 24))
    print("acrylic-hole-gauge: one closed part, 14–18mm hole centers, through bores, datum face and fine-offset override passed")
