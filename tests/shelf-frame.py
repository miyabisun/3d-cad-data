#!/usr/bin/env python3
"""30cm材のケース棚の枠: 角・筋交い・辺の支えをproduction STLで実測し、組付けの非干渉を確かめる。

座標は手前左の柱の内側2面の交点が原点、+X がラック右、+Y が奥、Z=0 が30cm材の下面。
柱の内角どうしは500×400。30cm材は9.1mm面を外(縦)、7.7mm面を下にし、外面を柱の内面にそろえる。
"""

import math
from pathlib import Path
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, overhangs, render, render_many, section

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "assets/steel-rack/500x400/shelf_frame"

# 30cm材の実測: 長穴30×7、穴間20、6個。縁は自由端から外(縦)面9.1・下面7.7。
OUTER_SLOT_Z = 30 - 9.1 - 3.5  # 17.4
BOTTOM_SLOT_Y = 30 - 7.7 - 3.5  # 18.8
FRONT_SLOTS = [125 + 50 * i for i in range(6)]  # 500の辺の中央に置いた長穴の中心
SIDE_SLOTS = [75 + 50 * i for i in range(6)]  # 400の辺
COLUMN_SLOT = 29.2 - 2 - 8 - 3.5  # 15.7
CASE = (35, 465, 80, 320)  # 430×240を中央に置いた外形


def hex_r(flat):
    return flat / math.sqrt(3)


def use_corner(stl):
    return f'rotate([180,0,0]) translate([0,0,-30]) import("{stl}");'


def use_flat(stl):
    return f'translate([0,0,2]) import("{stl}");'


def stadium(length, width):
    """2D の長穴。中心が原点、長手が X。"""
    return f"hull() for (s=[-1,1]) translate([s*{(length - width) / 2},0]) circle(d={width},$fn=48);"


def angle_x(x0, slots):
    """X 方向に延びる30cm材 (手前の辺)。接触面は 5µm 退かせて面積0の交差を避ける。"""
    profile = ("union() { translate([-0.005,0]) square([2,30]); square([30,1.995]);"
               " translate([1.995,1.995]) difference() { square(3); translate([3,3]) circle(r=3,$fn=48); } }")
    outer = "".join(f"translate([{x},-1,{OUTER_SLOT_Z}]) rotate([-90,0,0]) linear_extrude(4) {stadium(30, 7)}" for x in slots)
    bottom = "".join(f"translate([{x},{BOTTOM_SLOT_Y},-1]) linear_extrude(4) {stadium(30, 7)}" for x in slots)
    return (f"difference() {{ translate([{x0},0,0]) rotate([90,0,90]) linear_extrude(295) {profile}"
            f" {outer} {bottom} }}")


def environment():
    """手前左の柱 (90cm材の2面、長穴付き) と手前・左の30cm材。7.7mmの端を柱側に置く。"""
    column = (f"difference() {{ union() {{ translate([-2,-2,-20]) cube([29.2,1.995,70]);"
              f" translate([-2,-2,-20]) cube([1.995,29.2,70]); }}"
              f" translate([{COLUMN_SLOT},-3,15]) rotate([-90,0,0]) linear_extrude(4) rotate(90) {stadium(30, 7)}"
              f" translate([-3,{COLUMN_SLOT},15]) rotate([0,90,0]) linear_extrude(4) {stadium(30, 7)} }}")
    front = angle_x(FRONT_SLOTS[0] - 15 - 7.7, FRONT_SLOTS)
    side = f"mirror([1,-1,0]) {angle_x(SIDE_SLOTS[0] - 15 - 7.7, SIDE_SLOTS)}"
    return f"union() {{ {column} {front} {side} }}"


def shank(start, axis, length=14):
    rot = {"x": "[0,90,0]", "y": "[-90,0,0]", "z": "[0,0,0]"}[axis]
    return f"translate({list(start)}) rotate({rot}) cylinder(d=6,h={length},$fn=48);"


