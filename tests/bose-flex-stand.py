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
        ("default", [], 91, 53, 5, 0, 14.3, 22.1, 10.5, -5, 3, (8.1, 12.6), (12, 8)),
        ("adjusted", ["speaker_side_width=94", "speaker_depth=56", "speaker_clearance=0.7",
                      "port_x=7", "port_y=-3", "adapter_width=20", "adapter_depth=24",
                      "adapter_height=12", "contact_offset_y=-4", "tip_projection=4",
                      "contact_width=15", "contact_depth=12", "cable_width=13", "cable_height=9"],
         95.4, 57.4, 7, -3, 20, 24, 12, -4, 4, (15, 12), (13, 9)),
        ("offset", ["port_x=34", "port_y=8"], 91, 53, 34, 8, 14.3, 22.1, 10.5, -5, 3, (8.1, 12.6), (12, 8)),
    ]:
        stl = work / f"{name}.stl"
        render(SOURCE, stl, defines, binary=True)
        floor = 3 + ah + 0.3 + tip
        near(bounds(closed_mesh(stl)), (-w / 2 - 13, w / 2 + 13, -d / 2 - 13, d / 2 + 13, 0, floor + 25))
        # 着座面より上はスピーカーの全断面が空き、入口に1mmの導入面がある。
        for z, flare in [(floor + 0.1, 0), (floor + 23.9, 0), (floor + 24.5, 0.5)]:
            profile = section(stl, work, "z", z)
            loop_at(profile, (-w / 2 - flare, w / 2 + flare, -d / 2 - flare, d / 2 + flare))
            empty_rect(profile, (-w / 2, w / 2, -d / 2, d / 2))
        seat = section(stl, work, "z", floor - 0.1)
        assert inside(seat, (-w / 2 + 4, 0)) and inside(seat, (w / 2 - 4, 0))
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
        assert inside(section(stl, work, "z", 3 + cable[1] + 0.1), (cx, d / 2 + 10))
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
                   "contact_width=18", "port_x=40", "cable_height=12"]:
        result = subprocess.run(["openscad", "-o", str(work / "invalid.stl"), "-D", define, str(SOURCE)], capture_output=True, text=True)
        assert "ERROR: Assertion" in result.stderr, (define, result.stderr)

print("Bose Flex: cradle fit, contact position, retaining lip, cable exit, flush cover and closed meshes OK")
