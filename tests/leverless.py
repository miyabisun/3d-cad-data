#!/usr/bin/env python3
"""レバーレス筐体の印刷部品・ナット挿入経路をproduction STLで実測する。"""

from pathlib import Path
from functools import cache
import math
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/leverless/controller.scad"


with tempfile.TemporaryDirectory(prefix="leverless-test-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "leverless/controller.scad is missing"
    volumes = {}
    measured_buttons = {}
    measured_auxiliary = {}
    pcb_rect = (72.99, 169.149, 22.99, 68.222)
    usb_rect = (169.149, 194.149, 40.352, 50.352)

    def inner_round(loops, center, x_sign=1):
        arc = [p for loop in loops for p in loop
               if 0.01 < (p[0] - center[0]) * x_sign < 2.99 and 0.01 < p[1] - center[1] < 2.99]
        assert len(arc) >= 10, "exposed inside corner R3 missing"
        assert all(abs(math.dist(p, center) - 3) < 0.03 for p in arc)
        for angle in range(5, 90, 5):
            dx, dy = x_sign * math.cos(math.radians(angle)), math.sin(math.radians(angle))
            assert inside(loops, (center[0] + 2.95 * dx, center[1] + 2.95 * dy))
            assert not inside(loops, (center[0] + 3.05 * dx, center[1] + 3.05 * dy))

    def volume(vertices):
        terms = []
        for i in range(0, len(vertices), 3):
            p, q, r = vertices[i:i + 3]
            terms.append((p[0] * (q[1] * r[2] - q[2] * r[1]) + p[1] * (q[2] * r[0] - q[0] * r[2]) + p[2] * (q[0] * r[1] - q[1] * r[0])) / 6)
        return math.fsum(terms)

    def part(name, size, extra=(), x_margin=0):
        stl = work / f"{name}.stl"
        render(SOURCE, stl, (f'part="{name}"', *extra), binary=True)
        vertices = closed_mesh(stl)
        near(bounds(vertices), (x_margin, size[0] - x_margin, 0, size[1], 0, size[2]))
        assert max(size) <= 256, "part exceeds the P1S build volume"
        if not extra:
            volumes[name] = volume(vertices)
        return cache(lambda axis, pos: section(stl, work, axis, pos))

    def hex_at(loops, x, y, flat):
        loop = loop_at(loops, (x - flat / math.sqrt(3), x + flat / math.sqrt(3), y - flat / 2, y + flat / 2))
        for px, py in loop:
            support = max((px - x) * math.cos(math.radians(a)) + (py - y) * math.sin(math.radians(a)) for a in range(30, 390, 60))
            assert abs(support - flat / 2) < 0.03, "horizontal hole is not a flat-up hexagon"
        top = [p for p in loop if abs(p[1] - y - flat / 2) < 0.01]
        assert len(top) >= 2 and max(p[0] for p in top) - min(p[0] for p in top) >= flat / math.sqrt(3) - 0.03, "bridge ceiling is missing"

    def round_at(loops, x, y, radius):
        loop = loop_at(loops, (x - radius, x + radius, y - radius, y + radius))
        assert len(loop) >= 32 and all(abs(math.hypot(px - x, py - y) - radius) < 0.03 for px, py in loop), "countersink is not round"

    def m4_seat(cut, x, y, thickness, up=True):
        # 外面から0.2mmまではφ8.4、その奥2mmが90度テーパ、以降はφ4.4。
        for depth, radius in [(0.1, 4.2), (0.19, 4.2), (0.4, 4), (1.2, 3.2), (2.21, 2.2), (thickness - 0.1, 2.2)]:
            round_at(cut("z", thickness - depth if up else depth), x, y, radius)

    def slot_frame(loops, x, corner=False):
        # 生産STLのXY断面を挿入方向に合わせる。隅柱はL字の開口に向かう45度。
        angle = math.radians(-45 if corner else 0)
        c, s = math.cos(angle), math.sin(angle)
        return [[((px - x) * c + (py - 10) * s, -(px - x) * s + (py - 10) * c) for px, py in loop] for loop in loops]

    def planar_entry(loops, mirrored=False):
        if mirrored:
            loops = [[(40 - x, y) for x, y in loop] for loop in loops]
        # STLの三角形で分割された同一直線上の頂点も許容し、全点の共面性を測る。
        face = [p for loop in loops for p in loop if 19.99 <= p[0] <= 25.51 and 19.99 <= p[1] <= 25.51]
        for end in [(25.5, 20), (20, 25.5)]:
            assert any(math.dist(p, end) < 0.01 for p in face), "inner chamfer does not cover the whole nut entry"
        assert all(abs(x + y - 45.5) < 0.01 for x, y in face), "inner corner is not planar at 45 degrees"
        local = slot_frame(loops, 10, True)
        face_v = 25.5 / math.sqrt(2)
        empty_rect(local, (-3.65, 3.65, face_v + 0.01, face_v + 0.5))
        assert all(inside(local, (u, face_v - 0.1)) for u in [-3.6, 0, 3.6]), "nut entry has a curved or stepped ceiling"

    plug_sizes = {}
    for name, length in [("corner_nut_plug", 14.989768), ("center_nut_plug", 6.958548)]:
        part(name, (6.9, length, 3.1))
        x0, x1, y0, y1, z0, z1 = bounds(closed_mesh(work / f"{name}.stl"))
        plug_sizes[name] = (x1 - x0, y1 - y0, z1 - z0)

    def plug_fit(cut, x, corner=False, mirrored=False):
        width, length, height = plug_sizes["corner_nut_plug" if corner else "center_nut_plug"]
        # 溝に収まる六角ナット先端へ当て、実測した栓の外端が入口から1mm出る。
        tip = 7 / math.sqrt(3)
        face = 25.5 / math.sqrt(2) if corner else 10
        near((7.3 - width, 3.5 - height, tip + length - face), (0.4, 0.4, 1))

        def local_at(z):
            loops = cut("z", z)
            if mirrored:
                loops = [[(40 - px, py) for px, py in loop] for loop in loops]
            return slot_frame(loops, x, corner)

        face_section = local_at(20)
        assert inside(face_section, (0, face - 0.02)) and not inside(face_section, (0, face + 0.02))
        for base in [5, 41.5]:
            for z in [base + 0.21, base + 0.2 + height / 2, base + 0.2 + height - 0.01]:
                empty_rect(local_at(z), (-width / 2, width / 2, tip, tip + length))

    for name, width, depth, centers, side_centers in [
        ("corner_post", 40, 40, [10], [30]), ("center_post", 80, 20, [30, 50], [10, 70])]:
        cut = part(name, (width, depth, 50))
        for x in centers:
            plug_fit(cut, x, corner=name == "corner_post")
        for x in centers:
            # 縦断面全体を測り、止まり穴の天井や中間の膜が残っていないことを確認する。
            empty_rect(cut("y", 10), (x - 2.19, x + 2.19, -0.1, 50.1))
            for z in [12.01, 25, 37.99]:
                loop_at(cut("z", z), (x - 2.2, x + 2.2, 7.8, 12.2))
        for z in [1, 20, 49]:
            for center in ([(37, 17), (17, 37)] if name == "corner_post" else [(77, 17), (3, 17)]):
                inner_round(cut("z", z), center, -1 if center[0] == 3 else 1)
        for z in [1, 4.99, 45.81, 49]:
            roof = cut("z", z)
            for x in centers:
                loop_at(roof, (x - 2.2, x + 2.2, 7.8, 12.2))
                assert inside(roof, (x + 3, 10)), "nut roof is missing"
        for z in [5.01, 8.49, 41.51, 44.99]:
            slot = cut("z", z)
            for x in centers:
                local = slot_frame(slot, x, name == "corner_post")
                empty_rect(local, (-3.65, 3.65, -2, 45))
                assert inside(local, (3.7, 5)), "nut cannot resist rotation"
                if name == "corner_post":
                    assert inside(slot, (10, 35)) and inside(slot, (35, 10)), "nut entry still opens at the arm end"
                    empty_rect(slot, (20, 22, 20, 22))
        # 印刷の+Z方向へ、横長帯0.4 → 正方形0.4 → 丸穴。底用も反転しない。
        for ceiling in [8.5, 45]:
            band = cut("z", ceiling + 0.2)
            square = cut("z", ceiling + 0.6)
            circle = cut("z", ceiling + 0.81)
            for x in centers:
                local_band, local_square, local_circle = [slot_frame(loops, x, name == "corner_post") for loops in [band, square, circle]]
                loop_at(local_band, (-3.65, 3.65, -2.215625, 2.215625))
                empty_rect(local_band, (-3.65, 3.65, -2.215625, 2.215625))
                assert inside(local_band, (0, 3)), "first bridge has no landing"
                loop_at(local_square, (-2.215625, 2.215625, -2.215625, 2.215625))
                empty_rect(local_square, (-2.215625, 2.215625, -2.215625, 2.215625))
                assert inside(local_square, (3, 0)), "second bridge has no landing"
                assert inside(local_circle, (2, 2)), "square relief continues into the bore"
        for x in side_centers:
            hex_at(cut("y", 10), x, 25, 4.4)
            hex_at(cut("y", 18), x, 25, 7.3)
        if name == "center_post":
            loop_at(cut("y", 2), (20, 60, 0, 50))
        if name == "corner_post":
            plan = cut("z", 20)
            assert not inside(plan, (30, 30))
            assert inside(plan, (10, 25)) and inside(plan, (25, 10))
            arc = [p for loop in plan for p in loop if 0.01 < p[0] < 2.99 and 0.01 < p[1] < 2.99]
            assert len(arc) >= 10, "outside R3 missing"
            assert all(abs(math.dist(p, (3, 3)) - 3) < 0.03 for p in arc)
            # 内隅はC5.5の1本の直線。幅7.3の入口全部が同じ平面に収まる。
            for z in [1, 8.6, 20, 45.1, 49]:
                planar_entry(cut("z", z))
            empty_rect(cut("z", 25), (5, 20.1, 28.91, 31.09))
            # 横ネジの軸は別々の腕にあり、縦の貫通穴の周囲にも肉が残る。
            assert inside(cut("z", 25), (10, 17))

    cut = part("corner_post_right", (40, 40, 50))
    plug_fit(cut, 10, corner=True, mirrored=True)
    empty_rect(cut("y", 10), (27.81, 32.19, -0.1, 50.1))
    loop_at(cut("z", 25), (27.8, 32.2, 7.8, 12.2))
    assert not inside(cut("z", 20), (10, 30)) and inside(cut("z", 20), (30, 30))

    for z in [1, 8.6, 20, 45.1, 49]:
        planar_entry(cut("z", z), mirrored=True)
    for center in [(3, 17), (23, 37)]:
        inner_round(cut("z", 20), center, -1)

    for name, length in [("wall", 160)]:
        cut = part(name, (length, 50, 5), x_margin=0.25)
        for x in [10, length - 10]:
            m4_seat(cut, x, 25, 5, up=False)
        for z in [0.1, 2, 4.9]:
            plan = cut("z", z)
            assert len(loop_at(plan, (0.25, length - 0.25, 0, 50))) == 4, "wall perimeter is not a rectangle"
            for x in [1, 10, length - 10, length - 1]:
                assert inside(plan, (x, 0.1)) and inside(plan, (x, 49.9)), "wall still has an end tab or bevel"

    for name, thickness in [("top_left", 6), ("top_right", 6), ("bottom", 5)]:
        cut = part(name, (200, 200, thickness))
        edge = cut("y", 100)
        left = name != "top_right"
        points = [p for loop in edge for p in loop if (p[0] < 2.99 if left else p[0] > 197.01) and p[1] > thickness - 2.99]
        assert len(points) >= 10, "exposed edge R3 missing"
        assert all(abs(math.dist(p, (3 if left else 197, thickness - 3)) - 3) < 0.03 for p in points)
        for x in [10, 190]:
            for y in [10, 190]:
                m4_seat(cut, x, y, thickness)
        if name == "bottom":
            for y in [16, 107]:
                loop_at(cut("z", 4.5), (16.5, 183.5, y, y + 77))
                empty_rect(cut("z", 4.5), (16.5, 183.5, y, y + 77))
                assert inside(cut("z", 3.99), (100, y + 30))
        else:
            # 座標は造形後の輪郭から測る。ピッチ、向き、縁の非干渉を別々に検証する。
            loops = cut("z", 0.1)
            buttons = []
            for loop in loops:
                x0, x1, y0, y1 = bounds(loop)
                if 24 < x1 - x0 < 31:
                    near((x1 - x0,), (y1 - y0,))
                    buttons.append(((x0 + x1) / 2, (y0 + y1) / 2, x1 - x0))
            buttons.sort(key=lambda b: (-b[1], b[0]))
            assert len(buttons) == (7 if name == "top_left" else 12), "expected two auxiliary buttons on each panel"
            measured_buttons[name] = buttons
            for x, y, diameter in buttons:
                near((diameter,), (30.4 if diameter > 28 else 24.4,))
                loop_at(cut("z", 5.9), (x - diameter / 2, x + diameter / 2, y - diameter / 2, y + diameter / 2))
            def at(x, y):
                result = min(buttons, key=lambda b: math.dist(b[:2], (x, y)))
                assert math.dist(result[:2], (x, y)) < 0.03, ("missing button", (x, y), result)
                return result

            def pitch(a, b, length=27):
                near((math.dist(a[:2], b[:2]),), (length,))

            def angle(a, b, degrees):
                near((math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])),), (degrees,))

            auxiliary = [at(x, 160.5) for x in ([146.5, 175.5] if name == "top_left" else [24.5, 53.5])]
            measured_auxiliary[name] = auxiliary
            pitch(*auxiliary, 29)
            near((180 - auxiliary[0][1] - 14.5,), (5,))
            near((200 - auxiliary[1][0] - 14.5 if name == "top_left" else auxiliary[0][0] - 14.5,), (10,))

            def rim(b):
                return 33 if b[2] > 28 else (29 if b in auxiliary else 27)

            for i, a in enumerate(buttons):
                for b in buttons[i + 1:]:
                    assert math.dist(a[:2], b[:2]) >= (rim(a) + rim(b)) / 2 - 0.01, "button bodies overlap"

            if name == "top_right":
                # 全体20度を解除した元配列から、右を中央へ10mm移す。
                wp, mp, hp = at(53.189, 129.852), at(87.174, 144.336), at(120.124, 145)
                wk, mk, hk = at(68.269, 107.455), at(93.124, 118), at(120.124, 118)
                big, lower = at(146.915, 131.5), at(141.825, 101.935)
                # 旧X=61.2805/54.2924から-4/+3mm。27mm間隔のまま奥へ詰める。
                jump, parry = at(57.2805, 82.792), at(57.2924, 55.792)
                angle(mk, hk, 0); angle(hk, hp, 90)
                # 弱P/中Pは各Kから半径27の円弧上を16/6mm、反時計回り。
                for kick, punch, arc_length in [(wk, wp, 16), (mk, mp, 6)]:
                    rotation = math.atan2(punch[1] - kick[1], punch[0] - kick[0]) - math.pi / 2
                    near((27 * rotation,), (arc_length,))
                for a, b in [(wk, mk), (mk, hk), (wp, wk), (mp, mk), (hp, hk), (hk, lower), (wk, jump), (jump, parry)]:
                    pitch(a, b)
                for b in [hp, hk, lower]: pitch(big, b, 30)
                assert jump[0] < wk[0] and 55.295 < parry[1] < jump[1] < wk[1]
                assert jump[1] > 81.375, "jump button did not move upward"
                # 主指3穴・親指2穴・補助2穴を全て鏡像にする。
                for b in [hp, mp, wp, jump, parry, *auxiliary]:
                    expected = (200 - b[0], b[1], b[2])
                    actual = min(measured_buttons["top_left"], key=lambda p: math.dist(p[:2], expected[:2]))
                    near(actual, expected)
                # 部品面は内側、長辺は横向きのまま右天板へ移設する。
                for x, y in [(76.922, 26.852), (165.322, 26.952), (77.022, 64.452), (165.322, 64.252)]:
                    for z, radius in [(0.1, 1.7), (4.3, 1.7), (5, 2.4), (5.6, 3), (5.81, 3.2), (5.9, 3.2)]:
                        round_at(cut("z", z), x, y, radius)
                # 公開基板外形の保守的な外接矩形と、幅10×長さ25mmのUSB挿入予約枠。
                # ケーブル外装の実寸は未取得。予約枠が実ケーブルを保証するわけではない。
                for rect, clearance in [(pcb_rect, 3), (usb_rect, 0)]:
                    for b in buttons:
                        x, y = b[:2]
                        nearest = (min(max(x, rect[0]), rect[1]), min(max(y, rect[2]), rect[3]))
                        gap = math.dist((x, y), nearest) - rim(b) / 2
                        if rect == pcb_rect and b == parry:
                            near((gap,), (2.198,))
                            assert gap >= 2, "parry button is too close to the PCB"
                        else:
                            assert gap >= clearance, "PCB or USB reservation overlaps a button"
            # 基板穴4個は右だけ。左の旧穴や、掌の凹み等の余分な輪郭を検出する。
            assert len(loops) == len(buttons) + (5 if name == "top_left" else 9)
            assert len(cut("z", 5.9)) == len(loops)
            for x, y in [(100, 30), (150, 30), (170, 60)]:
                assert inside(cut("z", 5.99), (x, y)), "palm recess remains"

    # 指定した基板穴は金属スペーサーをネジで留めるための通し穴。
    cut = part("top_left", (200, 200, 6), ('pcb_mounts_left=[[60,80],[80,80]]',))
    for x in [60, 80]:
        loop_at(cut("z", 0.1), (x - 1.7, x + 1.7, 78.3, 81.7))
        assert not inside(cut("z", 5.9), (x, 80))

    # 中央は前後の柱だけで接続し、配線用の内部空間に仕切りがない。
    render(SOURCE, work / "assembly.stl", ('part="assembly"',), binary=True)
    assembled = closed_mesh(work / "assembly.stl")
    near(bounds(assembled), (0, 400, 0, 200, 0, 61))
    expected_volume = sum(volumes[name] * count for name, count in {
        "top_left": 1, "top_right": 1, "bottom": 2, "corner_post": 2, "corner_post_right": 2,
        "center_post": 2, "wall": 6}.items())
    assert abs(volume(assembled) - expected_volume) < expected_volume * 0.00002, "assembled parts intersect"
    loops = section(work / "assembly.stl", work, "z", 30)
    empty_rect(loops, (25, 375, 25, 175))
    for name, buttons in measured_buttons.items():
        offset = 200 if name == "top_right" else 0
        for b in buttons:
            x, y, d = b
            radius = 16.5 if d > 28 else (14.5 if b in measured_auxiliary[name] else 13.5)
            empty_rect(loops, (offset + x - radius, offset + x + radius, y - radius, y + radius))
    # 右天板下の基板外形とUSBプラグ予約枠も、既存の柱/壁を避ける。
    for x0, x1, y0, y1 in [pcb_rect, usb_rect]:
        empty_rect(loops, (200 + x0, 200 + x1, y0, y1))
    assert inside(loops, (200, 10)) and inside(loops, (200, 190))
    print("leverless: round M4 4.4/8.4mm countersinks with 0.2mm seats, nut plug fit, full-height M4 bores, inner R3, planar nut entries and bridges, button clearance, M3 countersinks, closed meshes and assembly fit passed")
