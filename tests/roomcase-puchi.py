#!/usr/bin/env python3
"""天馬用の前後STLを実測: 左端数セル、42mm格子、床なし、奥R5。"""

import math
from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/letter-case/temna-roomcase-puchi"

with tempfile.TemporaryDirectory(prefix="roomcase-puchi-test-") as temp:
    work = Path(temp)
    assembled_rows = []
    for name, rows, length, origin in [("front", 4, 168, 0), ("rear", 3, 153, 168)]:
        stl = work / f"{name}.stl"
        render(SOURCE / f"baseplate_{name}.scad", stl, binary=True)
        near(bounds(closed_mesh(stl)), (-115.5, 115.5, 0, length, 0, 4.65))
        # 全ソケットを各段で測る。左半セルのX幅だけが21mm短く、角R・Y幅・深さは同じ。
        for z, span, radius in [(0.35, 36.7, 1.6), (1.6, 37.4, 1.95), (4, 40.4, 3.45), (4.64, 41.7, 4.1)]:
            loops = section(stl, work, "z", z)
            spacer = name == "rear" and z < 2
            outer = loop_at(loops, (-115.5, 115.5, 0, length if spacer else rows * 42))
            assert len(loops) == 1 + 6 * rows + (24 if spacer else 0), (name, z, len(loops))
            for row in range(rows):
                cy = 21 + row * 42
                for cx, width in [(-105, span - 21), *[(x, span) for x in [-73.5, -31.5, 10.5, 52.5, 94.5]]]:
                    hole = loop_at(loops, (cx - width / 2, cx + width / 2, cy - span / 2, cy + span / 2))
                    # 端数ソケットの右奥の角。単純なX方向scaleによる楕円を弾く。
                    if cx == -105:
                        center = (cx + width / 2 - radius, cy + span / 2 - radius)
                        arc = [p for p in hole if p[0] > center[0] + 0.05 and p[1] > center[1] + 0.05]
                        assert len(arc) >= 5
                        assert all(abs(math.dist(p, center) - radius) < 0.03 for p in arc), ("socket radius", z)
            if spacer:
                for sign in [-1, 1]:
                    arc = [p for p in outer if sign * p[0] > 110.55 and p[1] > 148.05]
                    assert len(arc) >= 5, "rear corner is not rounded"
                    assert all(abs(math.dist(p, (sign * 110.5, 148)) - 5) < 0.03 for p in arc), "rear corner is not R5"
                # 奥の27mmはソケットを持たない位置決め縁。X筋交いの交点と外枠。
                for cx in [-105, -73.5, -31.5, 10.5, 52.5, 94.5]:
                    assert inside(loops, (cx, 139.5)) and inside(loops, (cx, 152))
            for sign in [-1, 1]:
                assert inside(loops, (sign * 115.45, 0.05)), "front corners must remain square"
        for row in range(rows):
            cy = 21 + row * 42
            vertical = section(stl, work, "y", cy)
            for cx, half_width in [(-105, 7.4), *[(x, 17.9) for x in [-73.5, -31.5, 10.5, 52.5, 94.5]]]:
                empty_rect(vertical, (cx - half_width, cx + half_width, -0.1, 4.8))
            for x in [-115.45, -94.5, -52.5, -10.5, 31.5, 73.5, 115.45]:
                assert inside(vertical, (x, 4.6)), ("socket wall missing", name, row, x)
            assembled_rows.append(cy + origin)
        if name == "rear":
            near(bounds([p for loop in section(stl, work, "y", 139.5) for p in loop]), (-115.5, 115.5, 0, 2))
        print(f"roomcase-puchi {name}: bounds, {rows * 6} sockets, mating profile, floorless closed mesh passed")
    near(assembled_rows, (21, 63, 105, 147, 189, 231, 273))
    print("roomcase-puchi: split pitch 42mm, rear R5 and rear spacer passed")
