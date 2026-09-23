#!/usr/bin/env python3
"""M8脚の実STLと、反転した既存アクリル受けとの接触・ボルト位置を確認する。"""

from pathlib import Path
import math
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/steel-rack/500x400/corner_rubber_foot.scad"

with tempfile.TemporaryDirectory(prefix="corner-rubber-foot-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "rubber foot mount is missing"
    foot = work / "foot.stl"
    render(SOURCE, foot, binary=True)
    near(bounds(closed_mesh(foot)), (0, 27, 0, 27, 0, 25.9))

    # M8ナットはL字内側から挿入。下に厚3.2の座面を残して抜けを止める。
    r = 13.3 / math.sqrt(3)
    for z in [0.1, 3.19]:
        loop_at(section(foot, work, "z", z), (12.8, 21.2, 12.8, 21.2))
    for z in [3.21, 9.99]:
        loop_at(section(foot, work, "z", z), (10.35, 23.65, 17 - r, 17 + r))

    # 両面のM6穴は既存と同じ中心15.7/Z15.2と座面4.6を維持。
    reflected = work / "reflected.scad"
    reflected.write_text(f'mirror([1,-1,0]) import("{foot}");\n')
    mirrored = work / "reflected.stl"
    render(reflected, mirrored, binary=True)
    for part in [foot, mirrored]:
        for y, flat in [(0.1, 6.4), (4.59, 6.4), (4.61, 10.4), (7, 10.4)]:
            r = flat / math.sqrt(3)
            loop_at(section(part, work, "y", y), (15.7 - r, 15.7 + r, 15.2 - flat / 2, 15.2 + flat / 2))
        loops = section(part, work, "y", 15.7)
        empty_rect(loops, (-1, 4.59, 12.01, 18.39))
        empty_rect(loops, (4.61, 28, 10.01, 20.39))

    bolts = ROOT / "modules/bolts.scad"
    helpers = ROOT / "modules/slide_rail_outer_bracket.scad"
    def no_collision(geometry):
        source, output = work / "collision.scad", work / "collision.stl"
        source.write_text(f'use <{bolts}>\nuse <{helpers}>\ntranslate([40,0,0]) cube(1);\n{geometry}\n')
        render(source, output, binary=True)
        near(bounds(closed_mesh(output)), (40, 41, 0, 1, 0, 1))

    # AF13×厚6.5の金属ナットを、座面接触から5µm離して上から挿入。
    nut = 'translate([17,17,3.205]) rotate([0,0,30]) nut_trap(13,6.5,center=false);'
    no_collision(f'intersection() {{ import("{foot}"); hull() {{ {nut} translate([0,0,30]) {{ {nut} }} }} }}')
    # M8を先に入れてから、M6ナットを各面へ入れた状態での非干渉。
    m6_nuts = '''
      translate([7.1,15.7,15.2]) hex_x_flat_up(10,5);
      translate([15.7,7.1,15.2]) hex_y_flat_up(10,5);
    '''
    no_collision(f'intersection() {{ {nut} union() {{ {m6_nuts} }} }}')
    # M8軸は底板より上のR5も通過できること。M6×12の軸も同時に検査。
    shanks = '''
      translate([17,17,-1]) cylinder(d=8,h=28,$fn=64);
      translate([-2,15.7,15.2]) rotate([0,90,0]) cylinder(d=6,h=12,$fn=48);
      translate([15.7,-2,15.2]) rotate([-90,0,0]) cylinder(d=6,h=12,$fn=48);
    '''
    no_collision(f'intersection() {{ import("{foot}"); union() {{ {shanks} }} }}')

    # 大きくなったM8ナットの挿入経路で内縁が一部切れるが、L字接触面は残す。
    acrylic = work / "acrylic.stl"
    render(ROOT / "assets/steel-rack/500x400/corner_acrylic_support.scad", acrylic, binary=True)
    contact = section(foot, work, "z", 25.89)
    assert len(contact) == 1, "L contact face is disconnected"
    outline = contact[0]
    contact_area = abs(sum(x * by - bx * y for (x, y), (bx, by) in zip(outline, outline[1:] + outline[:1]))) / 2
    assert contact_area > 400, ("lost L contact area", contact_area)

    # 使用姿勢は脚の平面が下、アクリル受けの平面が上。公称Z=25.9で接触。
    # STL座標丸めのゼロ厚接触を除くため、衝突検査では上側を5µm離す。
    no_collision(f'intersection() {{ import("{foot}"); translate([0,0,51.805]) rotate(a=180,v=[1,1,0]) import("{acrylic}"); }}')
    assembled = work / "upper.scad"
    assembled.write_text(f'translate([0,0,51.8]) rotate(a=180,v=[1,1,0]) import("{acrylic}");\n')
    upper = work / "upper.stl"
    render(assembled, upper, binary=True)
    r = 6.4 / math.sqrt(3)
    loop_at(section(upper, work, "y", 0.1), (15.7 - r, 15.7 + r, 33.4, 39.8))
    # 実測した上穴Z36.6と下穴Z15.2は中心間21.4。
    # φ6を7×30長穴の上端に寄せると、下側の軸外縁〜長穴下端は2.6mm。
    print("corner-rubber-foot: M8 bearing seat/entry, both M6 holes, R5 shaft clearance and 21.4mm assembly passed")
