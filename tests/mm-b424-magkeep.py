#!/usr/bin/env python3
"""MM-B424用MAGKEEP台: 印刷STLの貼付面・傾斜・掛け溝を実測する。"""

import math
from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/steel-rack/mm-b424/magkeep_holder.scad"

with tempfile.TemporaryDirectory(prefix="mm-b424-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "magkeep_holder.scad is missing"
    for angle in [20, 0, 30, 45]:
        stl = work / f"holder-{angle}.stl"
        render(SOURCE, stl, () if angle == 20 else (f"tilt_deg={angle}",), binary=True)
        vertices = closed_mesh(stl)
        near(bounds(vertices)[4:], (0, 64))  # 左右側面間が64mm、側面をベッドへ置く
        sin, cos = math.sin(math.radians(angle)), math.cos(math.radians(angle))

        # 全幅にわたる掛け溝は深さ5・高さ22。下向きの入口にも膜がない。
        for width in [0.1, 32, 63.9]:
            profile = section(stl, work, "z", width)
            assert len(profile) == 1
            empty_rect(profile, (-5, 0, -23, 0))
            for p in [(-5.1, -11), (0.1, -11), (-2.5, 0.1), (-7, -21.9)]:
                assert inside(profile, p), (angle, p, "hook wall missing")
            assert not inside(profile, (-2.5, -0.1)), "slot ceiling too low"

        # 上下C1の後も64×62の平面が残り、中央Φ61に上下各0.5mmの余白がある。
        front = [p for p in vertices if abs((p[0] - 8) * cos + (p[1] - 4) * sin) < 0.001]
        assert len(front) >= 4, "flat adhesive face is missing or tilted incorrectly"
        face_coords = [(p[2], (p[0] - 8) * sin - (p[1] - 4) * cos) for p in front]
        near(bounds(face_coords), (0, 64, 1, 63))
        assert all((p[0] - 8) * cos + (p[1] - 4) * sin < 0.001 for p in vertices), "hook protrudes in front of phone"

        # 面取り以外の板厚と貼付領域を保持する。
        profile = section(stl, work, "z", 32)
        edges = [(a, b) for loop in profile for a, b in zip(loop, loop[1:] + loop[:1])]
        face_edges = [(a, b) for a, b in edges if all(abs((p[0] - 8) * cos + (p[1] - 4) * sin) < 0.001 for p in (a, b))]
        assert len(face_edges) == 1
        a, b = face_edges[0]
        assert abs(math.dist(a, b) - 62) < 0.03
        for length in [1.5, 32, 62.5]:
            point = (8 + length * sin - 3.9 * cos, 4 - length * cos - 3.9 * sin)
            assert inside(profile, point), (angle, length, "adhesive plate thinner than 4mm")

        # 面を基準にした座標 (長手方向t、内向き深さd) で上下・下端裏を測る。
        local = [[((x - 8) * sin - (y - 4) * cos,
                   -(x - 8) * cos - (y - 4) * sin) for x, y in loop] for loop in profile]
        for t, d, material in [(0.4, 0.4, False), (0.6, 0.6, True),
                               (63.6, 0.4, False), (63.4, 0.6, True),
                               (63.6, 3.6, False), (63.4, 3.4, True)]:
            assert inside(local, (t, d)) == material, (angle, t, d, "C1 chamfer missing")
        for a, b in [((1, 0), (0.5, 0.5)), ((63, 0), (63.5, 0.5)), ((64, 3), (63.5, 3.5))]:
            # 指定した2点を通る辺を探す。傾斜1:1であることを実エッジで保証する。
            matches = [(p, q) for loop in local for p, q in zip(loop, loop[1:] + loop[:1])
                       if all(abs((q[0] - p[0]) * (v[1] - p[1]) - (q[1] - p[1]) * (v[0] - p[0])) < 0.001
                              and min(p[0], q[0]) - 0.001 <= v[0] <= max(p[0], q[0]) + 0.001 for v in (a, b))]
            assert len(matches) == 1, (angle, a, b, "45 degree edge missing")
        for p in [(-8.9, -21.9), (-5.1, -21.9), (0.1, -21.9)]:
            assert not inside(profile, p), (angle, p, "hook tip chamfer missing")

    # スリット寸法の調整が形状へ反映されること。
    adjusted = work / "adjusted.stl"
    render(SOURCE, adjusted, ("slit_width=6", "slit_height=24"), binary=True)
    closed_mesh(adjusted)
    profile = section(adjusted, work, "z", 32)
    empty_rect(profile, (-6, 0, -25, 0))
    assert inside(profile, (-8, -23.9))
    assert inside(profile, (-3, 0.1))

    # 取付表示: Xが幅、Yが手前、Zが上。下端ほど手前へ出る。
    mounted = work / "mounted.stl"
    render(SOURCE, mounted, ('part="mounted"',), binary=True)
    near(bounds(closed_mesh(mounted)), (-32, 32, -9, 29.54727, -57.16639, 4))
    print("mm-b424-magkeep: C1/45° upper/lower edges, 64×62 flat face, Φ61 area, 5×22 open slot, 20/0/30/45° upward tilt, closed connected mesh passed")
