#!/usr/bin/env python3
"""NFCタグ台の実STLで外形・上下C1面取り・M8の通し穴と頭の座ぐりを測る。"""

from pathlib import Path
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/clamp/nfc-tag-holder/nfc_tag_holder.scad"

with tempfile.TemporaryDirectory(prefix="nfc-tag-holder-") as temp:
    work = Path(temp)
    stl = work / "holder.stl"
    assert SOURCE.is_file(), "nfc_tag_holder.scad is missing"
    render(SOURCE, stl, binary=True)
    near(bounds(closed_mesh(stl)), (-14, 14, -14, 14, 0, 7))

    # 外周はΦ28。上下1mmは45度の直線で、端面は半径13まで絞る。
    # 穴はZ0〜4がM8通し穴Φ8.4、Z4〜7がトラス頭Φ13.8の座ぐりΦ14.2。
    for z, outer, hole in [(0.01, 13.01, 4.2), (0.5, 13.5, 4.2), (1.5, 14, 4.2), (3.99, 14, 4.2),
                           (4.01, 14, 7.1), (5.5, 14, 7.1), (6.5, 13.5, 7.1), (6.99, 13.01, 7.1)]:
        plan = section(stl, work, "z", z)
        assert len(plan) == 2, (z, len(plan))
        loop_at(plan, (-outer, outer) * 2)
        loop_at(plan, (-hole, hole) * 2)
        assert not inside(plan, (0, 0))
        assert inside(plan, (hole + 0.1, 0))

    # 天面の平らな環はΦ26まで残り、Φ25のタグ全体を受ける。
    top = section(stl, work, "z", 6.999)
    assert inside(top, (12.45, 0)) and inside(top, (0, -12.45))

    # 縦断面: 穴は上下に貫通し、座ぐりはZ4の段から天面まで開く (ブリッジ無し)。
    vertical = section(stl, work, "y", 0)
    empty_rect(vertical, (-4.2, 4.2, -0.1, 7.1))
    empty_rect(vertical, (-7.1, 7.1, 4, 7.1))
    for sign in [-1, 1]:
        assert inside(vertical, (sign * 5, 3.9)), "shaft seat is missing"
        assert inside(vertical, (sign * 13.9, 3.5))
        assert not inside(vertical, (sign * 13.9, 0.05)), "bottom chamfer is missing"
        assert not inside(vertical, (sign * 13.9, 6.95)), "top chamfer is missing"
    print("nfc-tag-holder: Φ28×7, C1 top/bottom, M8 Φ8.4 + head Φ14.2×3 passed")