def nut_path(center, axis):
    """AF10×厚5のナットを座面へ置いた姿勢と、上 (Z=40) から落とし込む経路。"""
    x, y, z = center
    if axis in ("zx", "zy"):  # 鉛直ボルト: 二面を材の長手 (zx: X方向の材) と直交させ、窪みへ上から入れる
        turn = "rotate(90)" if axis == "zx" else ""
        nut = f"{turn} linear_extrude(5) circle(d={10 / math.cos(math.pi / 6)},$fn=6);"
        return f"hull() {{ translate([{x},{y},{z}]) {nut} translate([{x},{y},40]) {nut} }}"
    # 水平ボルト: 二面を水平にした六角 (flat-up) を上から溝へ落とし、下半分の六角の受けに座らせる
    turn = "rotate([-90,0,0])" if axis == "y" else "rotate([0,90,0]) rotate(90)"
    nut = f"{turn} linear_extrude(5) circle(d={10 / math.cos(math.pi / 6)},$fn=6);"
    return f"hull() {{ translate([{x},{y},{z}]) {nut} translate([{x},{y},40]) {nut} }}"


def fasteners():
    """M6の軸 (M6×12に長さの公差2mmを足して座面から14mm) と、座ったナットの経路。"""
    shanks, nuts = [], []
    # 柱: 外から2面へ。樹脂の座面4.6、ナットは柱面から4.6..9.6。
    shanks += [shank((COLUMN_SLOT, -2, 15), "y"), shank((-2, COLUMN_SLOT, 15), "x")]
    nuts += [nut_path((COLUMN_SLOT, 4.605, 15), "y"), nut_path((4.605, COLUMN_SLOT, 15), "x")]
    # 角 ↔ 30cm材の縦面: 1番目の長穴の両端へ当てる2本。
    for x in [FRONT_SLOTS[0] - 12, FRONT_SLOTS[0] + 12]:
        shanks.append(shank((x, 0, OUTER_SLOT_Z), "y"))
        nuts.append(nut_path((x, 6.605, OUTER_SLOT_Z), "y"))
    for y in [SIDE_SLOTS[0] - 12, SIDE_SLOTS[0] + 12]:
        shanks.append(shank((0, y, OUTER_SLOT_Z), "x"))
        nuts.append(nut_path((6.605, y, OUTER_SLOT_Z), "x"))
    # 筋交いと辺の支え: 下面の長穴へ下から。
    vertical = [(x, BOTTOM_SLOT_Y) for x in [FRONT_SLOTS[1] - 12, FRONT_SLOTS[1] + 12, 237, 263]]
    vertical += [(BOTTOM_SLOT_Y, y) for y in [SIDE_SLOTS[1] - 12, SIDE_SLOTS[1] + 12, 187, 213]]
    for x, y in vertical:
        shanks.append(shank((x, y, 0), "z"))
        nuts.append(nut_path((x, y, 6.605), "zx" if y == BOTTOM_SLOT_Y else "zy"))
    return "union() {" + "".join(shanks) + "}", "union() {" + "".join(nuts) + "}"


def case_skirt():
    """旧ケースと同じく外周の壁 (厚1.2) が下へ12.5mm垂れると仮定した、柱の外側の帯。"""
    x0, x1, y0, y1 = CASE
    return (f"translate([0,0,17.5]) linear_extrude(12.5) difference() {{"
            f" translate([{x0},{y0}]) square([{x1 - x0},{y1 - y0}]);"
            f" translate([{x0 + 1.2},{y0 + 1.2}]) square([{x1 - x0 - 2.4},{y1 - y0 - 2.4}]); }}")


