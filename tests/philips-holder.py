#!/usr/bin/env python3
"""洗浄ポッド受けと下向きの棚スリットをproduction STLから測る。"""

from pathlib import Path
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

        # 溝は下と左右へ開放。棚が入る全長・全深さに膜がない。
        for z in [0.1, depth / 2, depth - 0.1]:
            plan = section(stl, work, "z", z)
            empty_rect(plan, (-length / 2 - 0.1, length / 2 + 0.1, -3 - gap, -3))
            loop_at(plan, (-length / 2, length / 2, -9 - gap, -3 - gap))
            assert inside(plan, (0, -2.9)), "front leg missing"
        loop_at(section(stl, work, "z", depth - 0.1), (-length / 2, length / 2, -3, 3))
        side = section(stl, work, "y", -3 - gap / 2)
        loop_at(side, (-length / 2, length / 2, depth, depth + 6))
        empty_rect(side, (-length / 2, length / 2, -0.1, depth))

        # 受けの内寸と深さ。底と側壁、底の排水穴を測る。
        for z in [floor + 0.1, height - 0.1]:
            cavity = loop_at(section(stl, work, "z", z), (-w / 2, w / 2, 3, d + 3))
            if name == "default":
                assert all(abs((x*x + (y - 53.5)**2)**0.5 - 50.5) < 0.03 for x, y in cavity)
            elif name == "square":
                assert len(cavity) == 4
            else:
                assert not inside([cavity], (w / 2 - 0.1, 3.1)), "corner rounding missing"
        bottom = section(stl, work, "z", floor - 0.1)
        loop_at(bottom, (-4, 4, d / 2 - 1, d / 2 + 7))
        assert inside(bottom, (10, d / 2 + 3)), "floor missing"
        vertical = section(stl, work, "y", d / 2 + 3)
        empty_rect(vertical, (-w / 2, w / 2, floor, height + 0.1))
        empty_rect(vertical, (-3.9, 3.9, -0.1, floor + 0.1))
        assert inside(vertical, (w / 2 + 1, height - 0.1)), "retaining wall missing"
        assert not inside(vertical, (w / 2 + 1, height + 0.1))

    for define in ["slot_length=61", "slot_depth=46", "pod_corner_radius=51", "slot_clearance=-0.1"]:
        result = subprocess.run(["openscad", "-o", str(work / "invalid.stl"), "-D", define, str(SOURCE)], capture_output=True, text=True)
        assert "ERROR: Assertion" in result.stderr, (define, result.stderr)

print("Philips holder: slot, fit, floor, drainage, single closed mesh and parameter limits OK")
