#!/usr/bin/env python3
"""stl_geometry の断面を、既知の立体の STL を直接書いて確かめる (OpenSCAD を使わない)。"""

from pathlib import Path
import struct
import subprocess
import sys
import tempfile

from stl_geometry import bounds, closed_mesh, inside, section


def area(loop):
    return abs(sum(x * by - bx * y for (x, y), (bx, by) in zip(loop, loop[1:] + loop[:1]))) / 2


def box(x0, x1, y0, y1, z0, z1, flip=False):
    # 外向き法線の12三角形。flip で内向き (穴の壁) にする。
    v = [(x, y, z) for z in (z0, z1) for y in (y0, y1) for x in (x0, x1)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    tris = [t for a, b, c, d in faces for t in ((v[a], v[b], v[c]), (v[a], v[c], v[d]))]
    return [t[::-1] for t in tris] if flip else tris


def write_stl(path, tris, ascii=False):
    if ascii:
        body = "".join("facet normal 0 0 0\nouter loop\n" + "".join(f"vertex {x} {y} {z}\n" for x, y, z in t)
                       + "endloop\nendfacet\n" for t in tris)
        path.write_text(f"solid t\n{body}endsolid t\n")
    else:
        path.write_bytes(b"\0" * 80 + struct.pack("<I", len(tris))
                         + b"".join(struct.pack("<12fH", 0, 0, 0, *[c for p in t for c in p], 0) for t in tris))


with tempfile.TemporaryDirectory(prefix="stl-geometry-") as temp:
    work = Path(temp)
    # 20×10×6 の直方体に、上下へ貫通する 4×4 の角穴 (中心 x=5)。角穴は内向きの箱で
    # 表す。上下面が重なる非多様体だが、輪郭は偶奇規則で数えるので穴の中は外になる。
    solid = work / "solid.stl"
    write_stl(solid, box(0, 20, 0, 10, 0, 6) + box(3, 7, 3, 7, 0, 6, flip=True))

    plan = section(solid, work, "z", 2.5)
    assert len(plan) == 2, plan
    outer, hole = sorted(plan, key=area, reverse=True)
    assert bounds(outer) == (0, 20, 0, 10) and bounds(hole) == (3, 7, 3, 7), plan
    # 三角形の対角線で割れた辺の途中の点は落とし、角の4点だけにする。
    assert len(outer) == 4 and len(hole) == 4, plan
    assert inside(plan, (1, 1)) and not inside(plan, (5, 5)) and not inside(plan, (21, 5))

    # y 断面は (x, z) の座標で返す。
    side = section(solid, work, "y", 5)
    assert sorted(bounds(l) for l in side) == [(0, 20, 0, 6), (3, 7, 0, 6)], side
    assert not inside(side, (5, 3)) and inside(side, (10, 3))

    # 頂点を通る平面 (x=3 の穴壁上の y=3 など) でも閉じた輪郭になる。
    edge = section(solid, work, "y", 3)
    assert all(len(l) >= 3 for l in edge) and sum(area(l) for l in edge) > 0, edge

    # ASCII STL も同じ結果。
    ascii_stl = work / "ascii.stl"
    write_stl(ascii_stl, box(0, 20, 0, 10, 0, 6) + box(3, 7, 3, 7, 0, 6, flip=True), ascii=True)
    assert sorted(map(bounds, section(ascii_stl, work, "z", 2.5))) == sorted(map(bounds, plan))

    # Manifold の和が float32 化で潰した面積0の三角形 (一直線・頂点の重複) は無視して、
    # 閉じ具合を検査する。面を1枚欠いたメッシュは引き続き閉じていないと判定する。
    sliver = work / "sliver.stl"
    write_stl(sliver, box(0, 20, 0, 10, 0, 6) + [((0, 0, 0), (10, 0, 0), (20, 0, 0)), ((0, 0, 6), (0, 0, 6), (20, 10, 6))])
    assert bounds(closed_mesh(sliver)) == (0, 20, 0, 10, 0, 6)
    holed = work / "holed.stl"
    write_stl(holed, box(0, 20, 0, 10, 0, 6)[1:])
    try:
        closed_mesh(holed)
    except AssertionError as e:
        assert str(e) == "STL is not closed", e
    else:
        raise AssertionError("open mesh passed closed_mesh")

    # シェルのテスト向け CLI は OpenSCAD の SVG と同じ向き (plan は y 反転、y 断面は z がそのまま) で書く。
    svg = work / "plan.svg"
    subprocess.run([sys.executable, Path(__file__).with_name("stl_geometry.py"), "svg", solid, "z", "2.5", svg], check=True)
    text = svg.read_text()
    assert 'd="M' in text and "0.000000,-10.000000" in text, text
    subprocess.run([sys.executable, Path(__file__).with_name("stl_geometry.py"), "svg", solid, "y", "5", svg], check=True)
    assert "20.000000,6.000000" in svg.read_text()

print("stl-geometry: python plane sections (holes, y cuts, vertex planes, ascii, slivers, svg cli) passed")
