#!/usr/bin/env python3
"""M8脚の実STLと、反転した既存アクリル受けとの接触・ボルト位置を確認する。"""

from pathlib import Path
import math
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/steel-rack/500x400/corner_rubber_foot.scad"

with tempfile.TemporaryDirectory(prefix="corner-rubber-foot-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "rubber foot mount is missing"
    foot = work / "foot.stl"
    render(SOURCE, foot, binary=True)
    near(bounds(closed_mesh(foot)), (0, 27, 0, 27, 0, 29.9))

    # 下へ4mm増厚し、窪みを2mm浅くする。M8座面厚9.2、内側床Z14、窪み深さ4.8。
    r = 13.3 / math.sqrt(3)
    half_extent = r * math.cos(math.radians(15))
    for z in [0.1, 9.19]:
        loop_at(section(foot, work, "z", z), (12.8, 21.2, 12.8, 21.2))
    for z in [9.21, 13.99]:
        pocket = loop_at(section(foot, work, "z", z), (17 - half_extent, 17 + half_extent) * 2)
        # L字の二等分線方向が対辺幅13.3、その直交方向が対角幅となる。
        diagonal = [((x + y - 34) / math.sqrt(2), (y - x) / math.sqrt(2)) for x, y in pocket]
        near(bounds(diagonal), (-6.65, 6.65, -r, r))

    # M6窪みは直交穴の中心X/Y=15.7で止め、向こう側の壁を残す。
    limited_m6 = section(foot, work, "z", 19.3)
    for entry, beyond in [((15.6, 9.8), (22, 9.8)), ((9.8, 15.6), (9.8, 22))]:
        assert not inside(limited_m6, entry)
        assert inside(limited_m6, beyond), "M6 nut corridor cuts the opposite wall"
    # M8窪みはM6中心高さで止める。M6穴より上の壁まで貫通させない。
    upper_wall = section(foot, work, "z", 25)
    for point in [(9.8, 15), (15, 9.8)]:
        assert inside(upper_wall, point), "M8 nut corridor cuts the upper wall"

    # M6中心は新底面基準でZ19.2。上端からの距離10.7、座面は柱側へ0.2寄せて4.4。
    reflected = work / "reflected.scad"
    reflected.write_text(f'mirror([1,-1,0]) import("{foot}");\n')
    mirrored = work / "reflected.stl"
    render(reflected, mirrored, binary=True)
    for part in [foot, mirrored]:
        for y, flat in [(0.1, 6.4), (4.39, 6.4), (4.41, 10.4), (7, 10.4)]:
            r = flat / math.sqrt(3)
            loop_at(section(part, work, "y", y), (15.7 - r, 15.7 + r, 19.2 - flat / 2, 19.2 + flat / 2))
        loops = section(part, work, "y", 15.7)
        empty_rect(loops, (-1, 4.39, 16.01, 22.39))
        empty_rect(loops, (4.41, 15.69, 14.01, 24.39))

    bolts = ROOT / "modules/bolts.scad"
    helpers = ROOT / "modules/slide_rail_outer_bracket.scad"
    def no_collision(geometry):
        source, output = work / "collision.scad", work / "collision.stl"
        source.write_text(f'use <{bolts}>\nuse <{helpers}>\ntranslate([40,0,0]) cube(1);\n{geometry}\n')
        render(source, output, binary=True)
        near(bounds(closed_mesh(output)), (40, 41, 0, 1, 0, 1))

    # M6は内側へ斜めに差し入れ、0.15だけ横へ逃がした姿勢で座面へ寄せる。
    # M8はまだ入れない。軸方向の終点は座面から5µm離して検査する。
    waypoints = [(32, 32, 19.2), (17, 17, 19.2), (17, 15.85, 19.2), (6.905, 15.85, 19.2), (6.905, 15.7, 19.2)]
    m6_path = 'union() {' + ''.join(
        f'hull() {{ translate({list(a)}) hex_x_flat_up(10,5); translate({list(b)}) hex_x_flat_up(10,5); }}'
        for a, b in zip(waypoints, waypoints[1:])
    ) + '}'
    m6_y_path = f'mirror([1,-1,0]) {{ {m6_path} }}'
    for path in [m6_path, m6_y_path]:
        no_collision(f'intersection() {{ import("{foot}"); {path} }}')
    m6_x_nut = 'translate([6.9,15.7,19.2]) hex_x_flat_up(10,5);'
    no_collision(f'intersection() {{ {m6_y_path} {m6_x_nut} }}')

    # AF13×厚6.5の金属ナットの着座位置。ゼロ厚接触を除くため座面から5µm浮かせる。
    nut = 'translate([17,17,9.205]) rotate([0,0,15]) nut_trap(13,6.5,center=false);'
    # ナット中央をM6中心高さに揃えて内側から差し入れ、その後、座面まで下げる。
    entry_nut = f'translate([0,0,15.95-9.205]) {{ {nut} }}'
    m8_path = f'union() {{ hull() {{ {nut} {entry_nut} }} hull() {{ {entry_nut} translate([13,13,0]) {{ {entry_nut} }} }} }}'
    no_collision(f'intersection() {{ import("{foot}"); {m8_path} }}')
    # M6ナットを先に入れ、M8を入れてからM6ボルトを締める。
    m6_nuts = f'{m6_x_nut} mirror([1,-1,0]) {{ {m6_x_nut} }}'
    # AF13.3窪み内でM8が寄り得る全範囲と、着座したM6ナットとの非干渉。
    nut_envelope = 'translate([17,17,9.205]) rotate([0,0,15]) nut_trap(13.3,6.5,center=false);'
    no_collision(f'intersection() {{ {nut_envelope} union() {{ {m6_nuts} }} }}')
    no_collision(f'intersection() {{ {m8_path} union() {{ {m6_nuts} }} }}')
    # M8軸は底板より上のR5も通過できること。M6×12の軸も同時に検査。
    m6_shanks = '''
      translate([-2,15.7,19.2]) rotate([0,90,0]) cylinder(d=6,h=12,$fn=48);
      translate([15.7,-2,19.2]) rotate([-90,0,0]) cylinder(d=6,h=12,$fn=48);
    '''
    shanks = 'translate([17,17,-1]) cylinder(d=8,h=32,$fn=64);' + m6_shanks
    no_collision(f'intersection() {{ import("{foot}"); union() {{ {shanks} }} }}')
    # 厚6.5のM8ナットは床から1.7突出するが、横のM6軸とも干渉しない。
    no_collision(f'intersection() {{ {nut_envelope} union() {{ {m6_shanks} }} }}')

    # 上下のパーツを受けるL字端面は連続した接触面として残す。
    acrylic = work / "acrylic.stl"
    render(ROOT / "assets/steel-rack/500x400/corner_acrylic_support.scad", acrylic, binary=True)
    contact = section(foot, work, "z", 29.89)
    assert len(contact) == 1, "L contact face is disconnected"
    outline = contact[0]
    contact_area = abs(sum(x * by - bx * y for (x, y), (bx, by) in zip(outline, outline[1:] + outline[:1]))) / 2
    assert contact_area > 400, ("lost L contact area", contact_area)

    # 使用姿勢は脚の平面が下、アクリル受けの平面が上。公称Z=29.9で接触。
    # STL座標丸めのゼロ厚接触を除くため、衝突検査では上側を5µm離す。
    no_collision(f'intersection() {{ import("{foot}"); translate([0,0,55.805]) rotate(a=180,v=[1,1,0]) import("{acrylic}"); }}')
    assembled = work / "upper.scad"
    assembled.write_text(f'translate([0,0,55.8]) rotate(a=180,v=[1,1,0]) import("{acrylic}");\n')
    upper = work / "upper.stl"
    render(assembled, upper, binary=True)
    r = 6.4 / math.sqrt(3)
    loop_at(section(upper, work, "y", 0.1), (15.7 - r, 15.7 + r, 37.4, 43.8))
    # 実測した上穴Z40.6と下穴Z19.2は中心間21.4。
    # φ6を7×30長穴の上端に寄せると、下側の軸外縁〜長穴下端は2.6mm。
    print("corner-rubber-foot: M8 bearing seat/entry, both M6 holes, R5 shaft clearance and 21.4mm assembly passed")
