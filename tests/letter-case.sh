#!/bin/bash
# レターケース用 Gridfinity ベースプレート (前後2分割) のレンダリング検証。
# - openscad が exit 0 で非空の STL を生成し、console に ERROR / WARNING が無いこと
# - 設計契約 (CONTRACT echo) が台帳の確定値と一致すること
# - production STL の断面実測で、板の外形 (引き出し内寸 − クリアランス)・
#   ソケットの配置 (42mm ピッチ)・ソケット輪郭 (41.5 / 37.2 / 35.8 の3段)・
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

# check_single_solid <name> — STL の三角形を頂点の共有で繋いで連結成分を数える。
# 単一プリント部品なので 1 でなければならない (2以上 = 宙に浮いた島がある)
check_single_solid() {
  name=$1
  python3 - "$WORK/$name.stl" "$name" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name = sys.argv[2]
vs = [(round(float(a), 4), round(float(b), 4), round(float(c), 4))
      for a, b, c in re.findall(r'vertex\s+(\S+)\s+(\S+)\s+(\S+)', src)]
parent = {}


def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]
        a = parent[a]
    return a


def union(a, b):
    ra, rb = find(a), find(b)
    if ra != rb:
        parent[ra] = rb


for v in vs:
    parent.setdefault(v, v)
for i in range(0, len(vs), 3):  # facet ごとに3頂点を繋ぐ
    union(vs[i], vs[i + 1])
    union(vs[i + 1], vs[i + 2])
n = len({find(v) for v in parent})
print(f"solids {name}: {n} connected component(s) from {len(vs) // 3} facets")
sys.exit(0 if n == 1 else 1)
PYEOF
}


render front assets/letter-case/baseplate_front.scad
render rear assets/letter-case/baseplate_rear.scad

# ---------------------------------------------------------------------------
# 0. 設計契約。引き出し内寸 240x318 からクリアランス 1 を片側ずつ引いた
#    238x316 の板に、実プリントの合わせ込み (左右 +1.5 ずつ、手前 −1.5) を
#    足した 241x314.5 の板に 5x7 のソケットを置く。横は 5x42=210 を中央へ置いて
#    左右 15.5 が縁になる。奥行きは高い床 (318-14=304) の中央へ 7x42=294 を
#    置くので、前 4−1.5=2.5 / 奥 18 (= くぼみ 14 + 余り 5 − クリアランス 1) が
#    縁になる。前 4 行 + 奥 3 行に分割し、前片は奥行き 2.5+168=170.5、奥片は
#    126+18=144。奥片の奥側 2 隅は R6
# ---------------------------------------------------------------------------
CONTRACT="CONTRACT plate=241x314.5 grid=5x7 pitch=42 socket=41.5/37.2/35.8 depth=4.65 floor=0 rim=L15.5/R15.5/F2.5/B18 xwin=2 corner=6"
expect_echo front "$CONTRACT split=front rows=4 len=170.5"
expect_echo rear "$CONTRACT split=rear rows=3 len=144"

# 外形。X は中央が 0、Y は各片の前端が 0、Z=0 が底面。床は無いので高さはソケットの 4.65
check_bbox front -120.5 120.5 0 170.5 0 4.65
check_bbox rear -120.5 120.5 0 144 0 4.65
check_single_solid front
check_single_solid rear

# ---------------------------------------------------------------------------
# 1. ソケットの配置 (42mm ピッチ)。上の面取り (Z 2.5..4.65) の中の z=4.0 で
#    切ると、各ソケットは 41.5 − 2×0.65 = 40.2 角の loop になる。縁の窓も
#    同じ断面に loop として出る (数は 4. で数える) ので、grid 節は 40.2 角の
#    loop だけを拾い、20 / 15 個すべての中心を集合として固定する。
#    列の中心は x = -84,-42,0,42,84。前片の行の中心は y = 23.5,65.5,107.5,149.5、
#    奥片は y = 21,63,105 で、前片の全長 170.5 を足すと 191.5,233.5,275.5 になり
#    149.5 + 42 = 191.5 で継ぎ目を跨いでも 42mm ピッチである
# ---------------------------------------------------------------------------
check_plan front cells 4.0 \
  "rect -120.5 120.5 0 170.5; grid -84 42 5 23.5 42 4 40.2;
   loop -84 23.5 40.2 40.2; loop 84 23.5 40.2 40.2; loop 0 107.5 40.2 40.2;
   loop -84 149.5 40.2 40.2; loop 84 149.5 40.2 40.2;
   void 0 23.5; solid -105 23.5; solid 105 23.5; solid 0 1; solid -63 65.5; solid 0 170.1"
