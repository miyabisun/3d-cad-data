#!/usr/bin/env python3
"""縦置き受け、端子の抜け止め、裏蓋とケーブル出口をproduction STLで測る。"""

from pathlib import Path
import subprocess
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/laundry/bose_soundlink_flex_stand.scad"

with tempfile.TemporaryDirectory(prefix="bose-flex-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "bose_soundlink_flex_stand.scad is missing"
    for name, defines, w, d, px, py, aw, ad, ah, off_y, tip, opening, cable in [
        ("default", [], 92.4, 54.3, 5, 0, 14.3, 22.1, 10.5, -5, 3, (12.6, 8.1), (12, 8)),
        ("adjusted", ["speaker_side_width=94", "speaker_depth=56", "speaker_clearance=0.7",
                      "back_radius=17", "port_x=7", "port_y=-3", "adapter_width=20", "adapter_depth=24",
                      "adapter_height=12", "contact_offset_y=-4", "tip_projection=4",
                      "contact_width=15", "contact_depth=12", "cable_width=13", "cable_height=9"],
         95.4, 57.4, 7, -3, 20, 24, 12, -4, 4, (15, 12), (13, 9)),
        ("offset", ["port_x=28"], 92.4, 54.3, 28, 0, 14.3, 22.1, 10.5, -5, 3, (12.6, 8.1), (12, 8)),
    ]:
        stl = work / f"{name}.stl"
        render(SOURCE, stl, defines, binary=True)
        floor = 3 + ah + 0.3 + tip
        near(bounds(closed_mesh(stl)), (-w / 2 - 13, w / 2 + 13, -d / 2 - 13, d / 2 + 13, 0, floor + 25))
        # 公称外形だけの角箱へ戻らないこと。前側の角より背側の角を深く丸める。
        rim = section(stl, work, "z", floor + 6.5)
        contour = loop_at(rim, (-w / 2, w / 2, -d / 2, d / 2))
        assert len(contour) > 32, "speaker profile is a rectangular envelope"
        assert inside([contour], (w / 2 - 3, -d / 2 + 3)), "front corner is too round"
        assert not inside([contour], (w / 2 - 3, d / 2 - 3)), "rear corner lacks curvature"
        assert inside([contour], (w / 2 - 6, d / 2 - 6)) == (name == "adjusted"), "rear radius adjustment is ignored"
        assert not inside([contour], (w / 2 - 0.2, -d / 2 + 0.2)), "square front corner"
        empty_rect(rim, (-w / 2 + 8, w / 2 - 8, -d / 2 + 1, d / 2 - 9))
        # 左端の丸みは高さにつれて広がる。床まで最大外形を掘る箱にはしない。
        lower = section(stl, work, "z", floor + 0.01)
        inner = min(lower, key=lambda loop: bounds(loop)[1] - bounds(loop)[0])
        assert w - 12.1 < bounds(inner)[1] - bounds(inner)[0] < w - 11.7
        mid = section(stl, work, "z", floor + 3)
        loop_at(mid, (-w / 2 + 0.804, w / 2 - 0.804, -d / 2 + 0.804, d / 2 - 0.804))
        # 前面は8mmの低い縁、背面は25mmの案内壁。グリル側を開ける。
        assert inside(section(stl, work, "z", floor + 7.5), (0, -d / 2 - 1))
        upper = section(stl, work, "z", floor + 12)
        assert not inside(upper, (0, -d / 2 - 1)), "front wall covers the grille"
        assert inside(upper, (0, d / 2 + 1)), "rear guide is missing"
        # 台座も同じ輪郭で、上ほど絞る。角箱の台座へ戻らないこと。
        bottom = section(stl, work, "z", 1)
        assert not inside(bottom, (w / 2 + 12, d / 2 + 12)), "square base corner"
        assert inside(bottom, (w / 2 + 10, 0))
        assert not inside(section(stl, work, "z", floor - 1), (w / 2 + 10, 0))
        seat = section(stl, work, "z", floor - 0.1)
        assert inside(seat, (-w / 2 + 10, 0)) and inside(seat, (w / 2 - 10, 0))
        # 端子窓の中心はport_x/y。着座位置まで、機器側の端子が届く。
        for z in [3 + ah + 0.4, floor - 0.1]:
            aperture = section(stl, work, "z", z)
            loop_at(aperture, (px - opening[0] / 2, px + opening[0] / 2,
                               py - opening[1] / 2, py + opening[1] / 2))
            empty_rect(aperture, (px - opening[0] / 2, px + opening[0] / 2,
                                  py - opening[1] / 2, py + opening[1] / 2))
        # 底から入れる端子ポケットは外形+片側0.3mm。上面の肩で引抜きを止める。
        cx, cy = px, py - off_y
        pw, pd = aw + 0.6, ad + 0.6
        pocket = section(stl, work, "z", 3 + ah - 0.1)
        loop_at(pocket, (cx - pw / 2, cx + pw / 2, cy - pd / 2, cy + pd / 2))
        empty_rect(pocket, (cx - pw / 2, cx + pw / 2, cy - pd / 2, cy + pd / 2))
        lip = section(stl, work, "z", 3 + ah + 0.4)
        assert inside(lip, (px + aw / 2 - 0.2, py)), "retaining shoulder missing"
        # ケーブルとプラグを通せる、後方まで連続した水平出口。
        for z in [3.1, 3 + cable[1] - 0.1]:
            empty_rect(section(stl, work, "z", z),
                       (cx - cable[0] / 2, cx + cable[0] / 2, cy, d / 2 + 13.1))
        assert inside(section(stl, work, "z", 3 + cable[1] + 0.1), (cx, d / 2 + 1))
        # 裏蓋を沈める座ぐりと2本の止めねじ。蓋は底面から突出しない。
        plate_w, plate_d = pw + 14, pd + 6
        recess = section(stl, work, "z", 1)
        loop_at(recess, (cx - plate_w / 2 - 0.2, cx + plate_w / 2 + 0.2,
                         cy - plate_d / 2 - 0.2, cy + plate_d / 2 + 0.2))
        for x in [cx - pw / 2 - 3.5, cx + pw / 2 + 3.5]:
            loop_at(section(stl, work, "z", 4), (x - 1.3, x + 1.3, cy - 1.3, cy + 1.3))
        cover = work / f"{name}-cover.stl"
        render(SOURCE, cover, [*defines, 'part="cover"'], binary=True)
        near(bounds(closed_mesh(cover)), (-plate_w / 2, plate_w / 2, -plate_d / 2, plate_d / 2, 0, 3))
        for x in [-pw / 2 - 3.5, pw / 2 + 3.5]:
            loop_at(section(cover, work, "z", 0.1), (x - 1.7, x + 1.7, -1.7, 1.7))
            # 印刷時の上面へ皿穴を向ける。組付け時は反転して底面側にする。
            radius = 3.2 - 0.1
            loop_at(section(cover, work, "z", 2.9), (x - radius, x + radius, -radius, radius))

    for define in ['part="typo"', "speaker_clearance=-1", "tip_projection=0.5",
                   "contact_width=18", "port_x=40", "cable_height=12",
                   "front_radius=-1", "back_radius=30", "end_radius=9", "front_height=30"]:
        result = subprocess.run(["openscad", "-o", str(work / "invalid.stl"), "-D", define, str(SOURCE)], capture_output=True, text=True)
        assert "ERROR: Assertion" in result.stderr, (define, result.stderr)

print("Bose Flex: asymmetric curved cradle, end relief, open front, contact position, retaining lip, cable exit, flush cover and closed meshes OK")
