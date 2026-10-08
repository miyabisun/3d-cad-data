#!/usr/bin/env python3
"""30Lゴミ袋用ゴミ箱: 内寸X220×Y240、床4mmの2段・4.2mmへ張り出すスナップ継手・ポケット・蓋をproduction STLで実測する。"""

import math
from pathlib import Path
import subprocess
import tempfile

from stl_geometry import bounds, closed_mesh, empty_rect, inside, loop_at, near, read_vertices, render_many, section

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "assets/trash-can"


def at(x, r, angle):
    """各壁の中央を x=0 とし、内面から外向きに r の点を angle 度回した壁へ置く。
    0/180 度は Y=∓120 の短辺 (長さ220)、90/270 度は X=±110 の長辺 (長さ240、ポケット側)。"""
    c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    y = -((120 if angle % 180 == 0 else 110) + r)
    return (x * c - y * s, x * s + y * c)


def material(plan, x, r, expected, angles=(0, 90, 180, 270)):
    for angle in angles:
        assert inside(plan, at(x, r, angle)) == expected, (x, r, angle, expected)


def check_walls(stl, work, z, inner):
    plan = section(stl, work, "z", z)
    loop_at(plan, (-113, 113, -123, 123))
    if inner:
        loop_at(plan, inner)
    else:  # 底段: ポケットの両脇に角の隙間が残り、内側の輪郭はポケットの前板の手前まで来ない
        assert len(plan) == 4, [bounds(p) for p in plan]
        loop_at(plan, (-110, -104, -110, 110))
        loop_at(plan, (104, 110, -110, 110))
    # 内面R10・外面R13。角の中心は (±100, ±110)。
    for sx in (-1, 1):
        for sy in (-1, 1):
            for d, solid in [(9.9, False), (10.1, True), (12.9, True), (13.1, False)]:
                p = (sx * (100 + d / math.sqrt(2)), sy * (110 + d / math.sqrt(2)))
                assert inside(plan, p) == solid, (z, p, solid)


def outer_slope(plan_at, angles=(0, 90, 180, 270)):
    """接合部の外面: 4.2mmから壁3mmへ30度で戻る。plan_at(t) は張り出しの端から t 離れた断面。"""
    for t, r in [(1.04, 4.2 - 1.04 * math.tan(math.radians(30))), (2.2, 3)]:
        plan = plan_at(t)
        material(plan, 50, r - 0.05, True, angles)
        material(plan, 50, r + 0.05, False, angles)


def check_tongue(stl, work, joint, angles=(0, 90, 180, 270)):
    """下段の上端: 外面を4.2mmへ張り出し、接合面 joint から内側2.05mmの舌が12mm立ち、各壁中央に爪がある。"""
    plan = section(stl, work, "z", joint - 0.1)
    material(plan, 50, 0.1, True, angles)
    material(plan, 50, 4.1, True, angles)
    material(plan, 50, 4.3, False, angles)
    outer_slope(lambda t: section(stl, work, "z", joint - t), angles)
    for z in [joint + 0.5, joint + 11.9]:
        plan = section(stl, work, "z", z)
        material(plan, 50, 0.1, True, angles)
        material(plan, 50, 2.0, True, angles)
        material(plan, 50, 2.1, False, angles)
    # 爪: 幅20。接合面+4から45度で外へ1.2mm張り出し、上へ6mmで舌へ戻る。下面は空中へ水平に出ない。
    material(section(stl, work, "z", joint + 3.9), 0, 2.1, False, angles)
    for z in [joint + 4.6, joint + 8.2]:
        plan = section(stl, work, "z", z)
        material(plan, 0, 2.6, True, angles)
        material(plan, 0, 2.7, False, angles)
    plan = section(stl, work, "z", joint + 5.3)
    material(plan, 0, 3.15, True, angles)
    material(plan, 9.9, 3.15, True, angles)
    material(plan, 10.1, 3.15, False, angles)
    material(plan, 0, 3.35, False, angles)