check_plan rear cells 4.0 \
  "rect -120.5 120.5 0 144; grid -84 42 5 21 42 3 40.2;
   loop -84 21 40.2 40.2; loop 84 21 40.2 40.2; loop 0 63 40.2 40.2;
   loop -84 105 40.2 40.2; loop 84 105 40.2 40.2;
   void 0 21; solid -105 63; solid 105 63; solid 0 135; solid 0 143; solid -63 63"

# ---------------------------------------------------------------------------
# 2. ソケット輪郭の3段 (底から 0.7 面取り / 1.8 垂直 / 2.15 面取り)。
#    垂直部 (Z 0.7..2.5) の z=1.6 で切ると 37.2 角、下の面取り (Z 0..0.7) の
#    z=0.35 で切ると 35.8 + 2×0.35 = 36.5 角になる
# ---------------------------------------------------------------------------
#    縁の窓は貫通なので、どの高さの断面でも loop 総数は z=4.0 と同じ
#    (前片 53、奥片 60。内訳は 4. を参照)。総数を固定して全ソケットの存在を測る
check_plan front wall 1.6 "loops 53; loop -84 23.5 37.2 37.2; loop 0 107.5 37.2 37.2"
check_plan front chamfer-bottom 0.35 "loops 53; loop -84 23.5 36.5 36.5; loop 84 149.5 36.5 36.5"
check_plan rear wall 1.6 "loops 60; loop 84 105 37.2 37.2"
check_plan rear chamfer-bottom 0.35 "loops 60; loop 0 21 36.5 36.5"

# ---------------------------------------------------------------------------
# 3. 縦断面 (X-Z) で、ソケットが底 (z=0) から天面まで抜けていること (床が無い)、
#    ソケット際の枠 (|x| = 105..107) と外周の枠 (118.5..120.5) が全高で
#    詰まっていること。ソケットの穴は z=0 で 35.8 角 (半幅 17.9) なので、
#    半幅 17.5 の矩形 x∈[-101.5,-66.5] z∈[0.05,4.6] は完全に空でなければならない。
#    床を混入させると z=0.05 の probe が材料になって red
# ---------------------------------------------------------------------------
# 全 7 行 × 5 列のソケットを、行ごとの縦断面で 1 個ずつ void_rect にする。
# 局所的な床の混入 (1 個のソケットの下だけ薄い膜) は体積の上限に掛からないので、
# ここで全数を測る
ALL_CELLS="void_rect -101.5 -66.5 0.05 4.6; void_rect -59.5 -24.5 0.05 4.6;
   void_rect -17.5 17.5 0.05 4.6; void_rect 24.5 59.5 0.05 4.6; void_rect 66.5 101.5 0.05 4.6"
for y in 23.5 65.5 107.5 149.5; do
  check_section front "row-y$y" "$y" "$ALL_CELLS; solid -63 2.5; solid 63 2.5; solid -106 2; solid 106 2"
done
for y in 21 63 105; do
  check_section rear "row-y$y" "$y" "$ALL_CELLS; solid -63 2.5; solid 63 2.5; solid -106 2; solid 106 2"
done
# 縁の枠 (ソケット際 105..107、外周 118.5..120.5) が全高で詰まっていること
check_section front row1 23.5 \
  "void -84 0.2; void 0 0.2; solid -119.5 2; solid 119.5 2; solid -120 4.5; void -84 3"
check_section rear row3 105 "void 84 0.2; solid 119.5 2; solid -119.5 2; void 84 3"
# 前縁 (2.5) は全幅で詰まった板
check_section front front-rim 1 "solid 0 3; solid -120 3; solid 120 3; void 0 4.7"
# 奥片の、左右の窓と奥の窓の間の無垢の帯 (y 125..128)
check_section rear rear-band 126.5 "solid 0 3; solid -112 3; solid 112 3; solid -120 3; void 0 4.7"

