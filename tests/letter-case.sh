#!/bin/bash
# レターケース用 Gridfinity ベースプレート (前後2分割) のレンダリング検証。
# - openscad が exit 0 で非空の STL を生成し、console に ERROR / WARNING が無いこと
# - 設計契約 (CONTRACT echo) が台帳の確定値と一致すること
# - production STL の断面実測で、板の外形 (引き出し内寸 − クリアランス)・
#   ソケットの配置 (42mm ピッチ)・ソケット輪郭 (公称 41.5 / 37.2 / 35.8 の3段 + 逃げ 0.1)・
#   縁の X 筋交い窓を実形状として固定すること (echo は自己申告なので形状で裏を取る)
# - 2枚を前後に突き合わせたとき、継ぎ目を跨いでも 42mm ピッチが保たれること
# - 各 STL が1連結成分であること
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0
err() {
  echo "letter-case: $*" >&2
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
#   arc <cx> <cy> <r> <x1> <x2> <y1> <y2> — 矩形 [x1,x2]×[y1,y2] に入る外形の頂点が
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
    elif kind == "arc":  # <cx> <cy> <r> <x1> <x2> <y1> <y2>
        cx, cy, r, x1, x2, y1, y2 = map(float, args)
        pts = [p for p in body if x1 <= p[0] <= x2 and y1 <= p[1] <= y2]
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

# 閉曲面・非縮退・単一連結を共有STL検査で確認する。
check_single_solid() {
  PYTHONPATH="$SCRIPT_DIR" python3 - "$WORK/$1.stl" <<'PYEOF' || fail=1
from pathlib import Path
import sys
from stl_geometry import closed_mesh
closed_mesh(Path(sys.argv[1]))
print("closed single solid:", sys.argv[1])
PYEOF
}


render front assets/letter-case/iris-oyama-a4-lcj/baseplate_front.scad
render rear assets/letter-case/iris-oyama-a4-lcj/baseplate_rear.scad

# 外形・奥行き方向の分割は既存の合わせ込み値を維持する。
# セル幅231mmを中央に置き、左半セル21mm＋標準5列、左右の無垢縁4.8mm。
CONTRACT="CONTRACT plate=240.6x313.5 grid=5.5x7 pitch=42 socket=41.5/37.2/35.8 fit=0.1 depth=4.65 floor=0 rim=L4.8/R4.8/F1.5/B18 xwin=2 corner=6"
expect_echo front "$CONTRACT split=front rows=4 len=169.5"
expect_echo rear "$CONTRACT split=rear rows=3 len=144"
check_bbox front -120.3 120.3 0 169.5 0 4.65
check_bbox rear -120.3 120.3 0 144 0 4.65
check_single_solid front
check_single_solid rear

# 標準列は42mmピッチ。前片最終行148.5と奥片先頭21+169.5=190.5の差も42。
# 前片は外形1＋24ソケット、奥片は外形1＋18ソケット＋奥6窓×4三角。
check_plan front cells 4.0 \
  "loops 25; rect -120.3 120.3 0 169.5; grid -73.5 42 5 22.5 42 4 40.4;
   loop -105 22.5 19.4 40.4; loop -105 148.5 19.4 40.4;
   solid -94.5 22.5; solid 115.5 22.5; solid 0 1; solid -52.5 64.5; solid 0 169.1"
check_plan rear cells 4.0 \
  "loops 43; rect -120.3 120.3 0 144; grid -73.5 42 5 21 42 3 40.4;
   loop -105 21 19.4 40.4; loop -105 105 19.4 40.4;
   solid -94.5 63; solid 115.5 63; solid 10.5 135; solid 0 143; solid -52.5 63"

# 全7個の半セル: 幅21mm、段差・角Rは標準と同じ。X方向の単純scaleを拒否する。
PYTHONPATH="$SCRIPT_DIR" python3 - "$WORK" <<'PYEOF' || fail=1
from pathlib import Path
import math, sys
from stl_geometry import loop_at, section
work = Path(sys.argv[1])
for name, centers in [("front", [22.5, 64.5, 106.5, 148.5]), ("rear", [21, 63, 105])]:
    for z, span, radius in [(0.35, 36.7, 1.6), (1.6, 37.4, 1.95), (4, 40.4, 3.45), (4.64, 41.7, 4.1)]:
        loops = section(work / (name + ".stl"), work, "z", z)
        for y in centers:
            width = span - 21
            loop = loop_at(loops, (-105 - width / 2, -105 + width / 2, y - span / 2, y + span / 2))
            center = (-105 + width / 2 - radius, y + span / 2 - radius)
            arc = [p for p in loop if p[0] > center[0] + 0.05 and p[1] > center[1] + 0.05]
            assert len(arc) >= 5 and all(abs(math.dist(p, center) - radius) < 0.03 for p in arc), (name, y, z, "half-cell radius")
print("half cells: 21mm pitch, all profiles and corner radii passed")
PYEOF
check_plan front wall 1.6 "loops 25; loop -73.5 22.5 37.4 37.4; loop 10.5 106.5 37.4 37.4"
check_plan front chamfer-bottom 0.35 "loops 25; loop -73.5 22.5 36.7 36.7; loop 94.5 148.5 36.7 36.7"
check_plan rear wall 1.6 "loops 43; loop 94.5 105 37.4 37.4"
check_plan rear chamfer-bottom 0.35 "loops 43; loop 10.5 21 36.7 36.7"

# 全42ソケットが底から天面まで空で、左右4.8mmの縁は全高で連続する。
ALL_CELLS="void_rect -112.4 -97.6 0.05 4.6; void_rect -91 -56 0.05 4.6;
   void_rect -49 -14 0.05 4.6; void_rect -7 28 0.05 4.6;
   void_rect 35 70 0.05 4.6; void_rect 77 112 0.05 4.6"
for y in 22.5 64.5 106.5 148.5; do
  check_section front "row-y$y" "$y" "$ALL_CELLS; solid -94.5 2.5; solid 73.5 2.5; solid -117 2; solid 117 2; solid -119.8 4.5"
done
for y in 21 63 105; do
  check_section rear "row-y$y" "$y" "$ALL_CELLS; solid -94.5 2.5; solid 73.5 2.5; solid -117 2; solid 117 2; solid 119.8 4.5"
done
check_section front front-rim 1 "solid 0 3; solid -119.8 3; solid 119.8 3; void 0 4.7"
check_section rear rear-band 126.5 "solid 0 3; solid -112 3; solid 112 3; solid -119.8 3; void 0 4.7"

# 奥のX窓は左半セル19×14、標準列40×14が5個。線幅2mmを維持する。
check_plan rear xwin 4.0 \
  "loops 43;
   winbox -105 135 19 14; winbox -73.5 135 40 14; winbox -31.5 135 40 14;
   winbox 10.5 135 40 14; winbox 52.5 135 40 14; winbox 94.5 135 40 14;
   solid -105 135; solid 10.5 135; solid -94.5 135; solid 0 143; solid 0 127;
   void -105 139.7; void -105 130.3; void 10.5 139.7; void 10.5 130.3;
   solid 17.79 138.40; solid 18.31 136.88; void 17.65 138.77; void 18.45 136.51"

# 床や肉抜きの退行を従来の体積上限でも検査する。
check_volume() {
  name=$1 max=$2
  python3 - "$WORK/$name.stl" "$name" "$max" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name, vmax = sys.argv[2], float(sys.argv[3])
vs = [tuple(map(float, v)) for v in re.findall(r'vertex\s+(\S+)\s+(\S+)\s+(\S+)', src)]
V = sum((a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
         + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
        for a, b, c in zip(vs[0::3], vs[1::3], vs[2::3])) / 1000
print(f"volume {name}: {abs(V):.1f} cm3 (max {vmax})")
sys.exit(0 if abs(V) <= vmax else 1)
PYEOF
}
check_volume front 47
check_volume rear 43

# ---------------------------------------------------------------------------
# 6. 奥片の奥側 2 隅は R6 (引き出しの内角の丸みに合わせる)。角の点 (120.3, 144)
#    から 1 内側の (119.3, 143) は円の中心 (114.3, 138) から 7.07 なので void、
#    (119.3, 140.5) は 5.59 なので solid。半径そのものは、隅の領域
#    x∈[114.8,121] y∈[138.2,145] に入る外形の頂点 (円弧の内部の頂点だけ。直線部の
#    頂点は領域の外) が全部 (±114.3, 138) から 6 の距離にあることで固定する。
#    前片の 4 隅と奥片の前側 2 隅は直角のまま
# ---------------------------------------------------------------------------
check_plan rear corners 2.0 \
  "void 119.3 143; void -119.3 143; solid 119.3 140.5; solid -119.3 140.5; solid 114.3 143.5;
   arc 114.3 138 6 114.8 121 138.2 145; arc -114.3 138 6 -121 -114.8 138.2 145;
   solid 119.8 0.5; solid -119.8 0.5"
check_plan front corners 2.0 "solid 119.8 0.5; solid -119.8 0.5; solid 119.8 169; solid -119.8 169"

# ---------------------------------------------------------------------------
# 7. 共有 module の既定値。letter-case はクリアランス 0.1 を渡すが、
#    gf_baseplate の既定 (clearance=0) は Gridfinity の公称輪郭 41.5/37.2/35.8
#    のままであること (他 project が使うときの契約)。1 マスの板を WORK で描く。
#    既定の床 floor_t=1 があるので、切断高さは letter-case より 1 高い
# ---------------------------------------------------------------------------
printf 'use <%s/modules/gridfinity.scad>\ngf_baseplate(1, 1);\n' "$ROOT" > "$WORK/nominal.scad"
if openscad -o "$WORK/nominal.stl" "$WORK/nominal.scad" > "$WORK/nominal.log" 2>&1; then
  check_plan nominal cells 5.0 "loops 2; loop 0 21 40.2 40.2"
  check_plan nominal wall 2.6 "loops 2; loop 0 21 37.2 37.2"
  check_plan nominal chamfer-bottom 1.35 "loops 2; loop 0 21 36.5 36.5"
else
  err "nominal: openscad failed"
  cat "$WORK/nominal.log" >&2
fi

if [ "$fail" -ne 0 ]; then
  echo "letter-case: FAILED" >&2
  exit 1
fi
echo "letter-case: ok"
