#!/bin/bash
# Gridfinity bin の代表4U（1x1・1x2・3x5、薄いリップ、13mmのラベル天板）と、
# 2x3x4U のカードケース (内側を埋めて隅にカードのポケット、右奥のマスに指の窪みを抜いたもの) のレンダリング検証。
# - openscad が exit 0 で非空の STL を生成し、console に ERROR / WARNING が無いこと
# - 設計契約 (CONTRACT echo) が台帳の確定値と一致すること
# - production STL の断面実測で、底の 3 段輪郭 (35.6/37.2/41.5)・42 ピッチ・
#   外形 41.5 角と全高・壁 1.2・床・薄いリップ・ラベル天板 13mm とその下の 45° くさびを
#   実形状として固定すること (echo は自己申告なので形状で裏を取る)
# - 底面に穴が無いこと (磁石穴・ネジ穴を持たない)
# - 各 STL が1連結成分であること
# - カードケース: ポケット 55×86.6 (R3) が X 中央・手前から 10 内側に床の天面から上へ開き、右奥のマスが
#   壁の内面まで抜けて (隅 R2.55)、その床と底が外形に平行な 45° の窪み (床 z=2.95、貫通しない) になり、
#   ポケットと穴の交点の縦エッジが R2 で丸く、左右の埋めの天面に 12mm 以上の平面 (ラベル帯) が残ること
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0
err() {
  echo "gridfinity-bin: $*" >&2
  fail=1
}

# render <name> <scad> — STL 生成と console 検査。console は $WORK/<name>.log に残す
render() {
  name=$1 scad=$2
  if ! openscad -o "$WORK/$name.stl" "$ROOT/$scad" > "$WORK/$name.log" 2>&1; then
    err "$name: openscad failed"
    cat "$WORK/$name.log" >&2
    return
  fi
  [ -s "$WORK/$name.stl" ] || err "$name: STL is empty"
  # STL が意味のある大きさか (ヘッダだけの空形状を弾く)
  size=$(stat -c %s "$WORK/$name.stl")
  [ "$size" -gt 10000 ] || err "$name: STL is suspiciously small ($size bytes)"
  if grep -Eq 'ERROR|WARNING' "$WORK/$name.log"; then
    err "$name: console has ERROR/WARNING"
    grep -E 'ERROR|WARNING' "$WORK/$name.log" >&2
  fi
}

# expect_echo <name> <payload> — CONTRACT echo の完全一致検査。
# openscad の console は echo(str(...)) を `ECHO: "<payload>"` という1行で書くので、
# 行全体と突き合わせる (grep -Fx)。部分一致で照合すると、期待値 36 が 360 でも、
# 8.4 が 8.41 でも通ってしまい、値を固定できない
expect_echo() {
  name=$1 payload=$2
  grep -Fxq "ECHO: \"$payload\"" "$WORK/$name.log" \
    || err "$name: missing contract echo: $payload"
}

