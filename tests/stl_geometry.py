"""OpenSCADのproduction STLを描画し、閉曲面と平面断面を測る共通処理。"""

import bisect
import collections
from concurrent.futures import ThreadPoolExecutor
import functools
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys


def render(source, output, defines=(), binary=False):
    result = subprocess.run(["openscad", "-o", str(output), *(["--export-format", "binstl"] if binary else []), *[v for d in defines for v in ("-D", d)], str(source)], capture_output=True, text=True)
    assert result.returncode == 0 and not re.search(r"ERROR|WARNING", result.stderr), result.stderr
    assert output.stat().st_size > 0


def render_many(jobs):
    """(source, output, defines) の独立した render を CPU 数だけ並列に回す。"""
    with ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
        list(pool.map(lambda job: render(*job, binary=True), jobs))


def bounds(points):
    return tuple(v for axis in zip(*points) for v in (min(axis), max(axis)))


def near(actual, expected):
    assert len(actual) == len(expected) and all(abs(a - b) < 0.03 for a, b in zip(actual, expected)), (actual, expected)


def inside(loops, point):
    x, y = point
    hits = 0
    for loop in loops:
        for (ax, ay), (bx, by) in zip(loop, loop[1:] + loop[:1]):
            if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
                hits += 1
    return hits % 2 == 1


def empty_rect(loops, rect):
    # Liang–Barsky: 薄膜も検出できるよう、矩形内部を横切る境界を拒否する。
    x0, x1, y0, y1 = rect
    eps = 0.005
    x0, x1, y0, y1 = x0 + eps, x1 - eps, y0 + eps, y1 - eps
    assert not inside(loops, ((x0 + x1) / 2, (y0 + y1) / 2))
    for loop in loops:
        for (ax, ay), (bx, by) in zip(loop, loop[1:] + loop[:1]):
            lo, hi = 0, 1
            for p, q in [(-(bx - ax), ax - x0), (bx - ax, x1 - ax), (-(by - ay), ay - y0), (by - ay, y1 - ay)]:
                if p == 0:
                    if q < 0:
                        hi = -1
                        break
                elif p < 0:
                    lo = max(lo, q / p)
                else:
                    hi = min(hi, q / p)
            assert lo > hi, ("material boundary in clearance", rect, (ax, ay), (bx, by))


def loop_at(loops, expected):
    matches = [p for p in loops if all(abs(a - b) < 0.03 for a, b in zip(bounds(p), expected))]
    assert len(matches) == 1, ("missing contour", expected, [bounds(p) for p in loops])
    return matches[0]

def read_vertices(stl):
    data = Path(stl).read_bytes()
    if len(data) >= 84 and len(data) == 84 + struct.unpack_from("<I", data, 80)[0] * 50:
        vertices = [tuple(facet[i:i + 3]) for facet in struct.iter_unpack("<12fH", data[84:]) for i in (3, 6, 9)]
    else:
        vertices = [tuple(map(float, m)) for m in re.findall(r"vertex\s+(\S+)\s+(\S+)\s+(\S+)", data.decode())]
    assert vertices, "empty STL"
    return vertices


def closed_mesh(stl):
    vertices = read_vertices(stl)
    edges = collections.Counter()
    graph = collections.defaultdict(set)
    for i in range(0, len(vertices), 3):
        triangle = vertices[i:i + 3]
        p, q, r = triangle
        u, v = [b - a for a, b in zip(p, q)], [b - a for a, b in zip(p, r)]
        assert any(abs(c) > 1e-12 for c in (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])), "degenerate STL triangle"
        for a, b in zip(triangle, triangle[1:] + triangle[:1]):
            assert a != b
            edges[tuple(sorted((a, b)))] += 1
            graph[a].add(b)
            graph[b].add(a)
    assert all(count == 2 for count in edges.values()), "STL is not closed"
    seen, pending = set(), [next(iter(graph))]
    while pending:
        point = pending.pop()
        if point not in seen:
            seen.add(point)
            pending.extend(graph[point] - seen)
    assert len(seen) == len(graph), "disconnected STL"

    return vertices


