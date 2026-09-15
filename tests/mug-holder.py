#!/usr/bin/env python3
"""マグホルダーの実STLで収納寸法・排水・取付界面を測る。"""

import math
from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/mug-holder/mug_holder.scad"

with tempfile.TemporaryDirectory(prefix="mug-holder-test-") as temp:
    work = Path(temp)
    stl = work / "holder.stl"
    assert SOURCE.is_file(), "mug_holder.scad is missing"
    render(SOURCE, stl, binary=True)
    vertices = closed_mesh(stl)
    near(bounds(vertices), (-43.8, 43.8, -43.8, 53.2, 0, 34.6))

    # 取っ手は上に逃げる。下端・上端とも切り欠きのない円筒。
    for z in [2.01, 34.59]:
        plan = section(stl, work, "z", z)
        cavity = loop_at(plan, (-41.8, 41.8, -41.8, 41.8))
        assert all(abs(math.hypot(x, y) - 41.8) < 0.03 for x, y in cavity)
        assert not inside(plan, (0, 0))

    # 円筒の左右断面: 底面上Z=2から34.6まで内径83.6、側壁2。
    vertical = section(stl, work, "y", 0)
    empty_rect(vertical, (-41.78, 41.78, 2.01, 34.7))
    for sign in [-1, 1]:
        for z in [2.1, 15, 34.5]:
            assert inside(vertical, (sign * 41.83, z))
            assert inside(vertical, (sign * 43.77, z))
            assert not inside(vertical, (sign * 43.83, z))

    for z in [0.01, 1, 1.99]:
        floor = section(stl, work, "z", z)
        holes = [loop for loop in floor if max(math.hypot(x, y) for x, y in loop) < 41.8]
        assert len(holes) >= 40, "honeycomb drainage is missing"
        for hole in holes:
            x0, x1, y0, y1 = bounds(hole)
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            near((x1 - x0, y1 - y0), (6 / math.cos(math.pi / 6), 6))
            for x, y in hole:
                support = max((x - cx) * math.cos(math.radians(a)) + (y - cy) * math.sin(math.radians(a)) for a in range(30, 390, 60))
                assert abs(support - 3) < 0.03, "drain is not hexagonal"
                assert math.hypot(x, y) <= 38.81, "floor perimeter is too thin"
            assert not inside(floor, (cx, cy)), "drain is blocked"
        empty_rect(floor, (-1.5, 1.5, -2.9, 2.9))
        assert inside(floor, (0, 4)), "2mm honeycomb web is missing"
        assert inside(floor, (40, 0)), "solid floor perimeter is missing"
    empty_rect(vertical, (-3.44, 3.44, -0.1, 2.01))
    assert inside(vertical, (40, 1.99)) and not inside(vertical, (40, 2.01))

    # 頭は収納円筒の外へ沈める。頭径13.8と軸径7.8に総すきま0.6。
    # コの字外高28.1、上腕3.8: 穴中心Z=34.6+3.8-28.1/2=24.35。
    for y, diameter in [(42, 14.4), (44.99, 14.4), (45.01, 8.4), (49.39, 8.4)]:
        cross = section(stl, work, "y", y)
        hole = loop_at(cross, (-diameter / 2, diameter / 2, 24.35 - diameter / 2, 24.35 + diameter / 2))
        assert all(abs(math.hypot(x, z - 24.35) - diameter / 2) < 0.03 for x, z in hole)
        assert not inside(cross, (0, 24.35))
    assert inside(section(stl, work, "y", 45.01), (5, 24.35)), "head bearing shoulder is missing"

    # 左右2mmの回転止め。中央24.4mmは板厚3.8ぶん逃がし、両外端はデスクへ当たる。
    for z in [10.5, 16, 33, 34.59]:
        plan = section(stl, work, "z", z)
        empty_rect(plan, (-12.2, 12.2, 49.4, 53.3))
        assert inside(plan, (0, 49.38)), "clamp bearing face is missing"
        for sign in [-1, 1]:
            assert inside(plan, (sign * 12.22, 53.18))
            assert inside(plan, (sign * 14.18, 53.18))
            assert not inside(plan, (sign * 14.22, 51)), "rotation stop width is wrong"
    back = section(stl, work, "y", 51)
    for sign in [-1, 1]:
        loop_at(back, (12.2, 14.2, 0, 34.6) if sign == 1 else (-14.2, -12.2, 0, 34.6))
        assert inside(back, (sign * 13.2, 34.59)), "rotation stop is not flush with the desk"
    empty_rect(back, (-12.2, 12.2, -0.1, 38.5))
    # 座面Y=45から軸長8: 先端Y=53、デスク面Y=53.2に0.2の逃げ。
    # 頭の前面Y=42は収納半径41.8の外。上の実測座面に対する寸法関係。

    print("mug-holder: closed solid, cup fit, honeycomb drainage, recessed M8 seat, desk-flush top and rotation stops passed")
