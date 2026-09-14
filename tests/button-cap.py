#!/usr/bin/env python3
"""薄型キャップのproduction STLで寸法・右ねじ・締結経路を測る。"""

from pathlib import Path
import math
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, near, render, section

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/leverless/button_cap.scad"

with tempfile.TemporaryDirectory(prefix="button-cap-test-") as temp:
    work = Path(temp)
    assert SOURCE.is_file(), "button_cap.scad is missing"
    for name in ["body", "nut"]:
        target = work / f"{name}.stl"
        render(SOURCE, target, (f'part="{name}"',), binary=True)

    body, nut = work / "body.stl", work / "nut.stl"
    near(bounds(closed_mesh(body)), (-13, 13, -13, 13, 0, 12))
    # 印刷下面はφ24.4、0.8mmかけてφ26へ広がり、残り0.4mmが直壁。
    for z, radius in [(0.1, 12.3), (0.7, 12.9), (0.9, 13), (1.19, 13), (1.21, 12), (2.99, 12)]:
        loops = section(body, work, "z", z)
        assert len(loops) == 1 and inside(loops, (0, 0)), "cap face must be solid"
        assert all(abs(math.hypot(x, y) - radius) < 0.02 for x, y in loops[0])
    # 底Z=0..3を残し、ねじ先端まで同軸φ11.9の空洞を開く。
    for z in [3.01, 3.99, 6, 11.99]:
        loops = section(body, work, "z", z)
        assert len(loops) == 2 and not inside(loops, (0, 0)), "cap cavity is missing or blocked"
        inner = min(loops, key=lambda loop: max(math.hypot(x, y) for x, y in loop))
        assert all(abs(math.hypot(x, y) - 5.95) < 0.02 for x, y in inner), "cap cavity diameter is wrong"
        outer = max(loops, key=lambda loop: max(math.hypot(x, y) for x, y in loop))
        assert min(math.hypot(x, y) for x, y in outer) - 5.95 >= 2.98, "cap wall is thinner than 3mm"
    # 先端はC0.8。筒部分φ24はφ24.4の穴に片側0.2mmの余裕で入る。
    assert max(math.hypot(x, y) for loop in section(body, work, "z", 11.9) for x, y in loop) < 9.08

    # 0.6mm進むと山が反時計回りに90度進む: 1条右ねじ、ピッチ2.4。
    # crest/valleyを複数半径で測り、ねじを消しても通る検査にしない。
    for dz in [1.2, 1.8, 2.4, 3.0, 3.6]:
        angle = math.radians(dz * 360 / 2.4)
        loops = section(body, work, "z", 4 + dz)
        outer = max(loops, key=lambda loop: max(math.hypot(x, y) for x, y in loop))
        radii = [math.hypot(x, y) for x, y in outer]
        near((min(radii), max(radii)), (8.95, 9.75))
        assert inside(loops, (9.7 * math.cos(angle), 9.7 * math.sin(angle))), "thread lead/hand is wrong"
        assert not inside(loops, (-9.1 * math.cos(angle), -9.1 * math.sin(angle))), "thread valley is missing"

    near(bounds(closed_mesh(nut)), (-13, 13, -13, 13, 0, 8))
    # 板側4mmは一周つながったリング。その先の4mmにOSB式の6つの切り欠き。
    for z in [0.01, 2, 3.99]:
        loops = section(nut, work, "z", z)
        assert len(loops) == 2 and not inside(loops, (0, 0)), "nut bearing ring is interrupted"
        for a in range(0, 360, 5):
            assert inside(loops, (12 * math.cos(math.radians(a)), 12 * math.sin(math.radians(a))))
    for z in [4.01, 6, 7.5, 7.99]:
        loops = section(nut, work, "z", z)
        assert len(loops) == 6, "nut needs six separate finger grips above the bearing ring"
        for a in range(30, 360, 60):
            # 各スリットを+Y方向へ回し、幅4.8mmが内穴から外側へ貫通することを測る。
            c, s = math.cos(math.radians(90 - a)), math.sin(math.radians(90 - a))
            rotated = [[(x * c - y * s, x * s + y * c) for x, y in loop] for loop in loops]
            empty_rect(rotated, (-2.4, 2.4, 8.5, 14))
            assert inside(rotated, (-2.43, 11)) and inside(rotated, (2.43, 11)), "grip slot is too wide"
    loops = section(nut, work, "z", 2)
    assert len(loops) == 2 and not inside(loops, (0, 0)), "nut must have a through bore"
    inner = min(loops, key=lambda loop: max(math.hypot(x, y) for x, y in loop))
    radii = [math.hypot(x, y) for x, y in inner]
    near((min(radii), max(radii)), (9.2, 10))
    assert 13 - max(radii) >= 2.99, "nut wall is thinner than 3mm"
    # 層高0.2mmでの輪郭の張り出しを軸断面から実測する。
    # twistの三角形分割による0.02mm以下の凹凸は、1層の幅で評価する。
    for stl, base, layers in [(body, 4, 38), (nut, 0, 38)]:
        loops = section(stl, work, "y", 0)

        def radius_at(z):
            crossings = []
            for loop in loops:
                for (x0, z0), (x1, z1) in zip(loop, loop[1:] + loop[:1]):
                    if min(z0, z1) < z < max(z0, z1):
                        x = x0 + (x1 - x0) * (z - z0) / (z1 - z0)
                        if 8.9 < x < 10.01:
                            crossings.append(x)
            assert len(crossings) == 1
            return crossings[0]

        radii = [radius_at(base + 0.013 + i * 0.2) for i in range(layers)]
        changes = [abs(b - a) for a, b in zip(radii, radii[1:])]
        assert max(changes) <= 0.215, "thread overhang exceeds 45 degrees at 0.2mm layers"
        assert sum(d > 0.18 for d in changes) >= 4, "45-degree thread flanks missing"

    # 実STLの体積交差を調べる。空のintersectionを既知の小立方体で観測する。
    # 板厚3/6mmの着座から、先端へ抜くまで右ねじ方向に回せること。
    # bodyのねじ起点z=4、nut起点z=0なので回転角は絶対高さ差から求める。
    def collision(extra):
        source, target = work / "collision.scad", work / "collision.stl"
        source.write_text(f'translate([40, 0, 0]) cube(1);\n{extra}\n')
        render(source, target, binary=True)
        near(bounds(closed_mesh(target)), (40, 41, 0, 1, 0, 1))

    for z in [4.2, 4.8, 5.4, 6.0, 6.6, 7.2, 8.4, 9.6, 10.8]:
        placed_nut = f'translate([0,0,{z}]) rotate([0,0,{(z - 4) * 360 / 2.4}]) import("{nut}");'
        collision(f'intersection() {{ import("{body}"); {placed_nut} }}')

    for thickness in [3, 6]:
        z = 1.2 + thickness
        placed_nut = f'translate([0,0,{z}]) rotate([0,0,{(z - 4) * 360 / 2.4}]) import("{nut}");'
        # STLのfloat丸めを避け、板の内部を上下各0.005mmだけ縮めて検査する。
        plate = f'translate([0,0,1.205]) difference() {{ cylinder(d=40,h={thickness - 0.01},$fn=96); translate([0,0,-0.1]) cylinder(d=24.4,h={thickness + 0.2},$fn=96); }}'
        collision(f'intersection() {{ {plate} union() {{ import("{body}"); {placed_nut} }} }}')
        # 位相を保って軸方向へ0.6mmだけ抜くと山が掛かる: 空回りの輪を弾く。
        source, target = work / "retention.scad", work / "retention.stl"
        source.write_text(f'intersection() {{ import("{body}"); translate([0,0,0.6]) {{ {placed_nut} }} }}')
        render(source, target, binary=True)
        assert target.stat().st_size > 84, "threads cannot retain the cap"

    # 補助ボタン中心間29mm・隣接外装φ29に対し、キャップ/ナットφ26は1.5mm空く。
    collision(f'intersection() {{ union() {{ import("{body}"); import("{nut}"); }} translate([29,0,0]) cylinder(d=29,h=12,$fn=96); }}')
    print("button-cap: closed parts, 3mm cap floor/wall, six 4.8x4mm OSB grip slots, 26x8mm nut, right-hand pitch 2.4, 45-degree flanks, 3/6mm plate fit and screw travel passed")
