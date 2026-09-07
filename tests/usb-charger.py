#!/usr/bin/env python3
"""LX充電器ホルダーのproduction STLを断面・閉曲面として実測する。"""

import collections
import math
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "assets/ergotron/usb-charger/lx_holder.scad"


def render(source, output):
    result = subprocess.run(["openscad", "-o", str(output), str(source)], capture_output=True, text=True)
    assert result.returncode == 0 and not re.search(r"ERROR|WARNING", result.stderr), result.stderr
    assert output.stat().st_size > 0


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


def hex_at(loops, x, z, flat):
    radius = flat / math.sqrt(3)
    loop = loop_at(loops, (x - radius, x + radius, z - flat / 2, z + flat / 2))
    # STLの三角分割による辺上の追加頂点を許し、六角の各辺上にあることを測る。
    for px, pz in loop:
        support = max((px - x) * math.cos(math.radians(a)) + (pz - z) * math.sin(math.radians(a)) for a in range(30, 390, 60))
        assert abs(support - flat / 2) < 0.03, ("non-hex hole", px, pz)
    return loop


with tempfile.TemporaryDirectory(prefix="usb-charger-test-") as temp:
    work = Path(temp)
    stl = work / "holder.stl"
    render(SOURCE, stl)
    vertices = [tuple(map(float, m)) for m in re.findall(r"vertex\s+(\S+)\s+(\S+)\s+(\S+)", stl.read_text())]
    assert vertices, "expected ASCII STL"
    near(bounds(vertices), (-38.1, 38.1, -3, 35.8, 0, 76.6))
    edges = collections.Counter()
    graph = collections.defaultdict(set)
    for i in range(0, len(vertices), 3):
        triangle = [tuple(round(v, 5) for v in p) for p in vertices[i:i + 3]]
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

    def section(axis, position):
        source, svg = work / "section.scad", work / "section.svg"
        transform = f"translate([0, 0, -{position}])" if axis == "z" else f"rotate([90, 0, 0]) translate([0, -{position}, 0])"
        source.write_text(f'projection(cut=true) {transform} import("{stl}");\n')
        render(source, svg)
        loops = []
        for path in ET.parse(svg).getroot().iter("{http://www.w3.org/2000/svg}path"):
            for sub in path.attrib["d"].split("M")[1:]:
                loops.append([(float(x), float(y) * (-1 if axis == "z" else 1)) for x, y in re.findall(r"(-?\d+\.?\d*),(-?\d+\.?\d*)", sub)])
        assert loops
        return loops

    plan = section("z", 30)
    cavity = loop_at(plan, (-35.1, 35.1, 0, 31.8))
    outer = loop_at(plan, (-38.1, 38.1, -3, 35.8))
    for loop, cx, cy, radius in [(cavity, 31.1, 4, 4), (cavity, 31.1, 27.8, 4), (outer, 31.1, 4, 7), (outer, 31.1, 28.8, 7)]:
        arc = [p for p in loop if p[0] > cx + 0.1 and (p[1] < cy - 0.1 if cy == 4 else p[1] > cy + 0.1)]
        assert len(arc) >= 6
        assert all(abs(math.dist(p, (cx, cy)) - radius) < 0.03 for p in arc)
    for p in [(0, -2.9), (0, -0.1), (0, 31.9), (12, 35.7), (38, 15)]:
        assert inside(plan, p), ("wall missing", p)
    assert not inside(plan, (0, 0.1)) and not inside(plan, (0, 31.7))
    loop_at(section("z", 76.5), (-35.1, 35.1, 0, 31.8))

    for z in [0.1, 1.5, 2.9]:
        floor = section("z", z)
        loop_at(floor, (-10.5, 10.5, 10.15, 23.15))
        empty_rect(floor, (-8.5, 8.5, 12.15, 21.15))
        assert inside(floor, (15, 16.65))
    vertical = section("y", 16.65)
    empty_rect(vertical, (-10.4, 10.4, -0.1, 76.7))
    assert inside(vertical, (15, 2.9)) and not inside(vertical, (15, 3.1))

    for y, flat in [(35.3, 6.4), (34.7, 6.6), (33.3, 9.4), (31.9, 12.2), (-1.5, 8.5)]:
        loops = section("y", y)
        for x in [-20, 20]:
            hex_at(loops, x, 61.6, flat)
            if y < 0:
                # 穴の内接円が六角ビットの全回転包絡円 + 半径0.5mmを包む。
                assert flat / 2 > 6.35 / math.sqrt(3) + 0.5
            assert not inside(loops, (x, 61.6))
    # 中央の突起を全高で逃がす。16×1.3の矩形領域に丸みの肉を戻さない。
    empty_rect(plan, (-8, 8, 34.5, 36))
    assert inside(plan, (0, 34.49)) and not inside(plan, (0, 34.51))
    assert inside(plan, (9.31, 35.79)) and not inside(plan, (9.29, 35.79))
    for sign in [-1, 1]:
        arc = [p for p in outer if 8.01 < sign * p[0] < 9.29 and 34.51 < p[1] < 35.79]
        assert len(arc) >= 6, ("missing rib relief fillet", sign)
        assert all(abs(math.dist(p, (sign * 8, 35.8)) - 1.3) < 0.03 for p in arc)
    empty_rect(section("y", 35), (-8, 8, -0.1, 76.7))
    # 最小残肉2.7mmの裏側(充電器側)と工具側の壁は連続して残る。
    assert inside(section("y", 34.4), (0, 38))

    # 上段で固定したときの中段・下段4箇所。奥面から深さ1mmで止まる。
    for y in [34.81, 35.3, 35.79]:
        loops = section("y", y)
        for x in [-20, 20]:
            for z in [36.6, 11.6]:
                hex_at(loops, x, z, 6.4)
    for y in [31.9, 34.79, -1.5]:
        loops = section("y", y)
        for x in [-20, 20]:
            for z in [36.6, 11.6]:
                assert inside(loops, (x, z)), ("tip pocket breaks through or is on wrong wall", x, y, z)
    print("usb-charger: fit dimensions, rib relief R1.3, four blind tip pockets and single closed solid passed")