def check_skirt(stl, work, height):
    """上段の下端: 外側2.05mmのスカートが舌を0.1mm離して受け、窓が爪を通し、外面は30度で壁へ戻る。"""
    def plan(z):  # 使用時の高さ z。上段は上下逆に印刷する。
        return section(stl, work, "z", height - z)
    for z in [0.5, 3.5, 11]:
        p = plan(z)
        material(p, 50, 2.2, True)
        material(p, 50, 4.1, True)
        material(p, 50, 4.3, False)
        material(p, 50, 2.1, False)
        material(p, 50, 0.1, False)
    # 窓は爪の斜面と0.4mm離れた高さから、爪の上端の0.4mm上まで。上下逆の印刷でブリッジがたるんでも爪がはまる。
    for z in [3.75, 11.5]:
        p = plan(z)
        material(p, 0, 3.2, False)
        material(p, 10.4, 3.2, False)
        material(p, 10.6, 3.2, True)
    for z in [3.65, 11.7]:
        material(plan(z), 0, 3.2, True)
    # 舌の上端12mmの上に0.1mmの隙間。その上は肩なしで全厚。
    material(plan(12.05), 50, 1, False)
    material(plan(12.15), 50, 0.1, True)
    outer_slope(lambda t: plan(12.1 + t))


def facets(stl):
    """(三角形, 法線の長さ0以上のベクトル) を float32 の STL 座標のまま返す。"""
    vertices = read_vertices(stl)
    for i in range(0, len(vertices), 3):
        p, q, r = vertices[i:i + 3]
        u, v = [b - a for a, b in zip(p, q)], [b - a for a, b in zip(p, r)]
        yield (p, q, r), (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])


def overhangs(stl):
    """印刷の向きで下を向き、鉛直から45度より寝た面の高さ。ベッド (z=0) は除く。"""
    levels = set()
    for (p, q, r), n in facets(stl):
        length = math.hypot(*n)
        if length > 1e-6 and n[2] / length < -0.75 and max(p[2], q[2], r[2]) > 0.01:
            levels.add(round(max(p[2], q[2], r[2]), 1))
    return levels


