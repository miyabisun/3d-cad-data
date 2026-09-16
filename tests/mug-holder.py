#!/usr/bin/env python3
"""マグホルダーの実STLで収納寸法・排水・面取り・取付界面を測る。"""

import math
from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/clamp/mug-holder/mug_holder.scad"

with tempfile.TemporaryDirectory(prefix="mug-holder-test-") as temp:
    work = Path(temp)
    stl = work / "holder.stl"
    assert SOURCE.is_file(), "mug_holder.scad is missing"
    render(SOURCE, stl, binary=True)
    vertices = closed_mesh(stl)
    near(bounds(vertices), (-44.8, 44.8, -44.8, 54.2, 0, 35.6))

    # 収納円筒は内径85.6。底Z3からR2で繋ぎ、上の1mmだけR1で広げる。
    for z, radius in [(3.1, 40.8 + math.sqrt(4 - 1.9 ** 2)),
                      (4, 40.8 + math.sqrt(3)), (5.01, 42.8), (34.59, 42.8),
                      (35.1, 43.8 - math.sqrt(0.75)), (35.59, 43.8 - math.sqrt(1 - 0.99 ** 2))]:
        plan = section(stl, work, "z", z)
        cavity = loop_at(plan, (-radius, radius, -radius, radius))
        assert all(abs(math.hypot(x, y) - radius) < 0.03 for x, y in cavity)
        assert not inside(plan, (0, 0))

    vertical = section(stl, work, "y", 0)
    empty_rect(vertical, (-40.78, 40.78, 3.01, 35.7))
    empty_rect(vertical, (-42.78, 42.78, 5.01, 35.7))
    for sign in [-1, 1]:
        for z in [5.1, 15, 34.5]:
            assert inside(vertical, (sign * 42.83, z))
            assert inside(vertical, (sign * 44.77, z))
            assert not inside(vertical, (sign * 44.83, z))
        for cx, cz, radius, z0, z1 in [(40.8, 5, 2, 3.001, 4.999), (43.8, 34.6, 1, 34.601, 35.599)]:
            arc = [(sign * x, z) for loop in vertical for x, z in loop if sign * x > 40.8 and abs(sign * x - cx) <= radius + 0.02 and z0 < z < z1]
            assert len(arc) >= 8, "fillet arc is missing"
            assert all(abs(math.hypot(x - cx, z - cz) - radius) < 0.03 for x, z in arc)

    for z in [0.01, 1.5, 2.99]:
        floor = section(stl, work, "z", z)
        holes = [loop for loop in floor if max(math.hypot(x, y) for x, y in loop) < 42.8]
        assert len(holes) >= 40, "honeycomb drainage is missing"
        for hole in holes:
            x0, x1, y0, y1 = bounds(hole)
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            near((x1 - x0, y1 - y0), (6 / math.cos(math.pi / 6), 6))
            for x, y in hole:
                support = max((x - cx) * math.cos(math.radians(a)) + (y - cy) * math.sin(math.radians(a)) for a in range(30, 390, 60))
                assert abs(support - 3) < 0.03, "drain is not hexagonal"
                assert math.hypot(x, y) <= 39.81, "floor perimeter is too thin"
            assert not inside(floor, (cx, cy)), "drain is blocked"
        empty_rect(floor, (-1.5, 1.5, -2.9, 2.9))
        assert inside(floor, (0, 4)), "2mm honeycomb web is missing"
        assert inside(floor, (41, 0)), "solid floor perimeter is missing"
    empty_rect(vertical, (-3.44, 3.44, -0.1, 3.01))
    assert inside(vertical, (40, 2.99)) and not inside(vertical, (40, 3.01))

    # 頭は対辺14.2 (=13.8+0.4)、軸は対辺8.4の上下flat六角。穴中心Z25.35。
    for y, flat in [(43, 14.2), (45.99, 14.2), (46.01, 8.4), (50.39, 8.4)]:
        cross = section(stl, work, "y", y)
        radius = flat / math.sqrt(3)
        hole = loop_at(cross, (-radius, radius, 25.35 - flat / 2, 25.35 + flat / 2))
        for x, z in hole:
            support = max(x * math.cos(math.radians(a)) + (z - 25.35) * math.sin(math.radians(a)) for a in range(30, 390, 60))
            assert abs(support - flat / 2) < 0.03, "screw hole is not a flat-up hexagon"
        top = [x for x, z in hole if abs(z - (25.35 + flat / 2)) < 0.02]
        near((min(top), max(top)), (-radius / 2, radius / 2))
        assert not inside(cross, (0, 25.35))
    assert inside(section(stl, work, "y", 46.01), (5, 25.35)), "head bearing shoulder is missing"

    # 上下の処理範囲を除き、回転止めは幅2、逃げは24.4x3.8を維持する。
    for z in [11.5, 16, 33, 34.59]:
        plan = section(stl, work, "z", z)
        empty_rect(plan, (-12.2, 12.2, 50.4, 54.3))
        assert inside(plan, (0, 50.38)), "clamp bearing face is missing"
        for sign in [-1, 1]:
            assert inside(plan, (sign * 12.22, 52))
            assert inside(plan, (sign * 14.18, 52))
            assert inside(plan, (sign * 13.2, 54.18)), "rotation stop no longer reaches the desk"
            assert not inside(plan, (sign * 14.22, 52)), "rotation stop width is wrong"
    back = section(stl, work, "y", 52)
    for sign in [-1, 1]:
        loop_at(back, (12.2, 14.2, 0, 35.6) if sign == 1 else (-14.2, -12.2, 0, 35.6))
        assert inside(back, (sign * 13.2, 35.59)), "rotation stop top is too low"
    empty_rect(back, (-12.2, 12.2, -0.1, 39.5))

    # 上R1は円筒外周・取付座・回転止め・クランプ逃げの全上縁へ掛かる。
    # 下は球面ではなく、Zが0.1進むと輪郭も0.1広がるC0.4の45度。
    for z, inset in [(0.1, 0.3), (0.3, 0.1), (0.41, 0),
                     (35.1, 1 - math.sqrt(0.75)), (35.5, 1 - math.sqrt(0.19))]:
        plan = section(stl, work, "z", z)
        near(bounds([p for loop in plan for p in loop]), (-44.8 + inset, 44.8 - inset, -44.8 + inset, 54.2 - inset))
        empty_rect(plan, (-12.2, 12.2, 50.4 - inset, 54.3))
        for sign in [-1, 1]:
            for x in [12.2 + inset + 0.035, 14.2 - inset - 0.035]:
                assert inside(plan, (sign * x, 52)), "rounded/chamfered stop is too thin"
            assert not inside(plan, (sign * (12.2 + inset - 0.035), 52)), "stop inner edge is sharp"
            assert not inside(plan, (sign * (14.2 - inset + 0.035), 52)), "stop outer edge is sharp"
        assert inside(plan, (0, 50.4 - inset - 0.035)), "mount upper/bottom edge lost too much material"

    print("mug-holder: 85.6mm bore, 2mm wall, closed solid, flat-up 8.4/14.2 hex holes, 3mm floor, R2 inner floor, R1 top, C0.4 bottom and clamp fit passed")
