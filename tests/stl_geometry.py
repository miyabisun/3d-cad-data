"""OpenSCADのproduction STLから閉曲面とSVG断面を測る共通処理。"""

import collections
import re
import struct
import subprocess
import xml.etree.ElementTree as ET


def render(source, output, defines=(), binary=False):
    result = subprocess.run(["openscad", "-o", str(output), *(["--export-format", "binstl"] if binary else []), *[v for d in defines for v in ("-D", d)], str(source)], capture_output=True, text=True)
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

def closed_mesh(stl):
    data = stl.read_bytes()
    if len(data) >= 84 and len(data) == 84 + struct.unpack_from("<I", data, 80)[0] * 50:
        vertices = [tuple(facet[i:i + 3]) for facet in struct.iter_unpack("<12fH", data[84:]) for i in (3, 6, 9)]
    else:
        vertices = [tuple(map(float, m)) for m in re.findall(r"vertex\s+(\S+)\s+(\S+)\s+(\S+)", data.decode())]
    assert vertices, "empty STL"
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


def section(stl, work, axis, position):
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