with tempfile.TemporaryDirectory(prefix="trash-can-test-") as temp:
    work = Path(temp)
    parts = ["bottom_ring", "top_ring", "lid"]
    for name in parts:
        assert (DIR / f"{name}.scad").is_file(), f"{name}.scad is missing"
    jobs = [(DIR / f"{name}.scad", work / f"{name}.stl", ()) for name in parts]
    # 組み立てた状態の上下段の重なり。空なら離れた1mm立方体だけが残る。接触面の0.01mm上へ浮かせる。
    clash = work / "clash.scad"
    clash.write_text(f'include <{ROOT / "modules/trash_can.scad"}>\ntranslate([300, 0, 0]) cube(1);\n'
                     "intersection() { bottom_ring(); translate([0, 0, height + 0.01]) mirror([0, 0, 1]) top_ring(); }\n")
    jobs += [(clash, work / "clash.stl", ()),
             (DIR / "trash_can.scad", work / "assembly.stl", ()),
             (DIR / "top_ring.scad", work / "short_top.stl", ("inner_height=400",))]
    render_many(jobs)
    stl = {name: work / f"{name}.stl" for name in parts}

    # 内高さ480、床4を足して484。底段250 (接合面238)、上段246で、ともにP1Sの256以下。
    # 長辺はY。蓋のX幅233がP1Sのベッド左手前の禁止域 (X 0〜18、Y 0〜28) を避けて置ける。
    assert not (DIR / "middle_ring.scad").exists(), "two rings only"
    near(bounds(closed_mesh(stl["bottom_ring"])), (-114.2, 114.2, -124.2, 124.2, 0, 250))
    near(bounds(closed_mesh(stl["top_ring"])), (-114.2, 114.2, -124.2, 124.2, 0, 246))
    near(bounds(closed_mesh(stl["lid"])), (-116.5, 116.5, -126.5, 126.5, 0, 78))
    near(bounds(closed_mesh(work / "short_top.stl"))[4:], (0, 166))
    near(bounds(read_vertices(work / "assembly.stl"))[4:], (0, 487))

    near(bounds(read_vertices(work / "clash.stl")), (300, 301, 0, 1, 0, 1))
    # OrcaServer は float32 で面積0の三角形を含むモデルを不正として取り込まない。
    for name in parts:
        flat = [t for t, n in facets(stl[name]) if n == (0, 0, 0)]
        assert not flat, (name, len(flat), flat[:2])
    # 空中へ出る面は無い。上段の窓の爪側の辺 (使用時の接合面+3.7) だけが幅21mmのブリッジ。
    assert overhangs(stl["bottom_ring"]) == set(), overhangs(stl["bottom_ring"])
    assert overhangs(stl["top_ring"]) == {242.3}, overhangs(stl["top_ring"])
    assert overhangs(stl["lid"]) == set(), overhangs(stl["lid"])

    check_walls(stl["top_ring"], work, 100, (-110, 110, -120, 120))
    check_skirt(stl["top_ring"], work, 246)
    check_walls(stl["bottom_ring"], work, 100, None)
    check_tongue(stl["bottom_ring"], work, 238)
    # 上段は上端を下に印刷する。ベッド側は全厚の壁。
    plan = section(stl["top_ring"], work, "z", 0.1)
    material(plan, 50, 0.1, True)
    material(plan, 50, 3.1, False)

    # 床: 厚4mmの一枚板が外周まで塞ぎ、その上は空く。
    bottom = stl["bottom_ring"]
    for z in [0.1, 3.9]:
        plan = section(bottom, work, "z", z)
        assert len(plan) == 1, [bounds(p) for p in plan]
        loop_at(plan, (-113, 113, -123, 123))
    assert not inside(section(bottom, work, "z", 4.1), (0, 0)), "floor thicker than 4 mm"

    # ポケット: 長辺 (X=±110) の内面に幅220・厚6・高さ240の空間、床の上から。前板3mm、上からU字。
    for angle in [90, 270]:
        for z in [4.1, 100, 243.9]:
            plan = section(bottom, work, "z", z)
            side = 1 if angle == 90 else -1
            empty_rect(plan, (*sorted((side * 110, side * 104)), -110, 110))
            material(plan, 111.5, -3, True, [angle])
            material(plan, -111.5, -3, True, [angle])
            material(plan, 0, -9.5, False, [angle])
        material(section(bottom, work, "z", 143), 0, -7.5, True, [angle])
        material(section(bottom, work, "z", 145), 0, -7.5, False, [angle])
        plan = section(bottom, work, "z", 214)
        material(plan, 69, -7.5, False, [angle])
        material(plan, 71, -7.5, True, [angle])
        material(section(bottom, work, "z", 160), 60, -7.5, True, [angle])
        material(section(bottom, work, "z", 243.9), 100, -7.5, True, [angle])
        plan = section(bottom, work, "z", 244.1)
        material(plan, 100, -7.5, False, [angle])
        material(plan, 0, -3, False, [angle])
    # 袋のパックを差す空間に膜がなく、上は接合部の舌の上端まで開いている。
    for x in [-107, 107]:
        profile = section(bottom, work, "x", x)
        empty_rect(profile, (-110, 110, 4, 250))
        assert inside(profile, (0, 2)), "pocket floor missing"

    # 蓋: 印刷向きで天板が下。中央に内壁から20mm内側の180×200・R20の穴、縁3mm内側を75mm覆う。
    lid = stl["lid"]
    plan = section(lid, work, "z", 1.5)
    loop_at(plan, (-116.5, 116.5, -126.5, 126.5))
    hole = loop_at(plan, (-90, 90, -100, 100))
    assert not inside([hole], (89.5, 99.5)), "hole corner radius missing"
    plan = section(lid, work, "z", 40)
    loop_at(plan, (-116.5, 116.5, -126.5, 126.5))
    loop_at(plan, (-113.5, 113.5, -123.5, 123.5))
    for d, solid in [(13.4, False), (13.6, True), (16.4, True), (16.6, False)]:
        assert inside(plan, (-100 - d / math.sqrt(2), -110 - d / math.sqrt(2))) == solid, (d, solid)

    for define in ["bottom_ring_height=257", "pocket_height=247", "pocket_width=221", "inner_height=500", "bag_length=550", "pocket_u_depth=69",
                   "joint_wall=2.9", "snap_depth=2.2", "snap_catch=60",
                   "inner=[240, 240]"]:
        result = subprocess.run(["openscad", "-o", str(work / "invalid.stl"), "-D", define, str(DIR / "bottom_ring.scad")],
                                capture_output=True, text=True)
        assert "ERROR: Assertion" in result.stderr, (define, result.stderr)

print("Trash can: 220 x 240 x 480 mm inside, 4 mm floor, two rings, 4.2 mm snap lap joints, 240 mm pockets with U cut and lid OK")