# ---------------------------------------------------------------------------
# 4. 縁の X 筋交い窓。z=4.0 の断面で数える。左右の縁 (15.5) には bin の境目
#    (42mm ピッチ) に沿って、幅 11.5 (枠 2 を外周とソケット際に残す)・長さ 40
#    (境目に 2mm のリブ) の窓を行ごとに開け、窓の対角に幅 2 の X を渡す。
#    窓の中心は x = ±112.75。各片の端 (継ぎ目・前縁側) は 2mm 残すので
#    継ぎ目側の端の窓は 39 になる。
#    前片の左右: y = [3.5,43.5] [45.5,85.5] [87.5,127.5] [129.5,168.5]、
#    奥片: [2,41] [43,83] [85,125]。
#    奥の縁 (18) には列ごとに 40×14 の窓 (x = 中心 ±20、y = [128,142])。
#    X は窓を 4 つの三角に割るので、窓 1 つが loop 4 本になる:
#    前片 1 + 20 + 8窓×4 = 53、奥片 1 + 15 + 6窓×4 + 5窓×4 = 60。
#    三角の重心 (端の三角は中心から長辺の 2/3 = 13.3、脇の三角は短辺の
#    2/3 = 3.83) が void、X の交点・リブ・枠が solid。
#    窓の実寸は winbox で測る (4 つの三角の union bbox = 窓の矩形)。
#    筋交いの幅 2 は、窓の中心から対角に沿って 8 進んだ点を法線方向へ
#    ±0.8 ずらすと solid、±1.2 ずらすと void になることで測る (もう 1 本の
#    筋交いの中心線はそこから 2.7mm 以上離れていて、半幅 1 の外にある)。
#    左右の窓 11.5×40 の対角の向きは (0.276, 0.961)、法線は (0.961, -0.276)。
#    奥の窓 40×14 は (0.944, 0.330) と (-0.330, 0.944)
#    (-0.330, 0.944)
# ---------------------------------------------------------------------------
check_plan front xwin 4.0 \
  "loops 53;
   void -112.75 36.8; void -112.75 10.2; void -116.58 23.5; void -108.92 23.5;
   void 112.75 36.8; void 112.75 162; void 112.75 136; void -112.75 162;
   solid -112.75 23.5; solid 112.75 149; solid -112.75 44.5; solid -112.75 3; solid -112.75 169.5;
   solid -106 23.5; solid -119.5 23.5; solid 106 65.5; solid 119.5 65.5;
   winbox -112.75 23.5 11.5 40; winbox 112.75 65.5 11.5 40; winbox -112.75 149 11.5 39; winbox 112.75 149 11.5 39;
   solid -109.77 30.97; solid -111.31 31.41; void -109.39 30.86; void -111.69 31.52"
check_plan rear xwin 4.0 \
  "loops 60;
   void -112.75 15.3; void -112.75 111; void 112.75 70; void -116.58 21; void 108.92 21;
   solid -112.75 21; solid -112.75 42; solid -112.75 1; solid -112.75 125.5;
   void 13.3 135; void -13.3 135; void 0 139.7; void 0 130.3; void 84 139.7; void -84 130.3;
   solid 0 135; solid 21 135; solid -21 135; solid 0 143; solid 0 127; solid -112.75 135; solid 112.75 135;
   winbox -112.75 21.5 11.5 39; winbox 112.75 63 11.5 40; winbox -112.75 105 11.5 40;
   winbox 0 135 40 14; winbox 84 135 40 14; winbox -84 135 40 14;
   solid 7.29 138.40; solid 7.81 136.88; void 7.15 138.77; void 7.95 136.51"

# ---------------------------------------------------------------------------
# 5. 材料。STL の体積 (facet の符号付き体積の和) が、床 0 化と縁の肉抜きの目標
#    (床 1 で 96.6 / 92.6 cm³ → 床 0 で 55.6 / 58.3 → ハニカムで 49.1 / 46.6
#    → X 窓) を下回ること。床の混入や窓の消失は体積で red になる
# ---------------------------------------------------------------------------
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
check_volume front 46
check_volume rear 43

# ---------------------------------------------------------------------------
# 6. 奥片の奥側 2 隅は R6 (引き出しの内角の丸みに合わせる)。角の点 (120.5, 144)
#    から 1 内側の (119.5, 143) は円の中心 (114.5, 138) から 7.07 なので void、
#    (119.5, 140.5) は 5.59 なので solid。半径そのものは、隅の領域
#    x∈[115,121] y∈[138.2,145] に入る外形の頂点 (円弧の内部の頂点だけ。直線部の
#    頂点は領域の外) が全部 (±114.5, 138) から 6 の距離にあることで固定する。
#    前片の 4 隅と奥片の前側 2 隅は直角のまま
# ---------------------------------------------------------------------------
check_plan rear corners 2.0 \
  "void 119.5 143; void -119.5 143; solid 119.5 140.5; solid -119.5 140.5; solid 114.5 143.5;
   arc 114.5 138 6 115 121 138.2 145; arc -114.5 138 6 -121 -115 138.2 145;
   solid 120 0.5; solid -120 0.5"
check_plan front corners 2.0 "solid 120 0.5; solid -120 0.5; solid 120 170; solid -120 170"

if [ "$fail" -ne 0 ]; then
  echo "letter-case: FAILED" >&2
  exit 1
fi
echo "letter-case: ok"
