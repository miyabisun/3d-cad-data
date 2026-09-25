#!/usr/bin/env python3
"""production STLの寸法、R形状、ナット挿入と金属部品の非干渉を確認する。"""

from pathlib import Path
import math
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]

def check_support(source, height, m6_levels):
    with tempfile.TemporaryDirectory(prefix="corner-acrylic-support-") as temp:
        work = Path(temp)
        assert source.is_file(), "corner acrylic support is missing"
        stl = work / "support.stl"
        render(source, stl, binary=True)
        near(bounds(closed_mesh(stl)), (0, 27, 0, 27, 0, height))

        for z in [0.1, 6.59]:
            loops = section(stl, work, "z", z)
            loop_at(loops, (14.8, 19.2, 14.8, 19.2))  # M4: 中心17×17、φ4.4
            outline = loop_at(loops, (0, 27, 0, 27))
            for cx, cy, r, select in [
                (2, 2, 2, lambda x, y: x < 1.99 and y < 1.99),
                (17, 17, 10, lambda x, y: x > 17.01 and y > 17.01),
            ]:
                arc = [(x, y) for x, y in outline if select(x, y)]
                assert len(arc) > 8, "corner radius is missing"
                assert all(abs(math.hypot(x - cx, y - cy) - r) < 0.03 for x, y in arc)
        m4_radius = 7.4 / math.sqrt(3)
        for z in [6.61, 9.99]:
            loop_at(section(stl, work, "z", z), (17 - m4_radius, 17 + m4_radius, 13.3, 20.7))

        # 壁同士のR5: 穴より上の断面を測る。
        loops = section(stl, work, "z", height - 1.9)
        arc = [(x, y) for loop in loops for x, y in loop if 10.01 < x < 14.99 and 10.01 < y < 14.99]
        assert len(arc) > 8
        assert all(abs(math.hypot(x - 15, y - 15) - 5) < 0.03 for x, y in arc)
        assert inside(loops, (11, 11)) and not inside(loops, (12, 12))

        # M6ナットの切削を直交穴の中心で止め、向こう側の壁を残す。
        for z in m6_levels:
            loops = section(stl, work, "z", z + 0.1)
            for entry, beyond in [((15.6, 9.8), (22, 9.8)), ((9.8, 15.6), (9.8, 22))]:
                assert not inside(loops, entry)
                assert inside(loops, beyond), "M6 nut corridor cuts the opposite wall"

        # X/Y両面を同じ測り方で検証。実STLを鏡映し、片側の穴欠落も検出する。
        reflected = work / "reflected.scad"
        reflected.write_text(f'mirror([1,-1,0]) import("{stl}");\n')
        mirror_stl = work / "reflected.stl"
        render(reflected, mirror_stl, binary=True)
        for part in [stl, mirror_stl]:
            for y, flat in [(0.1, 6.4), (4.59, 6.4), (4.61, 10.4), (7, 10.4)]:
                r = flat / math.sqrt(3)
                loops = section(part, work, "y", y)
                assert len(loops) == 1 + len(m6_levels), "unexpected M6 hole remains"
                for z in m6_levels:
                    loop_at(loops, (15.7 - r, 15.7 + r, z - flat / 2, z + flat / 2))
            loops = section(part, work, "y", 15.7)
            for z in m6_levels:
                empty_rect(loops, (-1, 4.59, z - 3.19, z + 3.19))
                empty_rect(loops, (4.61, 15.69, z - 5.19, z + 5.19))
            # 底板と壁のR5。ナット経路が切り欠く範囲を除いて実曲面を測る。
            loops = section(part, work, "y", 24)
            arc = [(x, z) for loop in loops for x, z in loop if 10 < x < 12 and 11.5 < z < 14.5]
            assert len(arc) > 5, "floor-to-wall R5 is missing"
            assert all(abs(math.hypot(x - 15, z - 15) - 5) < 0.03 for x, z in arc)

        # M6ナットAF10×厚5。座面へ密着した状態と、窪み内で角側へ寄った状態。
        # 空intersectionは離れた1mm立方体だけが残ることで検出する。
        helpers = ROOT / "modules/slide_rail_outer_bracket.scad"
        bolts = ROOT / "modules/bolts.scad"
        def no_collision(geometry):
            source, output = work / "collision.scad", work / "collision.stl"
            source.write_text(f'use <{helpers}>\nuse <{bolts}>\ntranslate([40,0,0]) cube(1);\n{geometry}\n')
            render(source, output, binary=True)
            near(bounds(closed_mesh(output)), (40, 41, 0, 1, 0, 1))

        for z in m6_levels:
            for shift in [0, 0.4 / math.sqrt(3)]:
                a = f'translate([7.1,{15.7-shift},{z}]) hex_x_flat_up(10,5);'
                b = f'translate([{15.7-shift},7.1,{z}]) hex_y_flat_up(10,5);'
                no_collision(f'intersection() {{ {a} {b} }}')
                # 着座時の嵌合。挿入は下の有限経路で別途検査する。
                for nut, vector in [(a, [30, 0, 0]), (b, [0, 30, 0])]:
                    # 座面・限界位置の側面接触から5µm離し、STL丸めによるゼロ厚面を除く。
                    clearance = [0.005, 0.005, 0] if shift else [0.005 if value else 0 for value in vector]
                    no_collision(f'intersection() {{ import("{stl}"); translate({clearance}) {{ {nut} }} }}')
            # 内側から斜めに入れ、横へ0.15・上へ0.1逃がした姿勢で座面へ寄せる。
            waypoints = [(32, 32, z + 0.1), (16.1, 17, z + 0.1), (16.1, 15.85, z + 0.1), (7.105, 15.85, z + 0.1), (7.105, 15.7, z)]
            path_x = 'union() {' + ''.join(
                f'hull() {{ translate({list(a)}) hex_x_flat_up(10,5); translate({list(b)}) hex_x_flat_up(10,5); }}'
                for a, b in zip(waypoints, waypoints[1:])
            ) + '}'
            path_y = f'mirror([1,-1,0]) {{ {path_x} }}'
            for path in [path_x, path_y]:
                no_collision(f'intersection() {{ import("{stl}"); {path} }}')
            seated_x = f'translate([7.1,15.7,{z}]) hex_x_flat_up(10,5);'
            no_collision(f'intersection() {{ {path_y} {seated_x} }}')
        m4 = 'translate([17,17,6.605]) nut_trap(d=7,h=3.2,center=false);'
        no_collision(f'intersection() {{ import("{stl}"); hull() {{ {m4} translate([0,0,{height}]) {{ {m4} }} }} }}')
        # 板厚2にM6×12、アクリル厚5にM4×16を通したときの軸部分の経路。
        shanks = 'translate([17,17,-5]) cylinder(d=4,h=16,$fn=48);'
        for z in m6_levels:
            shanks += f"""
              translate([-2,15.7,{z}]) rotate([0,90,0]) cylinder(d=6,h=12,$fn=48);
              translate([15.7,-2,{z}]) rotate([-90,0,0]) cylinder(d=6,h=12,$fn=48);
            """
        no_collision(f'intersection() {{ import("{stl}"); union() {{ {shanks} }} }}')
        print(f"{source.stem}: dimensions, {2 * len(m6_levels)} M6 seats/entries, M4 pocket, R2/R5/R10 and nut clearance passed")


for index, (name, height, levels) in enumerate([
    ("corner_acrylic_support", 25.9, [15.2]),
    # 厚5のアクリル上面=柱上端。座面は柱上端から5mm下。
    # φ6軸を長穴端38.5/58.5へ当てるため、座面基準の中心は30.5/56.5。
    ("corner_acrylic_support_top", 67.2, [30.5, 56.5]),
], 1):
    source = Path(sys.argv[index]).resolve() if len(sys.argv) > index else ROOT / f"assets/steel-rack/500x400/{name}.scad"
    check_support(source, height, levels)
