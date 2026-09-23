#!/usr/bin/env python3
"""ケーブル用binの全溝・左半セル・U字板と、上からの挿入経路をSTLで測る。"""

import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "assets/gridfinity-bin/goods/cable-holder"


def main(output, sources=SOURCES):
    output.mkdir(parents=True, exist_ok=True)
    for rows in (3, 4):
        depth = rows * 42 - 0.5
        length = depth - 2.8
        body = output / f"{rows}x5.5x9u.stl"
        plate = output / f"divider_{rows}.stl"
        with tempfile.TemporaryDirectory(prefix="cable-section-") as temp:
            work = Path(temp)
            render(sources / f"{rows}x5.5x9u.scad", body, binary=True)
            near(bounds(closed_mesh(body)), (-115.25, 115.25, 0, depth, 0, 67.4))
            # 左21mmの半セル＋標準5列。全ての足の3段輪郭が所定の位置にある。
            for z, span in ((0.4, 36.4), (2, 37.2), (4, 40)):
                feet = section(body, work, "z", z)
                assert len(feet) == 6 * rows, "foot count"
                for cy in (20.75 + 42 * row for row in range(rows)):
                    for cx, width in [(-105, span - 21), *[(x, span) for x in (-73.5, -31.5, 10.5, 52.5, 94.5)]]:
                        loop_at(feet, (cx - width / 2, cx + width / 2, cy - span / 2, cy + span / 2))

            # 各溝は幅2.4・深さ2。溝の間は補強壁、外側には1.2mmの皮が残る。
            for z in (6, 12, 62, 67.3):
                plan = section(body, work, "z", z)
                assert len(plan) == 2, (rows, z, "fixed partitions or disconnected guides", len(plan))
                if z < 66:
                    loop_at(plan, (-114.05, 114.05, 1.2, depth - 1.2))
                empty_rect(plan, (-114.05, 114.05, 10, depth - 10))
                for x in range(-105, 106, 10):
                    for rear in (False, True):
                        y0, y1 = (depth - 3.4, depth - 1.2) if rear else (1.2, 3.4)
                        empty_rect(plan, (x - 1.2, x + 1.2, y0, y1))
                        y = depth - 2.2 if rear else 2.2
                        assert inside(plan, (x - 1.21, y)) and inside(plan, (x + 1.21, y)), "slot width/guide"
                        assert inside(plan, (x, depth - 0.6 if rear else 0.6)), "outside wall"
            # 上端に溝を塞ぐ棚・薄膜がない。溝の底は床z=5.95で止まる。
            for y in (2.2, depth - 2.2):
                vertical = section(body, work, "y", y)
                for x in range(-105, 106, 10):
                    empty_rect(vertical, (x - 1.2, x + 1.2, 5.95, 68))
                    assert inside(vertical, (x, 5.9)), "slot must not cut through floor"
            empty_rect(section(body, work, "y", depth / 2), (-114.05, 114.05, 5.95, 68))

            render(sources / f"divider_{rows}.scad", plate, binary=True)
            plate_bounds = bounds(closed_mesh(plate))
            near(plate_bounds, (-length / 2, length / 2, 0, 57.05, 0, 2))
            profile = section(plate, work, "z", 1)
            assert len(profile) == 1, "divider must be one U-shaped plate"
            empty_rect(profile, (-length / 2 + 22, length / 2 - 22, 18, 58))
            assert inside(profile, (0, 17.95)) and not inside(profile, (0, 18.05)), "U bottom"
            for sign in (-1, 1):
                assert inside(profile, (sign * (length / 2 - 5), 56.5)), "U leg"
                center = (sign * (length / 2 - 22), 30)
                arc = [p for p in profile[0] if 0.05 < sign * (p[0] - center[0]) < 11.95 and 18.05 < p[1] < 29.95]
                assert len(arc) >= 5 and all(abs(math.dist(p, center) - 12) < 0.03 for p in arc), "U corner R12"

            # 実測した板の幅・厚さで22位置の挿入経路を掃引し、本体と交差しないこと。
            # 床に接する面だけは0.01mm浮かせて、接触を体積干渉と区別する。
            sweep = work / "interference.scad"
            sweep.write_text(f'''intersection() {{
  import("{body}");
  for (x = [-105:10:105])
    translate([x - {plate_bounds[5] / 2}, {(depth - length) / 2}, 5.96])
      cube([{plate_bounds[5]}, {plate_bounds[1] - plate_bounds[0]}, 70]);
}}
''')
            result = subprocess.run(["openscad", "-o", str(work / "interference.stl"), str(sweep)], capture_output=True, text=True)
            assert result.returncode == 1 and "Current top level object is empty." in result.stderr and not re.search(r"ERROR|WARNING", result.stderr), result.stderr
        print(f"cable-holder {rows}x5.5x9u: closed meshes, half-cell feet, all 22 slot pairs, U divider and insertion clearance passed", flush=True)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else SOURCES)
    else:
        with tempfile.TemporaryDirectory(prefix="cable-holder-test-") as temp:
            main(Path(temp))
