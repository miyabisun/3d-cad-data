#!/usr/bin/env python3
"""洗浄ポッド受けと下向きの棚スリットをproduction STLから測る。"""

from pathlib import Path
import math
import subprocess
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/laundry/philips_cleaning_pod_holder.scad"

with tempfile.TemporaryDirectory(prefix="philips-holder-test-") as temp:
    work = Path(temp)
    # 円形の初期値、実測合わせの角丸長方形、角丸なし・補正なし。
    for name, defines, w, d, gap, length, depth, floor, height in [
        ("default", [], 101, 101, 3.4, 60, 45, 8, 28),
        ("adjusted", ["pod_width=104", "pod_depth=96", "pod_corner_radius=12",
                      "pod_clearance=0.7", "shelf_thickness=3.2", "slot_clearance=0.6",
                      "slot_length=54", "slot_depth=38", "floor_thickness=9", "retaining_height=24"],
         105.4, 97.4, 3.8, 54, 38, 9, 33),
        ("square", ["pod_corner_radius=0", "pod_clearance=0", "slot_clearance=0"],
         100, 100, 3, 60, 45, 8, 28),
    ]:
        stl = work / f"{name}.stl"
        render(SOURCE, stl, defines, binary=True)
        near(bounds(closed_mesh(stl)), (-w / 2 - 3, w / 2 + 3, -9 - gap, d + 6, 0, depth + 6))

        # フック両端まで、受けとの隙間を全高で埋める（内部を補集合で検査）。
        if name == "default":
            for z in [1.1, floor + 1, height - 1.1]:
                plan = section(stl, work, "z", z)
                for rect in [(-29.9, -26, 2, 8.5), (26, 29.9, 2, 8.5)]:
                    empty_rect([[(-200, -200), (200, -200), (200, 200), (-200, 200)], *plan], rect)

        # 溝は下と左右へ開放。棚が入る全長・全深さに膜がない。
        for z in [0.1, depth / 2, depth - 0.1]:
            plan = section(stl, work, "z", z)
            empty_rect(plan, (-length / 2 - 0.1, length / 2 + 0.1, -3 - gap, -3))
            inset = max(0, 1 - z)
            loop_at(plan, (-length / 2 + inset, length / 2 - inset, -9 - gap + inset, -3 - gap))
            assert inside(plan, (0, -2.9)), "front leg missing"
        loop_at(section(stl, work, "z", depth - 0.1), (-length / 2, length / 2, -3, 3))
        side = section(stl, work, "y", -3 - gap / 2)
        loop_at(side, (-length / 2, length / 2, depth, depth + 6))
        empty_rect(side, (-length / 2, length / 2, -0.1, depth))

        # 受けの内寸と深さ。
        for z in [floor + 0.1, height - 0.1]:
            cavity = loop_at(section(stl, work, "z", z), (-w / 2, w / 2, 3, d + 3))
            if name == "default":
                assert all(abs((x*x + (y - 53.5)**2)**0.5 - 50.5) < 0.03 for x, y in cavity)
            elif name == "square":
                assert len(cavity) == 4
            else:
                assert not inside([cavity], (w / 2 - 0.1, 3.1)), "corner rounding missing"
        # 底は＋と×を合わせた8方向。各桟の直角方向の幅を輪郭との交点から測る。
        cy = d / 2 + 3
        for z in [0.1, floor / 2, floor - 0.1]:
            bottom = section(stl, work, "z", z)
            assert inside(bottom, (0, cy)), "center must be solid"
            for angle in range(0, 360, 45):
                ux, uy = math.cos(math.radians(angle)), math.sin(math.radians(angle))
                assert inside(bottom, (30 * ux, cy + 30 * uy)), ("missing spoke", angle)
                hits = []
                for loop in bottom:
                    for a, b in zip(loop, loop[1:] + loop[:1]):
                        sa, sb = (p[0] * ux + (p[1] - cy) * uy - 30 for p in (a, b))
                        if (sa > 0) != (sb > 0):
                            ta, tb = (-p[0] * uy + (p[1] - cy) * ux for p in (a, b))
                            hits.append(ta + (tb - ta) * sa / (sa - sb))
                near((max(v for v in hits if v < 0), min(v for v in hits if v > 0)), (-5, 5))
                a = math.radians(angle + 22.5)
                x, y = 30 * math.cos(a), cy + 30 * math.sin(a)
                empty_rect(bottom, (x - 1, x + 1, y - 1, y + 1))

        # 外周の上下1mmを45度で落とす。溝・受け内寸と桟幅は変えない。
        for z, inset in [(0.1, 0.9), (0.5, 0.5), (1.1, 0), (height - 1.1, 0), (height - 0.5, 0.5), (height - 0.1, 0.9)]:
            plan = section(stl, work, "z", z)
            xmin, xmax, _, ymax = bounds([p for loop in plan for p in loop])
            near((xmin, xmax, ymax), (-w / 2 - 3 + inset, w / 2 + 3 - inset, d + 6 - inset))
        for z, inset in [(depth + 5.1, 0.1), (depth + 5.5, 0.5), (depth + 5.9, 0.9)]:
            loop_at(section(stl, work, "z", z), (-length / 2 + inset, length / 2 - inset, -9 - gap + inset, 3 - inset))
        vertical = section(stl, work, "y", d / 2 + 3)
        empty_rect(vertical, (-w / 2, w / 2, floor, height + 0.1))
        assert inside(vertical, (0, floor - 0.1))
        assert inside(vertical, (w / 2 + 1, height - 0.1)), "retaining wall missing"
        assert not inside(vertical, (w / 2 + 1, height + 0.1))

    for define in ["slot_length=61", "slot_depth=46", "pod_corner_radius=51", "slot_clearance=-0.1", "rib_width=0", "edge_chamfer=2"]:
        result = subprocess.run(["openscad", "-o", str(work / "invalid.stl"), "-D", define, str(SOURCE)], capture_output=True, text=True)
        assert "ERROR: Assertion" in result.stderr, (define, result.stderr)

print("Philips holder: full-width joint, eight 10 mm spokes, C1 edges, slot, fit and closed mesh OK")
