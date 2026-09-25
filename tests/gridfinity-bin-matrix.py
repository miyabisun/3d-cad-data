#!/usr/bin/env python3
"""4U/9Uの全66種をSTL実測し、5.5セル版の回転後の嵌合も確認する。"""

from concurrent.futures import ThreadPoolExecutor
from itertools import product
import math
import os
from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SIZES = [(c, r, u) for c, r, u in product((1, 1.5, 2, 2.5, 3), (1, 2, 3, 4, 5, 5.5, 6), (4, 9))
         if not (c % 1 and r % 1)]


def check_bin(stl, cols, rows, units, work):
    half, depth, h = cols * 21 - 0.25, rows * 42 - 0.5, units * 7
    near(bounds(closed_mesh(stl)), (-half, half, 0, depth, 0, h + 4.4))
    # 標準の足を右/奥の端から42mm間隔で数え、左/手前に21mmの半セルを加える。
    xs = [(cols * 21 - 21 - i * 42, 42) for i in range(int(cols))]
    ys = [(depth - 20.75 - i * 42, 42) for i in range(int(rows))]
    if cols % 1:
        xs.append((-cols * 21 + 10.5, 21))
    if rows % 1:
        ys.append((10.25, 21))
    for z, span, radius in [(0.4, 36.4, 1.2), (2, 37.2, 1.6), (4, 40, 3)]:
        loops = section(stl, work, "z", z)
        assert len(loops) == len(xs) * len(ys), (stl, z, "foot count", len(loops))
        for (cx, pitch_x), (cy, pitch_y) in product(xs, ys):
            w, d = span + pitch_x - 42, span + pitch_y - 42
            foot = loop_at(loops, (cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2))
            center = (cx + w / 2 - radius, cy + d / 2 - radius)
            arc = [p for p in foot if p[0] > center[0] + 0.05 and p[1] > center[1] + 0.05]
            assert len(arc) >= 5, (stl, z, "foot corner missing")
            assert all(abs(math.dist(p, center) - radius) < 0.03 for p in arc), (stl, z, "foot radius")
    body = section(stl, work, "z", 12)
    assert len(body) == 2
    loop_at(body, (-half, half, 0, depth))
    loop_at(body, (-half + 1.2, half - 1.2, 1.2, depth - 1.2))
    # 全サイズでラベルは奥側、手前は取り出し口として空ける。
    label_y = depth - 8
    side = section(stl, work, "y", label_y)
    assert inside(side, (0, 5.5))
    empty_rect(side, (-half + 1.3, half - 1.3, 6, h - 7.3))
    for x in (0, -half + 1.3, half - 1.3):
        assert inside(side, (x, h - 7.1)) and not inside(side, (x, h - 7.3)), "label wedge"
        assert inside(side, (x, h - 0.1)) and not inside(side, (x, h + 0.1)), "label top"
    assert inside(side, (half - 0.6, h + 3)) and not inside(side, (half - 1.3, h + 3)), "thin lip"
    assert inside(side, (half - 0.6, h + 4)) and not inside(side, (half - 0.9, h + 4)), "lip chamfer"
    opposite = section(stl, work, "y", depth - label_y)
    empty_rect(opposite, (-half + 1.3, half - 1.3, 6, h + 0.1))


def check_rotated(output, work):
    def fits(socket, foot):
        edges = list(zip(socket, socket[1:] + socket[:1]))
        direction = 1 if sum(ax * by - bx * ay for (ax, ay), (bx, by) in edges) > 0 else -1
        # 既存の公称足/受けの角で約0.004mmの差があるため、0.01mmを許容する。
        return all(direction * ((bx - ax) * (y - ay) - (by - ay) * (x - ax)) >= -0.01 * math.dist((ax, ay), (bx, by))
                   for x, y in foot for (ax, ay), (bx, by) in edges)

    plate = work / "plate.stl"
    render(ROOT / "assets/letter-case/temna-roomcase-puchi/baseplate_front.scad", plate, binary=True)
    for z in (0.4, 2, 4):
        loops = section(plate, work, "z", z)
        outer = loop_at(loops, (-115.5, 115.5, 0, 168))
        sockets = [p for p in loops if p is not outer]
        for cols in (1, 2, 3):
            feet = section(output / f"4u/{cols}x5.5.stl", work, "z", z)
            for foot in feet:
                # 上から時計回り90度。半セルは左端、ラベルは右側になる。
                rotated = [(y - 115.25, cols * 21 - x) for x, y in foot]
                # 各足/ソケットは凸形状。同じソケットに全頂点が入れば辺も収まる。
                assert any(fits(socket, rotated) for socket in sockets), (cols, z, "rotated foot does not fit")
    print("gridfinity-bin: all three 5.5-cell widths fit the Tenma sockets after rotation", flush=True)


def main(output):
    sources = ROOT / "assets/gridfinity-bin"
    expected = {f"{u}u/{c}x{r}.scad" for c, r, u in SIZES} | {
        "goods/card_case_2x3x4u.scad",
        "goods/cable-holder/3x5.5x9u.scad", "goods/cable-holder/4x5.5x9u.scad",
        "goods/cable-holder/divider_3.scad", "goods/cable-holder/divider_4.scad",
    }
    actual = {str(p.relative_to(sources)) for p in sources.rglob("*.scad")}
    assert actual == expected, ("asset matrix", sorted(expected - actual), sorted(actual - expected))

    def check(size):
        c, r, u = size
        relative = Path(f"{u}u/{c}x{r}")
        stl = output / f"{relative}.stl"
        stl.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="bin-section-") as temp:
            render(sources / f"{relative}.scad", stl, binary=True)
            check_bin(stl, c, r, u, Path(temp))
        print(f"gridfinity-bin: {relative} bounds, closed mesh, feet, walls, floor, lip and label passed", flush=True)

    with ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
        list(pool.map(check, SIZES))
    with tempfile.TemporaryDirectory(prefix="bin-mating-") as temp:
        check_rotated(output, Path(temp))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(Path(sys.argv[1]).resolve())
    else:
        with tempfile.TemporaryDirectory(prefix="bin-matrix-") as temp:
            main(Path(temp))