def check(work, stls):
    def no_collision(a, b):
        source, output = work / "collision.scad", work / "collision.stl"
        source.write_text(f"translate([600,0,0]) cube(1);\nintersection() {{ {a} union() {{ {b} }} }}\n")
        render(source, output, binary=True)
        near(bounds(closed_mesh(output)), (600, 601, 0, 1, 0, 1))

    def use_stl(name, transform):
        source, output = work / f"{name}-use.scad", work / f"{name}-use.stl"
        source.write_text(transform(stls[name]) + "\n")
        render(source, output, binary=True)
        return output

    corner = use_stl("corner_l", use_corner)
    brace = use_stl("brace_l", use_flat)
    mid_front = use_stl("mid_front", use_flat)
    mid_side = use_stl("mid_side", use_flat)

    # 印刷向き: 角は上面を、ほかは土台の下面をビルドプレートへ置く。
    near(bounds(closed_mesh(stls["corner_l"])), (0, 149, -99, 0, 0, 30))
    near(bounds(closed_mesh(corner)), (0, 149, 0, 99, 0, 30))
    near(bounds(closed_mesh(stls["brace_l"]))[4:], (0, 28))
    near(bounds(closed_mesh(brace)), (2.3, 198.2, 2.3, 148.2, 2, 30))
    near(bounds(closed_mesh(mid_front)), (225.8, 274.2, 2.3, 102, 2, 30))
    near(bounds(closed_mesh(mid_side)), (2.3, 57, 175.8, 224.2, 2, 30))

    # 印刷向きで下を向き45度より寝た面は、角の水平M6の通し穴とナット溝の天井 (flat-upの短いブリッジ) だけ。
    # 柱へのM6は使用時Z=15、30cm材へのM6はZ=17.4。上下反転した印刷では、通し穴 (AF6.4) の上端が
    # 18.2・15.8、ナット溝 (AF10.4) の受けの底が20.2・17.8になる。
    assert overhangs(stls["corner_l"]) == {15.8, 17.8, 18.2, 20.2}, overhangs(stls["corner_l"])
    for name in ["brace_l", "mid_front", "mid_side"]:
        assert overhangs(stls[name]) == set(), (name, overhangs(stls[name]))

    # 角: 上面はL字の全面 (印刷時の接地面)。内隅R10・柱の角R2。
    top = section(corner, work, "z", 29.9)
    outline = loop_at(top, (0, 149, 0, 99))
    for cx, cy, r, select in [(40, 40, 10, lambda x, y: 30.01 < x < 39.99 and 30.01 < y < 39.99),
                              (2, 2, 2, lambda x, y: x < 1.99 and y < 1.99)]:
        arc = [(x, y) for x, y in outline if select(x, y)]
        assert len(arc) > 5, "corner radius is missing"
        assert all(abs(math.hypot(x - cx, y - cy) - r) < 0.03 for x, y in arc)
    # 角の断面: 隙間を埋める区間は30角、30cm材に入る腕は縦面2・下面2.3を逃がし、曲げRを45°で落とす。
    loop_at(section(corner, work, "x", 60), (0, 30, 0, 30))
    arm = section(corner, work, "x", 120)
    loop_at(arm, (2, 30, 2.3, 30))
    assert not inside(arm, (2.5, 3.5)) and inside(arm, (2.5, 5.5)) and inside(arm, (5.5, 2.6))
    # 柱へのM6: 通しAF6.4 (flat-up) と、上へ抜けるナット溝 (AF10.4)。
    for axis in ["y", "x"]:
        loops = section(corner, work, axis, 1)
        r = hex_r(6.4)
        loop_at(loops, (COLUMN_SLOT - r, COLUMN_SLOT + r, 15 - 3.2, 15 + 3.2))
        loops = section(corner, work, axis, 7.3)
        empty_rect(loops, (COLUMN_SLOT - 5.19, COLUMN_SLOT + 5.19, 15, 30.01))
        assert inside(loops, (COLUMN_SLOT, 9.7)), "nut channel must stop at the hex seat"
    # 30cm材へのM6: 縦面の長穴の両端へ当てる2本ずつ。
    for axis, slots in [("y", FRONT_SLOTS), ("x", SIDE_SLOTS)]:
        loops = section(corner, work, axis, 4)
        for c in [slots[0] - 12, slots[0] + 12]:
            loop_at(loops, (c - hex_r(6.4), c + hex_r(6.4), OUTER_SLOT_Z - 3.2, OUTER_SLOT_Z + 3.2))
        loops = section(corner, work, axis, 9.3)
        for c in [slots[0] - 12, slots[0] + 12]:
            empty_rect(loops, (c - 5.19, c + 5.19, OUTER_SLOT_Z, 30.01))

    # 筋交い: 下面の2番目の長穴の両端へ2本ずつ、柱はケースの角から2mm内側。
    for part, holes, post in [
        (brace, [(x, BOTTOM_SLOT_Y) for x in [163, 187]] + [(BOTTOM_SLOT_Y, y) for y in [113, 137]], (37, 57, 82, 102)),
        (mid_front, [(237, BOTTOM_SLOT_Y), (263, BOTTOM_SLOT_Y)], (240, 260, 82, 102)),
        (mid_side, [(BOTTOM_SLOT_Y, 187), (BOTTOM_SLOT_Y, 213)], (37, 57, 190, 210)),
    ]:
        loops = section(part, work, "z", 4)
        for x, y in holes:
            loop_at(loops, (x - 3.2, x + 3.2, y - 3.2, y + 3.2))
        # ナット窪みAF10.4: 二面を材の長手と直交させ、長手方向の幅を5.2に抑える。
        loops = section(part, work, "z", 9)
        for x, y in holes:
            along_x = y == BOTTOM_SLOT_Y
            rx, ry = (5.2, hex_r(10.4)) if along_x else (hex_r(10.4), 5.2)
            loop_at(loops, (x - rx, x + rx, y - ry, y + ry))
        loop_at(section(part, work, "z", 20), post)
        loop_at(section(part, work, "z", 29.9), post)

    # 組付け: 柱・30cm材・ボルト軸・ナット経路・ケースの垂れ壁と部品が交差しない。
    env = environment()
    shanks, nuts = fasteners()
    for part in [corner, brace, mid_front, mid_side]:
        no_collision(f'import("{part}");', env + shanks + nuts + case_skirt())
    no_collision(f'import("{corner}");', f'import("{brace}");')
    no_collision(shanks, env)  # ボルト軸は長穴の中を通る

    # 右用は左用の鏡像。
    for name in ["corner", "brace"]:
        mirrored = work / f"{name}-mirror.scad"
        mirrored.write_text(f'mirror([1,0,0]) import("{stls[name + "_r"]}");\n')
        output = work / f"{name}-mirror.stl"
        render(mirrored, output, binary=True)
        left = stls[name + "_l"]
        near(bounds(closed_mesh(output)), bounds(closed_mesh(left)))
        for z in [1, 5, 15, 25]:
            a = sorted(bounds(p) for p in section(output, work, "z", z))
            b = sorted(bounds(p) for p in section(left, work, "z", z))
            assert len(a) == len(b) and all(abs(u - v) < 0.03 for p, q in zip(a, b) for u, v in zip(p, q)), (name, z)


names = ["corner_l", "corner_r", "brace_l", "brace_r",
         "mid_front", "mid_side"]
with tempfile.TemporaryDirectory(prefix="shelf-frame-") as temp:
    work = Path(temp)
    for name in names:
        assert (DIR / f"{name}.scad").is_file(), f"{name}.scad is missing"
    stls = {name: work / f"{name}.stl" for name in names}
    render_many([(DIR / f"{name}.scad", stls[name], ()) for name in names])
    check(work, stls)
print("shelf frame: corner/brace/mid dimensions, M6 seats, print orientation, mirror and assembly clearance passed")