# 水平断面 (X-Y) の実測: 指定 z で切る。2D X = 部品X、生 y = -部品Y。
# spec の節:
#   loops <n>                        — loop の数
#   rect <x1> <x2> <y1> <y2>         — 最大 loop (外形) の bbox
#   loop <cx> <cy> <sx> <sy>         — 指定位置に指定 bbox の loop がある (穴の実測)
#   solid <cx> <cy> / void <cx> <cy> — 指定点に材料が有る/無い
#   winbox <cx> <cy> <sx> <sy>       — 指定の矩形の中に収まる (外形以外の) loop が
#       ちょうど 4 本あり、その union の bbox が矩形と一致する (X 窓の実寸)
#   arc <cx> <cy> <r> <x1> <x2> <y1> <y2> — 矩形 [x1,x2]×[y1,y2] に入る (全 loop の) 頂点が
#       5 個以上あり、すべて (cx,cy) から距離 r (±0.05) にある (角の丸みの実測)
#   grid <x0> <dx> <nx> <y0> <dy> <ny> <span> — 外形以外の span 角の全 loop の
#       中心の集合が格子 {x0+i*dx} × {y0+j*dy} と過不足なく一致する
# solid/void は全 loop を偶奇規則で数える内外判定なので、穴・ポケットの中は
# 外側 (材料無し) になる。bbox では見えない「肉の抜け」を直接測る。
# この部品は全周が曲面 (楕円・円・六角) なので、外形は bbox と点の内外で測る
check_plan() {
  stl=$1 name=$2 cut_z=$3 spec=$4
  cat > "$WORK/plan_$name.scad" <<EOF
projection(cut = true) translate([ 0, 0, -$cut_z ]) import("$WORK/$stl.stl");
EOF
  if ! openscad -o "$WORK/plan_$name.svg" "$WORK/plan_$name.scad" > /dev/null 2>&1; then
    err "plan $name: failed to render"
    return
  fi
  python3 - "$WORK/plan_$name.svg" "$name" "$spec" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name, spec = sys.argv[2], sys.argv[3]
loops = []
for sub in re.search(r'd="([^"]+)"', src).group(1).split("M")[1:]:
    pts = [(float(a), -float(b)) for a, b in re.findall(r'(-?\d+\.?\d*),(-?\d+\.?\d*)', sub)]
    loops.append(pts)


def bbox(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return (min(xs), max(xs), min(ys), max(ys))


def inside(x, y):  # 偶奇規則 (+X 方向へ ray を飛ばして交差数を数える)
    hits = 0
    for pts in loops:
        for i in range(len(pts)):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % len(pts)]
            if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
                hits += 1
    return hits % 2 == 1


body = max(loops, key=lambda p: (bbox(p)[1] - bbox(p)[0]) * (bbox(p)[3] - bbox(p)[2]))
ok = True
for cond in spec.split(";"):
    kind, *args = cond.split()
    if kind == "loops":
        want = int(args[0])
        print(f"plan {name}: {len(loops)} loops (want {want})")
        if len(loops) != want:
            ok = False
    elif kind == "rect":  # rect <x1> <x2> <y1> <y2>
        x1, x2, y1, y2 = map(float, args)
        b = bbox(body)
        print(f"plan {name}: rect x=[{b[0]:.3f},{b[1]:.3f}]"
              f" y=[{b[2]:.3f},{b[3]:.3f}] span x={b[1] - b[0]:.3f}")
        if any(abs(a - c) > 0.05 for a, c in zip(b, (x1, x2, y1, y2))):
            print(f"plan {name}: rect want x=[{x1},{x2}] y=[{y1},{y2}]")
            ok = False
    elif kind == "loop":  # loop <cx> <cy> <sx> <sy>
        cx, cy, sx, sy = map(float, args)
        hit = [l for l in map(bbox, loops)
               if abs((l[0] + l[1]) / 2 - cx) < 0.1 and abs((l[2] + l[3]) / 2 - cy) < 0.1
               and abs((l[1] - l[0]) - sx) < 0.05 and abs((l[3] - l[2]) - sy) < 0.05]
        if not hit:
            print(f"plan {name}: missing loop ({cx},{cy}) span ({sx},{sy})")
            print(f"plan {name}: loops = "
                  f"{[tuple(round(v, 3) for v in bbox(l)) for l in loops]}")
            ok = False
        else:
            l = hit[0]
            print(f"plan {name}: loop x=[{l[0]:.3f},{l[1]:.3f}] y=[{l[2]:.3f},{l[3]:.3f}]"
                  f" span ({l[1] - l[0]:.3f},{l[3] - l[2]:.3f})")
    elif kind == "winbox":  # <cx> <cy> <sx> <sy>
        cx, cy, sx, sy = map(float, args)
        box = (cx - sx / 2 - 0.1, cx + sx / 2 + 0.1, cy - sy / 2 - 0.1, cy + sy / 2 + 0.1)
        inner = [bbox(l) for l in loops if l is not body]
        inner = [b for b in inner
                 if b[0] >= box[0] and b[1] <= box[1] and b[2] >= box[2] and b[3] <= box[3]]
        u = (min(b[0] for b in inner), max(b[1] for b in inner),
             min(b[2] for b in inner), max(b[3] for b in inner)) if inner else None
        print(f"plan {name}: winbox ({cx},{cy}) {len(inner)} loops, union "
              f"{tuple(round(v, 3) for v in u) if u else None}")
        want = (cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2)
        if len(inner) != 4 or any(abs(a - c) > 0.05 for a, c in zip(u, want)):
            print(f"plan {name}: winbox want 4 loops with union {want}")
            ok = False
    elif kind == "arc":  # <cx> <cy> <r> <x1> <x2> <y1> <y2> (全 loop の頂点が対象。矩形で 1 つの角に絞る)
        cx, cy, r, x1, x2, y1, y2 = map(float, args)
        pts = [p for l in loops for p in l if x1 <= p[0] <= x2 and y1 <= p[1] <= y2]
        dist = [((p[0] - cx) ** 2 + (p[1] - cy) ** 2) ** 0.5 for p in pts]
        print(f"plan {name}: arc ({cx},{cy}) r={r}: {len(pts)} vertices, "
              f"r=[{min(dist):.3f},{max(dist):.3f}]" if pts else f"plan {name}: arc: no vertices")
        if len(pts) < 5 or any(abs(d - r) > 0.05 for d in dist):
            print(f"plan {name}: arc want >=5 vertices at r={r} from ({cx},{cy})")
            ok = False
    elif kind == "grid":  # <x0> <dx> <nx> <y0> <dy> <ny> <span>
        x0, dx, nx, y0, dy, ny, span = map(float, args)
        want = {(round(x0 + i * dx, 3), round(y0 + j * dy, 3))
                for i in range(int(nx)) for j in range(int(ny))}
        # 外形以外の loop のうち span 角のものだけが対象 (他の大きさの穴は別の節で数える)
        holes = [b for b in (bbox(l) for l in loops if l is not body)
                 if abs((b[1] - b[0]) - span) <= 0.05 and abs((b[3] - b[2]) - span) <= 0.05]
        got = {(round((b[0] + b[1]) / 2, 3), round((b[2] + b[3]) / 2, 3)) for b in holes}
        # 中心は格子と 0.05 以内で一致しなければならない (集合として過不足なし)
        matched = {w for w in want if any(abs(w[0] - g[0]) < 0.05 and abs(w[1] - g[1]) < 0.05 for g in got)}
        extra = [g for g in got if not any(abs(w[0] - g[0]) < 0.05 and abs(w[1] - g[1]) < 0.05 for w in want)]
        print(f"plan {name}: grid {len(matched)}/{len(want)} centers matched,"
              f" {len(extra)} extra (span {span})")
        if len(matched) != len(want) or extra:
            print(f"plan {name}: missing {sorted(want - matched)} extra {extra}")
            ok = False
    elif kind in ("solid", "void"):  # <cx> <cy>
        cx, cy = map(float, args)
        got = inside(cx, cy)
        print(f"plan {name}: ({cx},{cy}) is {'solid' if got else 'void'}")
        if got != (kind == "solid"):
            print(f"plan {name}: want {kind} at ({cx},{cy})")
            ok = False
print(f"plan {name}: {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PYEOF
}

# 縦断面 (X-Z) の実測: production STL を指定 y で切り、輪郭の bbox と材料の
# 有無を測る。rotate([90,0,0]) で部品Y軸が切断面法線になり、2D X = 部品X、
# SVG の生 y = 部品Z (openscad の SVG は y 軸を反転して書く)。
# 水平断面は「その高さで何が在るか」しか見えないので、段の切り替わる Z と
# 穴が上まで開いているかは、この縦断面で測る。
# spec の節:
#   loop <cx> <cz> <span_x> <span_z> — 指定位置に指定 bbox の loop がある
#   arc <cx> <cz> <r> <x1> <x2> <z1> <z2> — 矩形に入る頂点が 5 個以上あり全部 (cx,cz) から r
#   solid <x> <z> / void <x> <z>     — 指定点に材料が有る/無い
#   void_rect <x1> <x2> <z1> <z2>    — 矩形領域の内部が完全に空 (材料ゼロ)
# void_rect は幾何交差で領域の空を測る: 全 loop の全辺と矩形の線分交差が0本
# (= 材料の境界が領域へ入って来ない) かつ、5点の偶奇判定がすべて外側
# (= 領域が材料に包含されていない) のときだけ空とみなす。点のサンプリングでは
# 「サンプルの隙間に薄膜が残る」退行 (穴を横切る 1mm 未満の天井) を見逃すため、
# 穴の連続性はこの交差判定で測る
check_section() {
  stl=$1 name=$2 cut_y=$3 spec=$4
  cat > "$WORK/sec_$name.scad" <<EOF
projection(cut = true) rotate([ 90, 0, 0 ]) translate([ 0, -($cut_y), 0 ])
  import("$WORK/$stl.stl");
EOF
  if ! openscad -o "$WORK/sec_$name.svg" "$WORK/sec_$name.scad" > /dev/null 2>&1; then
    err "section $name: failed to render"
    return
  fi
  section_eval "$name" "$spec"
}

# section_eval <name> <spec> — $WORK/sec_<name>.svg を spec で検査する (断面の向きに依らない)
section_eval() {
  name=$1 spec=$2
  python3 - "$WORK/sec_$name.svg" "$name" "$spec" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name, spec = sys.argv[2], sys.argv[3]
loops = []
for sub in re.search(r'd="([^"]+)"', src).group(1).split("M")[1:]:
    loops.append([(float(a), float(b)) for a, b
                  in re.findall(r'(-?\d+\.?\d*),(-?\d+\.?\d*)', sub)])


def bbox(pts):
    xs, zs = [p[0] for p in pts], [p[1] for p in pts]
    return (min(xs), max(xs), min(zs), max(zs))


def inside(x, z):  # 偶奇規則 (+X 方向へ ray を飛ばして交差数を数える)
    hits = 0
    for pts in loops:
        for i in range(len(pts)):
            x1, z1 = pts[i]
            x2, z2 = pts[(i + 1) % len(pts)]
            if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
                hits += 1
    return hits % 2 == 1


# 線分 pq が矩形の内部を正の長さで通るか (Liang-Barsky のクリッピング)。
# 矩形は境界を eps だけ内側へ縮めてあるので、切断面と重なるだけの辺
# (= 領域の縁そのもの) は交差扱いにならない
def seg_crosses(p, q, x1, x2, z1, z2):
    dx, dz = q[0] - p[0], q[1] - p[1]
    t0, t1 = 0.0, 1.0
    for den, num in ((-dx, p[0] - x1), (dx, x2 - p[0]),
                     (-dz, p[1] - z1), (dz, z2 - p[1])):
        if den == 0:
            if num < 0:  # 辺が境界と平行で、矩形の外側にある
                return False
        else:
            t = num / den
            if den < 0:
                t0 = max(t0, t)
            else:
                t1 = min(t1, t)
            if t0 > t1:
                return False
    return t1 > t0


ok = True
for cond in spec.split(";"):
    kind, *args = cond.split()
    if kind == "loop":  # loop <cx> <cz> <span_x> <span_z>
        cx, cz, sx, sz = map(float, args)
        hit = [l for l in map(bbox, loops)
               if abs((l[0] + l[1]) / 2 - cx) < 0.1 and abs((l[2] + l[3]) / 2 - cz) < 0.1
               and abs((l[1] - l[0]) - sx) < 0.05 and abs((l[3] - l[2]) - sz) < 0.05]
        if not hit:
            print(f"section {name}: missing loop ({cx},{cz}) span ({sx},{sz})")
            print(f"section {name}: loops = "
                  f"{[tuple(round(v, 3) for v in bbox(l)) for l in loops]}")
            ok = False
        else:
            l = hit[0]
            print(f"section {name}: loop x=[{l[0]:.3f},{l[1]:.3f}]"
                  f" z=[{l[2]:.3f},{l[3]:.3f}]")
    elif kind in ("solid", "void"):  # <x> <z>
        x, z = map(float, args)
        got = inside(x, z)
        print(f"section {name}: ({x},{z}) is {'solid' if got else 'void'}")
        if got != (kind == "solid"):
            print(f"section {name}: want {kind} at ({x},{z})")
            ok = False
    elif kind == "arc":  # <cx> <cz> <r> <x1> <x2> <z1> <z2>
        cx, cz, r, x1, x2, z1, z2 = map(float, args)
        pts = [p for l in loops for p in l if x1 <= p[0] <= x2 and z1 <= p[1] <= z2]
        dist = [((p[0] - cx) ** 2 + (p[1] - cz) ** 2) ** 0.5 for p in pts]
        print(f"section {name}: arc ({cx},{cz}) r={r}: {len(pts)} vertices, "
              + (f"r=[{min(dist):.3f},{max(dist):.3f}]" if pts else "none"))
        if len(pts) < 5 or any(abs(d - r) > 0.05 for d in dist):
            print(f"section {name}: arc want >=5 vertices at r={r} from ({cx},{cz})")
            ok = False
    elif kind == "void_rect":  # <x1> <x2> <z1> <z2>
        x1, x2, z1, z2 = map(float, args)
        # 領域の縁に載るだけの辺 (切断面そのもの) を交差扱いしないための許容。
        # STL/SVG の座標は有効6桁で書かれ実測で ~2e-5mm ずれるので、それを
        # 十分超え、かつ検出したい薄膜 (0.2mm 級) より桁違いに小さい 1e-3 を取る
        eps = 1e-3
        rect = (x1 + eps, x2 - eps, z1 + eps, z2 - eps)
        # (1) 材料の境界が領域内へ入ってくるか: 全 loop の全辺 × 矩形の交差
        edges = [(pts[i], pts[(i + 1) % len(pts)])
                 for pts in loops for i in range(len(pts))]
        crossing = [e for e in edges if seg_crosses(e[0], e[1], *rect)]
        # (2) 辺が1本も入らないなら領域は「全部材料」か「全部空」のどちらか。
        #     偶奇判定 (4隅 + 中心) で材料に包含されている側を弾く
        probes = [(rect[0], rect[2]), (rect[1], rect[2]), (rect[0], rect[3]),
                  (rect[1], rect[3]), ((x1 + x2) / 2, (z1 + z2) / 2)]
        filled = [p for p in probes if inside(*p)]
        print(f"section {name}: void_rect x=[{x1},{x2}] z=[{z1},{z2}]:"
              f" {len(crossing)} crossing edges, {len(filled)}/5 probes solid")
        if crossing or filled:
            if crossing:
                print(f"section {name}: material boundary enters the rect at"
                      f" {[tuple(round(v, 4) for v in e[0]) for e in crossing[:5]]}"
                      f"{' ...' if len(crossing) > 5 else ''}")
            if filled:
                print(f"section {name}: material fills the rect at {filled[:5]}")
            ok = False
print(f"section {name}: {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PYEOF
}

# check_bbox <name> <x1> <x2> <y1> <y2> <z1> <z2> — STL 頂点の外形実測
check_bbox() {
  name=$1
  shift
  python3 - "$WORK/$name.stl" "$name" "$@" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name = sys.argv[2]
want = list(map(float, sys.argv[3:]))
vs = [tuple(map(float, v)) for v in
      re.findall(r'vertex\s+(\S+)\s+(\S+)\s+(\S+)', src)]
got = []
for i in range(3):
    col = [v[i] for v in vs]
    got += [min(col), max(col)]
print(f"bbox {name}: x=[{got[0]:.3f},{got[1]:.3f}] y=[{got[2]:.3f},{got[3]:.3f}]"
      f" z=[{got[4]:.3f},{got[5]:.3f}] span x={got[1] - got[0]:.3f}")
ok = all(abs(a - b) < 0.05 for a, b in zip(got, want))
if not ok:
    print(f"bbox {name}: want {want}")
print(f"bbox {name}: {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PYEOF
}

# 共通STL検査で単一連結・閉曲面・非縮退を確認する。
check_single_solid() {
  PYTHONPATH="$ROOT/tests" python3 - "$WORK/$1.stl" <<'PYEOF' || fail=1
from pathlib import Path
import sys
from stl_geometry import closed_mesh
closed_mesh(Path(sys.argv[1]))
PYEOF
}

# 全56種の検証はgridfinity-bin-matrix.py。このテストは整数binと専用品の詳細断面を保つ。
CONTRACT="CONTRACT units=4 pitch=42 outer=41.5 h=28 lip=4.4 base=35.6/37.2/41.5 base_h=4.75 wall=1.2 floor_top=5.95 label=13x1 wedge=45 fillet=1"
for bin_size in 1x1 1x2 3x5; do
  c=${bin_size%x*} r=${bin_size#*x}
  render "b$bin_size" "assets/gridfinity-bin/4u/$bin_size.scad"
  expect_echo "b$bin_size" "$CONTRACT bin=$bin_size size=$((c * 42 - 1)).5x$((r * 42 - 1)).5"
  half=$((c * 21 - 1)).75
  check_bbox "b$bin_size" -$half $half 0 $((r * 42 - 1)).5 0 32.4
  check_single_solid "b$bin_size"
done

# ---------------------------------------------------------------------------
# 1. 底の 3 段輪郭と 42 ピッチ。z=0.4 (下の面取りの中) で 35.6 + 0.8 = 36.4 角、
#    z=2.0 (垂直部) で 37.2 角、z=4.0 (上の面取りの中: 37.2 + 2×(4.0−2.6)) で 40.0 角。
#    底の中心は bin 座標で y = 20.75 (外形 41.5 の中心。ソケットの中心 21 に置くと
#    bin は 0.25..41.25 に収まる)。1x2 は底が 2 個 (20.75, 62.75) で、その間
#    (y=41.75) は z=2 で空
# ---------------------------------------------------------------------------
check_plan b1x1 base-lo 0.4 "loops 1; rect -18.2 18.2 2.55 38.95"
check_plan b1x1 base-mid 2.0 "loops 1; rect -18.6 18.6 2.15 39.35; solid 0 21"
check_plan b1x1 base-hi 4.0 "loops 1; rect -20 20 0.75 40.75"
check_plan b1x2 base-mid 2.0 \
  "loops 2; loop 0 20.75 37.2 37.2; loop 0 62.75 37.2 37.2; void 0 41.75; solid 0 21; solid 0 63"
# 底面に穴が無い: z=0.4 で loop は外形 1 本だけ (穴があれば loop が増える)
check_plan b1x2 base-lo 0.4 "loops 2; solid 0 21; solid 0 63; solid 8 13; solid -8 29"

# ---------------------------------------------------------------------------
# 2. 胴体と床。z=12 (床の上、ラベルのくさびの下端 z=14 より下) で外形 41.5 角 +
#    内側の空 39.1 角 (壁 1.2) の 2 loop。
#    床の天面は z=5.95: (0,21) は z=5.5 で材料、z=6.5 で空
# ---------------------------------------------------------------------------
check_plan b1x1 body 12 \
  "loops 2; rect -20.75 20.75 0 41.5; loop 0 20.75 39.1 39.1;
   void 0 21; solid -20.15 21; solid 20.15 21; solid 0 0.6; solid 0 40.9"
check_plan b1x2 body 12 "loops 2; rect -20.75 20.75 0 83.5; loop 0 41.75 39.1 81.1; void 0 42"
check_section b1x1 floor 21 "solid 0 5.5; void 0 6.5; solid 0 4; solid -20.15 15; solid 20.15 15; void 0 15"

# ---------------------------------------------------------------------------
# 3. 薄いリップ。壁 1.2 がそのまま z=32.4 まで立ち、内側の上端 0.8 を 45° に
#    落とす (上の bin の底の面取りがここに座る)。内側にリップの肉 (棚) は無い。
#    縦断面 (y=21、X-Z): z=31 で壁の内面は 19.55 のまま (棚があれば内側に肉が出る)、
#    z=32.0 では面取りで内面が 19.95 へ退く
# ---------------------------------------------------------------------------
check_section b1x1 lip 21 \
  "solid -20.15 31; solid 20.15 31; void 19.2 31; void -19.2 31; void 0 31;
   void 19.9 32.0; solid 20.4 32.0; void 0 32.5"

# ---------------------------------------------------------------------------
# 4. ラベル天板と 45° くさび。手前の壁の内面 (y=1.2) から y=14.2 まで、z=27..28 の
#    天板 (厚さ 1)。その下は 45° の斜面が先端 (14.2, 27) から壁へ下りる無垢の
#    くさび。斜面 z = 27 − (14.2 − y) は契約値として y=1.3 で 14.1、y=5 で 17.8、
#    y=10 で 22.8、y=13 で 25.8 にあり、各点を ±0.08 で挟んで 45° を固定する
#    (斜面の上がくさびの材料、下が空) (壁側の終点を 1 下げて 47° にすると y=5 で 17.15 になり red)。
#    内幅いっぱい (x=±19.55) に同じ断面なので、x=0 / 5 / 15 のどこで切っても同じ
#    (x>17 は内側の角 R2.55 に掛かり y=1.3 が壁の中になるので、そこでは切らない)。
#    先端の垂直面 (z=27..28) と 45° 面の境目 (14.2, 27) は R1: 円弧の中心は
#    (13.2, 27.414) で、接点は垂直面の (14.2, 27.414) と斜面の (13.907, 26.707)。
#    断面の頂点のうち y∈[13.5,14.3] z∈[26.6,27.6] にあるものが全部この円弧上に
#    あることで R を固定する
# ---------------------------------------------------------------------------
# Y-Z 断面: 指定 x で切る。2D X = 部品Y、生 y = 部品Z (X-Z 断面と同じ流儀)
check_section_yz() {
  stl=$1 name=$2 cut_x=$3 spec=$4
  cat > "$WORK/yz_$name.scad" <<EOS
projection(cut = true) rotate([ 90, 0, 0 ]) rotate([ 0, 0, -90 ])
  translate([ -($cut_x), 0, 0 ]) import("$WORK/$stl.stl");
EOS
  if ! openscad -o "$WORK/sec_$name.svg" "$WORK/yz_$name.scad" > /dev/null 2>&1; then
    err "section $name: failed to render"
    return
  fi
  section_eval "$name" "$spec"
}
WEDGE="solid 5 27.5; solid 13.8 27.5; void 14.6 27.5; void 5 28.5;
   void 1.3 14.02; solid 1.3 14.18; void 5 17.72; solid 5 17.88;
   void 10 22.72; solid 10 22.88; void 13 25.72; solid 13 25.88;
   solid 5 20; void 5 16; void 10 21; void 13 24.5;
   arc 13.2 27.414 1 13.5 14.3 26.6 27.6; void 25 27.5"
check_section_yz b1x1 wedge-x0 0 "$WEDGE"
check_section_yz b1x1 wedge-x5 5 "$WEDGE"
check_section_yz b1x1 wedge-x15 15 "$WEDGE"
check_section_yz b1x2 wedge-x0 0 "solid 5 27.5; solid 13.8 27.5; void 14.6 27.5; solid 5 20; void 5 16; void 42 27.5; void 80 27.5"
# X-Z 断面 (y=8、くさびの中): z=22 は内幅いっぱい材料 (斜面は y=8 で z=20.8)、
#    z=19.5 は空。内面 (±19.55) の直前 ±19.5 まで材料が続く (側壁に溶けている)
check_section b1x1 wedge-width 8 \
  "solid 0 27.5; solid -19.5 27.5; solid 19.5 27.5; solid 0 22; solid 15 22; solid -15 22;
   solid 19.5 22; solid -19.5 22; void 19.5 20.72; solid 19.5 20.88;
   void 0 19.5; void 15 19.5; void 0 12"

# ---------------------------------------------------------------------------
# 5. くさびと天板は bin の角丸外形 (R3.75) の内側に収まる。矩形の柱をそのまま
#    置くと、壁へ食い込ませた 1mm ぶんが角の丸みの外へ出る。外壁の角の円は
#    中心 (±17, 3.75) 半径 3.75 で、x=19.5 では外面が y=0.955、x=18.5 では
#    y=0.31 まで後退する。角の丸みの領域 (|x| > 17) の Y-Z 断面で、外面より
#    手前 (y=0.3) がくさびの高さ (z=20) と天板 (z=27.5) で void、外面より内側が
#    solid であることを測る (水平断面はこの STL で CGAL の projection が落ちるので
#    縦断面で測る)
# ---------------------------------------------------------------------------
CORNER="void 0.3 20; void 0.3 27.5; void 0.3 24; solid 1.5 20; solid 1.5 24; solid 1.5 27.5; solid 5 27.5"
INSIDE="solid 0.9 20; solid 0.9 24; solid 0.9 27.5; void 0.1 20"
check_section_yz b1x1 corner-clip-r 19.5 "$CORNER"
check_section_yz b1x1 corner-clip-l -19.5 "$CORNER"
check_section_yz b1x1 corner-inside 18.5 "$INSIDE"
check_section_yz b1x2 corner-clip-r 19.5 "$CORNER"
check_section_yz b1x2 corner-clip-l -19.5 "$CORNER"
check_section_yz b1x2 corner-inside 18.5 "$INSIDE"

# ---------------------------------------------------------------------------
# 6. 最大の整数サイズ3x5。底の格子3×5、角のクリップ、ラベル天板の内幅123.1。
# ---------------------------------------------------------------------------
GRID="loops 15"
for x in -42 0 42; do
  for j in 0 1 2 3 4; do
    GRID="$GRID; loop $x $((j * 42 + 20)).75 37.2 37.2"
  done
done
check_plan b3x5 base-mid 2.0 "$GRID"
check_section_yz b3x5 corner-clip-r 61.5 "$CORNER"
check_section_yz b3x5 corner-clip-l -61.5 "$CORNER"
check_section_yz b3x5 corner-inside 60.5 "$INSIDE"
check_section b3x5 label-width 8 \
  "solid 0 27.5; solid -61.5 27.5; solid 61.5 27.5; solid 0 22; solid 61.5 22; solid -61.5 22; void 0 19.5"

# ---------------------------------------------------------------------------
# 7. カードケース 2x3x4U。外形・底・リップは bin と同じでラベル天板無し。内側は床の天面 (5.95) から
#    壁の上端 (28) まで無垢で埋め、そこからカードのポケットと右奥のマスの穴を抜く。
#    - ポケット: カード (ISO/IEC 7810 ID-1) 54×85.6 + 1 = 55 (X) × 86.6 (Y)、隅 R3 (user 指定)。
#      X は中央 (x -27.5..27.5)、手前の壁の内側から 10 内側 (y 11.2..97.8)。床は bin の床 (z=5.95)。
#      左右の埋めの天面 (z=28) は幅 13.05 の平面で、12mm のラベルを貼る帯になる
#    - 穴: 右奥のマス (x 0.25..40.55、y 84..124.3)。隅は内壁と同じ R2.55 (奥右の隅は壁の内側の角と
#      一致する)。埋めは壁の内面まで抜く。床と底のマスは、外形の 3 段を壁厚 1.2 だけ内側へ寄せた
#      平行な窪みにする: 39.1 角 (R2.55) @ z=5.95 → 45° → 34.8 角 (R0.4) @ 3.8 → 垂直 → 床 z=2.95
#      (床の天面から 3.0 下がる。底の皮 2.95 で貫通しない)。
#      cut は壁との面の一致を避けるため各段 0.02 小さい (39.08 / 34.78)
#    - 交点の縦エッジ: ポケットの右の辺 (x=27.5) × 穴の手前の辺 (y=84) と、穴の左の辺 (x=0.25) ×
#      ポケットの奥の辺 (y=97.8) にできる埋めの凸の縦エッジを R2 で丸める (弧の中心 (29.5, 82) と
#      (-1.75, 99.8))。壁は上端まで垂直 (開口の上縁は丸めない)
#    - カードの右奥の角 (x 0.25..27.0、y 84..97.3) が穴の上に張り出す。その下は床の天面から 45° で下がる窪み
# ---------------------------------------------------------------------------
render card "assets/gridfinity-bin/goods/card_case_2x3x4u.scad"
expect_echo card "CONTRACT card units=4 bin=2x3 size=83.5x125.5 h=28 lip=4.4 floor_top=5.95 card=54x85.6 pocket=55x86.6 at=-27.5,11.2 hole=0.25,84 hole_r=2.55 recess=39.1/34.8 recess_floor=2.95 r=3 edge_r=2"
check_bbox card -41.75 41.75 0 125.5 0 32.4
check_single_solid card
# z=15: 外形と、ポケットと穴が角で繋がった 1 つの空洞。ポケットの 4 辺 (x=±27.5、y=11.2 / 97.8) と
#    穴の縁 (x=0.25、y=84) の両側で solid/void を測り、隅の R を円弧の頂点距離で測る
#    (ポケットの手前左・手前右・奥左は R3。穴の奥左・手前右・奥右は R2.55。奥右は壁の内側の角そのもの)。
#    交点の 2 本の縦エッジは R2 の弧 (中心 (29.5, 82) / (-1.75, 99.8)): 弧の外の元の角の位置 (27.75, 83.7) /
#    (0, 98.1) は空、弧の内側 (29.05, 82.4) / (-1.3, 99.4) は無垢
check_plan card pocket 15 \
  "loops 2; rect -41.75 41.75 0 125.5;
   void 27.75 83.7; solid 29.05 82.4; void 0 98.1; solid -1.3 99.4;
   arc 29.5 82 2 27.45 29.55 81.95 84.05; arc -1.75 99.8 2 -1.8 0.3 97.75 99.85;
   void -3.2 54.45; void 26.5 54.45; solid 28 54.45; void -27 54.45; solid -28 54.45; solid -35 54.45;
   void -3.2 12; solid -3.2 10.5; solid -3.2 6; void -3.2 97.2; solid -3.2 98.2; solid -10 105;
   void 21 104.75; void 12 90; solid -0.5 104.75; void 0.75 104.75; solid 32 83.5; void 32 84.5;
   solid 32 40; solid 35 70; solid -20 110;
   arc -24.5 14.2 3 -27.55 -24.45 11.15 14.25; arc 24.5 14.2 3 24.45 27.55 11.15 14.25; arc -24.5 94.8 3 -27.55 -24.45 94.75 97.85;
   arc 2.8 121.75 2.55 0.2 2.85 121.7 124.35; arc 38 86.55 2.55 37.95 40.6 83.95 86.6; arc 38 121.75 2.55 37.95 40.6 121.7 124.35"
# z=27.5 は埋めの中、z=30 はリップの内側 (埋めは 28 で終わる)
check_plan card fill-top 27.5 "loops 2; solid 32 40; solid -20 110; solid -35 54.45; void 21 104.75; void -3.2 54.45"
check_plan card lip 30 "loops 2; rect -41.75 41.75 0 125.5; loop 0 62.75 81.1 123.1; void 32 40; void 21 104.75; solid 41.2 62.75"
# z=5.5 (床の中): 窪みの上の 45° の途中 (幅 34.78 + 2×1.7 = 38.18)。ポケットの下は床。カードの角の下
#    (x=12、y=90) は窪み。穴の縁 (x=0.25 / y=84) から窪みの縁 (x=1.91 / y=85.66) までは床の棚
check_plan card floor 5.5 \
  "loops 2; loop 21 104.75 38.18 38.18; void 21 104.75; solid -3.2 54.45; void 12 90; solid 12 85.0; solid 0.5 90;
   solid 21 85.0; void 21 86.0; solid 40.3 104.75"
# z=3.3 (窪みの垂直部、底のマスは上の面取りの中で 38.6 角): 6 マス + 窪み 34.78 角の 7 loop。
#    右奥のマスの肉 (y 85.45..87.36) は残る
check_plan card recess-mid 3.3 \
  "loops 7; loop 21 104.75 34.78 34.78; loop 21 104.75 38.6 38.6; loop -21 104.75 38.6 38.6; loop 21 62.75 38.6 38.6;
   void 21 104.75; solid 21 86.5; solid 21 62.75; solid -21 104.75"
# z=2.5 (窪みの床 2.95 より下: 皮が残る。マスは垂直部 37.2)
check_plan card recess-skin 2.5 "loops 6; solid 21 104.75; loop 21 104.75 37.2 37.2"
# Y-Z 断面 (x=21、窪みの中心。x=21 はポケットの中でもある): 窪みの床 z=2.95 (2.8 で solid、3.1 で void)、
#    上の 45° (z=5.0 で y=86.16、z=4.0 で y=87.16、±0.25 で挟む)、垂直部 (y=87.36)。
#    ポケットの床の上 (y=54.45) は空、手前の埋め (y=6) は無垢。窪みは外壁に達しない
check_section_yz card recess-x21 21 \
  "solid 104.75 2.8; void 104.75 3.1; solid 86.5 3.3; void 88 3.3; void 86.4 5.0; solid 85.9 5.0; void 87.4 4.0; solid 86.9 4.0;
   solid 54.45 5.5; void 54.45 6.5; void 54.45 20; solid 6 20; void 90 20; void 104.75 20; void 104.75 27.5;
   void 104.75 30; solid 124.9 30; solid 0.6 30; solid 123.8 5.0; solid 122.6 3.3"
# Y-Z 断面 (x=10、カードの右奥の角の下): ポケットの床の上は空、角の張り出し (y 84..97.3) の下に
#    45° で下がる窪みがあり、その床は z=2.95。穴とポケットは繋がって上まで空
check_section_yz card corner-x10 10 \
  "solid 54.45 5.5; void 54.45 6.5; void 54.45 20; void 90 6.5; void 90 20; solid 124.9 20;
   solid 85.4 5.5; void 86.9 5.5; solid 85.9 5.0; void 86.4 5.0; solid 86.4 4.0; void 87.4 4.0;
   void 90 4.0; void 90 3.1; solid 90 2.8"
# X-Z 断面 (y=104.75、穴の中心): 窪みの床と 45°、埋めは x=0.25 まで、穴の中に埋めが残らない (void_rect)。
#    穴の縁は上端まで垂直 (z=27.9 でも x=0.25 / 40.55 で切り替わる)
check_section card hole-y 104.75 \
  "solid 21 2.8; void 21 3.1; solid 3.0 3.3; void 4.0 3.3; void 2.7 5.0; solid 2.1 5.0; void 3.7 4.0; solid 3.1 4.0;
   solid 39.9 5.0; void 39.3 5.0; solid -21 3; solid -20 20; solid -0.5 20; void 0.75 20; solid 41.2 20; void 40.0 20;
   void 21 30; solid 41.2 30; void_rect 0.3 40.5 6.0 27.9;
   solid -0.5 27.9; void 0.75 27.9; void 40.4 27.9; solid 40.7 27.9"
# Y-Z 断面 (x=0): ポケットの手前の縁 (11.2) は上端まで垂直 (z=27.9 でも 11.0 が無垢、11.3 が空)。
#    x=0 は穴の左の縁 (0.25) の縦エッジの弧 (中心 (-1.75, 99.8) R2) の中で、y=98.1 は床の上から上端まで
#    空 (弧の外)、y=99.1 は無垢 (弧の内)。縦エッジの丸めが全高で同じ断面であること
check_section_yz card wall-x0 0 \
  "solid 11.0 27.9; void 11.3 27.9; solid 11.0 26.5; void 11.3 26.5; solid 11.0 6.5; void 11.3 6.5;
   void 98.1 27.9; void 98.1 20; void 98.1 6.5; solid 98.1 5.5; solid 99.1 27.9; solid 99.1 20; solid 99.1 6.5;
   solid 110 27.9; solid 110 20; solid 5 27.9; solid 5 20"
# X-Z 断面 (y=54.45、ポケットの中): 左右の埋めの天面は 13.05 幅の平面 (z=27.9 で ∓27.7 が無垢、∓27.3 が空)。左右対称
check_section card label-strip 54.45 \
  "solid -27.7 27.9; solid -40.0 27.9; void -27.3 27.9; solid -27.7 26.5; void -27.3 26.5;
   solid 27.7 27.9; solid 40.0 27.9; void 27.3 27.9; solid 27.7 26.5; void 27.3 26.5"

if [ "$fail" -ne 0 ]; then
  echo "gridfinity-bin: FAILED" >&2
  exit 1
fi
echo "gridfinity-bin: ok"