@functools.lru_cache(maxsize=8)
def _triangles(path, stamp, k):
    # 軸 k の最小座標で並べ、平面より下に頂点を持つ三角形を bisect で切り出す
    v = read_vertices(path)
    tris = sorted((v[i:i + 3] for i in range(0, len(v), 3)), key=lambda t: min(p[k] for p in t))
    return tris, [min(p[k] for p in t) for t in tris]


def _crossing(a, b, da, db):
    # 共有辺は両側の三角形で同じ点になるよう、端点の順を揃えてから内挿する
    if a > b:
        a, b, da, db = b, a, db, da
    if da == 0:
        return a
    if db == 0:
        return b
    t = da / (da - db)
    return tuple(p + t * (q - p) for p, q in zip(a, b))


def _simplify(loop):
    # 重複点と、同一直線上の途中の点 (三角形の対角線で割れた辺) を落とす
    i = 0
    while i < len(loop) and len(loop) > 2:
        (ax, ay), (bx, by), (cx, cy) = loop[i - 1], loop[i], loop[(i + 1) % len(loop)]
        u, v = (bx - ax, by - ay), (cx - bx, cy - by)
        if abs(u[0] * v[1] - u[1] * v[0]) <= 1e-9 * math.hypot(*u) * math.hypot(*v):
            del loop[i]
            i = max(i - 1, 0)
        else:
            i += 1
    return loop


def section(stl, work, axis, position):
    """STL を平面 axis=position で切った輪郭。z 断面は (x, y)、y 断面は (x, z) の点列を返す。

    平面上の頂点は上側として扱うので、平面に載った面でも輪郭は閉じる。輪郭は偶奇規則で
    数える前提で、OpenSCAD の projection(cut = true) と同じ形を返す。work は互換のため受け取る。
    """
    k, u = {"z": (2, 1), "y": (1, 2)}[axis]
    stat = Path(stl).stat()
    tris, lows = _triangles(str(stl), (stat.st_mtime_ns, stat.st_size, stat.st_ino), k)
    segments = []
    for tri in tris[:bisect.bisect_left(lows, position)]:
        d = [p[k] - position for p in tri]
        up = [x >= 0 for x in d]
        if not any(up):
            continue
        ends = [_crossing(tri[i], tri[i - 2], d[i], d[i - 2]) for i in range(3) if up[i] != up[i - 2]]
        ends = [(p[0], p[u]) for p in ends]
        if ends[0] != ends[1]:
            segments.append(ends)
    graph = collections.defaultdict(list)
    for n, (p, q) in enumerate(segments):
        graph[p].append(n)
        graph[q].append(n)
    used, loops = [False] * len(segments), []
    for n, (start, point) in enumerate(segments):
        if used[n]:
            continue
        used[n], loop = True, [start]
        while point != start:
            loop.append(point)
            n = next((m for m in graph[point] if not used[m]), None)
            if n is None:
                break
            used[n] = True
            point = segments[n][1] if segments[n][0] == point else segments[n][0]
        loop = _simplify(loop)
        if len(loop) >= 3:
            loops.append(loop)
    assert loops
    return loops


def write_svg(loops, axis, output):
    # OpenSCAD の SVG と同じ向き: z 断面は y を反転し、y 断面は z をそのまま書く
    sign = -1 if axis == "z" else 1
    d = " ".join("M " + " L ".join(f"{x:.6f},{sign * y:.6f}" for x, y in loop) + " z" for loop in loops)
    Path(output).write_text(f'<svg xmlns="http://www.w3.org/2000/svg"><path d="{d}"/></svg>\n')


if __name__ == "__main__":
    # シェルのテスト用: stl_geometry.py svg <stl> <z|y> <position> <output.svg>
    _, command, stl, axis, position, output = sys.argv
    assert command == "svg"
    write_svg(section(stl, None, axis, float(position)), axis, output)
