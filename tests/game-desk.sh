#!/bin/bash
# ゲーム用デスクのイヤホン・マイク置き (クランプ留め) のレンダリング検証。
# - openscad が exit 0 で非空の STL を生成すること
# - console に ERROR / WARNING が出ないこと
# - 設計契約 (CONTRACT echo) が台帳の確定値と一致すること
# - production STL の断面実測で取付界面・ポケット内寸・切り欠きを実形状として
#   固定すること (echo は自己申告なので形状で裏を取る)
# - STL が1連結成分であること (部品が分裂していないこと)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0
err() {
  echo "game-desk: $*" >&2
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

# expect_echo <name> <fragment> — CONTRACT echo の一致検査
expect_echo() {
  name=$1 fragment=$2
  grep -qF "$fragment" "$WORK/$name.log" \
    || err "$name: missing contract echo: $fragment"
}

# X-Z 断面の実測: production STL を指定 y で切り、輪郭の bbox と材料の
# 有無を測る。rotate([90,0,0]) で部品Y軸が切断面法線になり、2D X = 部品X、
# SVG の生 y = 部品Z (openscad の SVG は y 軸を反転して書く)。
# spec の節:
#   loop <cx> <cz> <span_x> <span_z> — 指定位置に指定 bbox の loop がある
#   outline <x1> <x2> <z1> <z2>     — 最大 loop (外形) の bbox
#   solid <x> <z> / void <x> <z>    — 指定点に材料が有る/無い
#   void_rect <x1> <x2> <z1> <z2>   — 矩形領域の内部が完全に空 (材料ゼロ)
# solid/void は全 loop を偶奇規則で数える内外判定なので、穴・窪み・切り欠きの
# 中は外側 (材料無し) になる。bbox では見えない「肉の抜け」を直接測る。
# void_rect は幾何交差で領域の空を測る: 全 loop の全辺と矩形の線分交差が0本
# (= 材料の境界が領域へ入って来ない) かつ、5点の偶奇判定がすべて外側
# (= 領域が材料に包含されていない) のときだけ空とみなす。点のサンプリングでは
# 「サンプルの隙間に薄膜が残る」退行 (貫通したはずの切り欠きの底や天端に
# 1mm 未満の膜) を見逃すため、貫通の連続性はこの交差判定で測る
check_section() {
  stl=$1 name=$2 cut_y=$3 spec=$4
  if ! python3 "$SCRIPT_DIR/stl_geometry.py" svg "$WORK/$stl.stl" y "$cut_y" "$WORK/sec_$name.svg" > /dev/null 2>&1; then
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
            print(f"section {name}: loop x=[{l[0]:.3f},{l[1]:.3f}] z=[{l[2]:.3f},{l[3]:.3f}]")
    elif kind == "outline":  # outline <x1> <x2> <z1> <z2>
        x1, x2, z1, z2 = map(float, args)
        body = max(map(bbox, loops), key=lambda l: (l[1] - l[0]) * (l[3] - l[2]))
        print(f"section {name}: outline x=[{body[0]:.3f},{body[1]:.3f}]"
              f" z=[{body[2]:.3f},{body[3]:.3f}]")
        if any(abs(a - b) > 0.05 for a, b in zip(body, (x1, x2, z1, z2))):
            print(f"section {name}: outline want x=[{x1},{x2}] z=[{z1},{z2}]")
            ok = False
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
        # (1) 材料の境界が領域内へ入ってくるか: 全 loop の全辺 × 矩形の交差。
        #     頂点が領域内にある場合もその頂点を端点とする辺が引っ掛かる
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

# 水平断面 (X-Y) の実測: 指定 z で切る。2D X = 部品X、生 y = -部品Y。
# spec の節:
#   loops <n>                  — loop の数
#   rect <x1> <x2> <y1> <y2>   — 最大 loop の bbox
#   loop <cx> <cy> <sx> <sy>   — 指定位置に指定 bbox の loop がある (穴の実測)
#   sharp <cx> <cy>            — 指定の角位置に頂点がある (直角のまま)
#   nosharp <cx> <cy>          — 指定の角位置の 0.5mm 以内に頂点が無い (R済み)
#   arc <cx> <cy> <r> <n>      — 中心(cx,cy)・半径 r の弧上に n 個以上の頂点
#   solid <cx> <cy> / void <cx> <cy> — 指定点に材料が有る/無い
#   void_rect <x1> <x2> <y1> <y2>    — 矩形領域の内部が完全に空 (材料ゼロ)
# sharp/nosharp/arc は全 loop の頂点を見る (外形の R2 も、ポケット内側の R4 も
# 同じ語彙で測るため)。「角の鋭点が無い」+「弧上に頂点が載る」の2条件で
# 垂直フィレットを実測する。
# solid/void は全 loop を偶奇規則で数える内外判定 (穴・切り欠きの中は材料無し)。
# void_rect は幾何交差で領域の空を測る: 全 loop の全辺と矩形の線分交差が0本
# (= 材料の境界が領域へ入って来ない) かつ、5点の偶奇判定がすべて外側
# (= 領域が材料に包含されていない) のときだけ空とみなす。点や格子の
# サンプリングでは「サンプルの隙間に薄壁が残る」退行を見逃すため、
# 空隙の連続性はこの交差判定で測る
check_plan() {
  stl=$1 name=$2 cut_z=$3 spec=$4
  if ! python3 "$SCRIPT_DIR/stl_geometry.py" svg "$WORK/$stl.stl" z "$cut_z" "$WORK/plan_$name.svg" > /dev/null 2>&1; then
    err "plan $name: failed to render"
    return
  fi
  python3 - "$WORK/plan_$name.svg" "$name" "$spec" <<'PYEOF' || fail=1
import math, re, sys
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


# 線分 pq が矩形の内部を正の長さで通るか (Liang-Barsky のクリッピング)。
# 矩形は境界を eps だけ内側へ縮めてあるので、切断面と重なるだけの辺
# (= 領域の縁そのもの) は交差扱いにならない
def seg_crosses(p, q, x1, x2, y1, y2):
    dx, dy = q[0] - p[0], q[1] - p[1]
    t0, t1 = 0.0, 1.0
    for den, num in ((-dx, p[0] - x1), (dx, x2 - p[0]),
                     (-dy, p[1] - y1), (dy, y2 - p[1])):
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


verts = [p for pts in loops for p in pts]
body = max(loops, key=lambda p: (bbox(p)[1] - bbox(p)[0]) * (bbox(p)[3] - bbox(p)[2]))
ok = True
for cond in spec.split(";"):
    kind, *args = cond.split()
    if kind == "loops":
        want = int(args[0])
        if len(loops) != want:
            print(f"plan {name}: {len(loops)} loops (want {want})")
            ok = False
    elif kind == "rect":  # rect <x1> <x2> <y1> <y2>
        x1, x2, y1, y2 = map(float, args)
        b = bbox(body)
        print(f"plan {name}: rect x=[{b[0]:.3f},{b[1]:.3f}]"
              f" y=[{b[2]:.3f},{b[3]:.3f}]")
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
            print(f"plan {name}: loop x=[{l[0]:.3f},{l[1]:.3f}] y=[{l[2]:.3f},{l[3]:.3f}]")
    elif kind in ("sharp", "nosharp"):  # <cx> <cy>
        cx, cy = map(float, args)
        near = min(math.dist(p, (cx, cy)) for p in verts)
        if kind == "sharp" and near > 0.05:
            print(f"plan {name}: no vertex at corner ({cx},{cy}); nearest {near:.3f}")
            ok = False
        elif kind == "nosharp" and near <= 0.5:
            print(f"plan {name}: sharp corner at ({cx},{cy}); nearest {near:.3f}")
            ok = False
        else:
            print(f"plan {name}: {kind} ({cx},{cy}) nearest vertex {near:.3f}")
    elif kind == "arc":  # arc <cx> <cy> <r> <n>
        cx, cy, r = map(float, args[:3])
        n = int(args[3])
        on = [p for p in verts if abs(math.dist(p, (cx, cy)) - r) < 0.05]
        print(f"plan {name}: arc ({cx},{cy}) r={r}: {len(on)} vertices on the arc")
        if len(on) < n:
            print(f"plan {name}: arc ({cx},{cy}) r={r} wants >= {n} vertices")
            ok = False
    elif kind in ("solid", "void"):  # <cx> <cy>
        cx, cy = map(float, args)
        got = inside(cx, cy)
        print(f"plan {name}: ({cx},{cy}) is {'solid' if got else 'void'}")
        if got != (kind == "solid"):
            print(f"plan {name}: want {kind} at ({cx},{cy})")
            ok = False
    elif kind == "void_rect":  # <x1> <x2> <y1> <y2>
        x1, x2, y1, y2 = map(float, args)
        # 領域の縁に載るだけの辺 (切断面そのもの) を交差扱いしないための許容。
        # STL/SVG の座標は有効6桁で書かれ実測で ~2e-5mm ずれるので、それを
        # 十分超え、かつ検出したい薄壁 (0.2mm 級) より桁違いに小さい 1e-3 を取る
        eps = 1e-3
        rect = (x1 + eps, x2 - eps, y1 + eps, y2 - eps)
        edges = [(pts[i], pts[(i + 1) % len(pts)])
                 for pts in loops for i in range(len(pts))]
        crossing = [e for e in edges if seg_crosses(e[0], e[1], *rect)]
        probes = [(rect[0], rect[2]), (rect[1], rect[2]), (rect[0], rect[3]),
                  (rect[1], rect[3]), ((x1 + x2) / 2, (y1 + y2) / 2)]
        filled = [p for p in probes if inside(*p)]
        print(f"plan {name}: void_rect x=[{x1},{x2}] y=[{y1},{y2}]:"
              f" {len(crossing)} crossing edges, {len(filled)}/5 probes solid")
        if crossing or filled:
            if crossing:
                print(f"plan {name}: material boundary enters the rect at"
                      f" {[tuple(round(v, 4) for v in e[0]) for e in crossing[:5]]}"
                      f"{' ...' if len(crossing) > 5 else ''}")
            if filled:
                print(f"plan {name}: material fills the rect at {filled[:5]}")
            ok = False
print(f"plan {name}: {'ok' if ok else 'FAIL'}")
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
      f" z=[{got[4]:.3f},{got[5]:.3f}]")
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

render holder assets/game-desk/earphone_mic_holder.scad

# ---------------------------------------------------------------------------
# 1. 取付界面: クランプ板 40×24 を覆う取付座に、M8 通し六角 (二面幅8.4・
#    対角9.70) と皿用の六角錐台が同心で開く。本体はクランプ当たり面 (y=0)
#    から -Y へ伸びる (デスクの奥側へ回した向き) ので、座は y -6..0 に在り、
#    皿ネジは外面 (y=-6) から入る。皿の逃げは直壁のボアではなく、
#    外面の二面幅16.0 から深さ4.5 で通し 8.4 へ直線的に絞る錐台にする
#    (断面がなだらかな三角形になり、皿がきれいに収まる)。
#    深さ d の二面幅は 16.0 - d * (16.0 - 8.4) / 4.5、対角はその 1/cos30。
#    y=-1.4 (錐台の底 y=-1.5 より内側) では通し六角だけが残る。
#    部品の上端はクランプ板の上端より 4.5 低い (天板と面一にするため) ので、
#    M8 の中心は部品座標で Z = 40 + 4.5 - 20 = 24.5 に上がる。旧値 20 は
#    superseded — 部品が板の上へ 4.5 はみ出す配置だった
# ---------------------------------------------------------------------------
check_section holder mount-pass1.4 -1.4 \
  "loop 0 24.5 9.70 8.40; void 0 24.5; solid 0 5"
# 錐台の3断面。直壁ボアなら d に依らず 16.0 のままなので red になる
check_section holder mount-bore0.5 -5.5 \
  "loop 0 24.5 17.500 15.156; void 0 24.5; solid 0 5"
check_section holder mount-bore2.25 -3.75 \
  "loop 0 24.5 14.087 12.200; void 0 24.5; solid 0 5"
check_section holder mount-bore4.0 -2.0 \
  "loop 0 24.5 10.675 9.244; void 0 24.5; solid 0 5"
# 取付座の板厚 6 (皿ボア4.5 + 残り肉1.5): 座は当たり面から y=-6 までで、
# その先 (y=-6.5) は両ポケットのブロックに挟まれた凹みになり材料が無い。
# 皿ネジの頭とドライバーはこの凹みから入る
check_plan holder mount-seat 38 "solid 0 -5.5; void 0 -6.5"

# ---------------------------------------------------------------------------
# 2. デスク側の段: クランプ板の厚み 4.2 は、中央 24.4 (板24 + クリアランス
#    0.4・片側0.2) の帯だけを逃がし、その外側の左右はデスク面 (y=4.2) まで
#    回り込ませる。左右が板厚の分だけ浮くのを止めるための段である。
# ---------------------------------------------------------------------------
# y=2 (逃げの中) の X-Z 断面: 中央の帯が全高 z 0..40 にわたって空で、その
# 直外側 (|x| = 13) には材料が在る。前後の反転が抜ければ帯に座の肉が現れ、
# 段が本体側を向けば y=2 に材料が無くなる — どちらでも red になる
check_section holder desk-step 2 \
  "outline 12.2 99.2 0 40;
   void_rect -12.2 12.2 0 40;
   solid -13 20; solid 13 20; solid -79 5; solid 98 5"
# z=38 の平面: 逃げの幅 24.4 と深さ 4.2 を4隅の頂点として実測する。逃げは
# opening の後に切るので角は直角のまま残る (板の角と合う)。
# solid 0 -3 は「当たり面 y=0 の裏 (-Y) に座が在る」= 前後反転の実測
check_plan holder desk-step 38 \
  "void_rect -12.2 12.2 0 4.2;
   sharp -12.2 0; sharp 12.2 0; sharp -12.2 4.2; sharp 12.2 4.2;
   solid -13 2; solid 13 2; solid 0 -3"

# ---------------------------------------------------------------------------
# 3. ポケット: 左 (イヤホン) 61.4×29.9×34深、右 (ピンマイク) 81.2×38.1×32深。
#    内側コーナーは R4。上端を Z40 の一平面へ揃えたので、深さを変えずに
#    床で吸収した (左6・右8)。本体は -Y 側なので Y の符号は負になる。
#    前後の定義: 前 = デスク接触面 (y=4.2) 側、後 = その反対側。ポケットは
#    前壁の内面 y=1.2 (デスク接触面から wall 3mm) を基準に並べる
# ---------------------------------------------------------------------------
# デスク側の壁厚。旧構成は「当たり面から +Y へ 4.2 の帯を足す」方式で、
# ポケットを y=0 基準に置いていたため前壁が 3 + 4.2 = 7.2mm もあった。
# 前壁も後壁も 3mm ちょうどであることを、材料の跨ぎで両ポケット分測る
check_plan holder wall-3mm 30 \
  "solid -45.7 4.1; solid -45.7 1.3; void -45.7 1.1; void -45.7 -28.6;
   solid -45.7 -28.8; solid -45.7 -31.6; void -45.7 -31.8;
   solid 55.6 4.1; solid 55.6 1.3; void 55.6 1.1; void 55.6 -36.8;
   void 55.6 -45.5; solid 55.6 -45.7; solid 55.6 -48.5; void 55.6 -48.7"
# z=30 (両ポケットの中・皿の錐台の帯 z 12..28 より上): 外形1本 + 左内寸1本 +
# 右内寸1本 = 3 loop。右の内寸 loop は凸断面なので bbox の Y は
# 38.1 + チャンネル 8.7 = 46.8。
# 水平断面を M8 の高さ (z=20) で取ると通し六角が取付座を左右に断ち切って
# 外形が2 loop に割れるため、ポケットの実測は穴帯の外で行う
check_plan holder pockets 30 \
  "loops 3;
   loop -45.7 -13.75 61.4 29.9;
   loop 55.6 -22.2 81.2 46.8;
   arc -72.4 -2.8 4 8; arc -19 -2.8 4 8; arc -72.4 -24.7 4 8; arc -19 -24.7 4 8;
   arc 19 -2.8 4 8; arc 92.2 -2.8 4 8; arc 19 -32.9 4 8; arc 92.2 -32.9 4 8;
   nosharp -76.4 1.2; nosharp -15 1.2; nosharp -76.4 -28.7; nosharp -15 -28.7;
   nosharp 15 1.2; nosharp 96.2 1.2; nosharp 15 -36.9; nosharp 96.2 -36.9"
# z=38 (両ポケットの天端の直下): 上端を Z40 の一平面へ揃えたので、ここでも
# 外形は全幅 178.6 × 奥行き 52.8 のまま残り、両ポケットの内寸 loop も在る。
# 旧構成 (右35 → 左37 → 座40 の段) なら、ここは幅24の座だけになって red
check_plan holder top-flush 38 \
  "loops 3; rect -79.4 99.2 -48.6 4.2;
   loop -45.7 -13.75 61.4 29.9; loop 55.6 -22.2 81.2 46.8"
# 右ポケットの凸チャンネル: ケースを差し込む向きを前後反対にしたので、
# チャンネルはデスク側ではなく反対側 (後) の壁を通る。cavity 背面
# (y=-36.9) から後壁の内面 (y=-45.6) までが全幅にわたって空で、その左右は
# 材料が残る。solid 55.6 2 はデスク側の前壁 3mm が塞がったままであること
# (= 反転が効いていること)、solid 55.6 -47 は後壁 3mm が残ること
check_plan holder mic-channel 30 \
  "void_rect 49.25 61.95 -45.6 -36.9;
   solid 49 -41; solid 62.2 -41; solid 30 -41; solid 80 -41;
   solid 55.6 -47; solid 55.6 2"
# z=1.5 (両方の床の中): 左は USB-C 長穴 14×8.5、右はチャンネルが床を貫通し、
# それ以外の床は受けとして残る (loop は外形 + 長穴 + チャンネルの3本)。
# 長穴は反転後の前壁内面 (y=1.2) から 7.5..16.0 = y -6.3..-14.8 に移る
check_plan holder floor 1.5 \
  "loops 3;
   loop -45.7 -10.55 14 8.5;
   void_rect 49.25 61.95 -45.6 -36.9;
   void -45.7 -7; void -45.7 -14;
   solid -45.7 0; solid -45.7 -20; solid 55.6 -30; solid 55.6 -1.5"
# y=-20 (両ポケットの内部を通る X-Z 断面): 左は外形 67.4×40 (床6+深さ34)、
# 右は外形 87.2×40 (床8+深さ32)。上端が一平面 Z40 に揃ったことと、床の
# 厚みが左6・右8 であることを、材料の有無の跨ぎで実測する。
# y=-20 を選ぶのは、左の長穴 (y -14.8..-6.3) も右のチャンネル
# (y -45.6..-36.9) も通らない帯だから — そこを切ると床が割れて U 字断面が
# 2 loop になる
check_section holder pockets-depth -20 \
  "loop -45.7 20 67.4 40; loop 55.6 20 87.2 40;
   solid -45.7 5.5; void -45.7 6.5; void -45.7 39;
   solid 55.6 7.5; void 55.6 8.5; void 55.6 39"
# y=-41 (右の凸チャンネルの帯): チャンネルは後壁の全高 (床の下端から天端
# まで) を貫通する。点で拾うと「底や天端に 1mm 未満の膜が残った」退行を
# 見逃すため、チャンネルの X 範囲 × 部品の全高 z 0..40 を void_rect の幾何
# 交差で測る (材料の境界がこの矩形へ1辺も入って来ないこと = 膜が無いこと)。
# 矩形の縁 (x=49.25/61.95 のチャンネル側壁、z=0 の底面、z=40 の天端) に
# 載るだけの辺は eps の内側縮めで交差扱いにならない。左右は材料
check_section holder mic-channel-height -41 \
  "void_rect 49.25 61.95 0 40;
   void 55.6 1; void 55.6 20; void 55.6 39;
   solid 48 20; solid 63 20; solid 48 1"

# ---------------------------------------------------------------------------
# 4. 補強ガセット: 取付座の外面 (y=-6) と両ポケットの側壁 (x=±12) が作る
#    凹角へ、脚 2mm の 45度 直角三角形を左右対称に足す。中央の座だけで
#    左右のポケットを繋いでいると、この凹角に応力が集まって折れる。
#    右のガセットは (12,-6)-(10,-6)-(12,-8)。斜辺は x + y = 4 の 45度 線で、
#    材料は x + y > 4 の側にある (左は x を反転した鏡像)。
#    ガセットは opening の後に union するので、角は R2 に丸まらない
# ---------------------------------------------------------------------------
# z=20 (M8 の通し六角 z 20.3..28.7 の下・皿錐台が座を断ち切らない高さ) の
# 平面。凹角 (±12,-6) が肉で埋まって頂点が消え、代わりに (±10,-6) と
# (±12,-8) が新しい鋭角の頂点になる。斜辺の内側は材料・外側は空
check_plan holder gusset 20 \
  "sharp 10 -6; sharp 12 -8; sharp -10 -6; sharp -12 -8;
   nosharp 12 -6; nosharp -12 -6;
   solid 11.3 -6.3; solid -11.3 -6.3;
   void 10.5 -7.5; void -10.5 -7.5"
# y=-7 / y=-7.5 の X-Z 断面: 座 (y -6..0) より外なので、本来は左右のポケットの
# ブロックだけが残る帯である。ガセットが 45度 で張り出すぶん、右ブロックの
# 内側の縁が x=12 から 11 (y=-7)・11.5 (y=-7.5) へ寄る。0.5 下がると 0.5
# 寄るのが 45度 の実測で、ガセットが無ければどちらも 12 のままで red。
# ガセットは全高の押し出しなので、ブロックは z 0..40 に伸びる。
# 左ブロックの bbox は測らない — この帯は USB-C 長穴 (y -14.8..-6.3) の
# 中なので、左は床が抜けて 2 loop に割れる。左は材料の跨ぎで測る
check_section holder gusset -7 \
  "loop 55.1 20 88.2 40;
   solid 11.5 20; solid -11.5 20; void 10.5 20; void -10.5 20"
check_section holder gusset-deep -7.5 \
  "loop 55.35 20 87.7 40;
   solid 11.8 20; solid -11.8 20; void 11.2 20; void -11.2 20"

# ---------------------------------------------------------------------------
# 5. 形状健全性: 外形 bbox、外側垂直エッジの R2、単一連結成分。
#    デスク接触面 (底面) の水平エッジは未加工 (R2 は垂直エッジだけ)。
#    ガセットは凹角の中に収まるので bbox は変わらない
# ---------------------------------------------------------------------------
check_bbox holder -79.4 99.2 -48.6 4.2 0 40
check_plan holder outer-round 30 \
  "nosharp -79.4 -31.7; nosharp 99.2 -48.6; nosharp -79.4 4.2; nosharp 99.2 4.2;
   arc -77.4 -29.7 2 8; arc 97.2 -46.6 2 8;
   arc -77.4 2.2 2 8; arc 97.2 2.2 2 8"
check_single_solid holder

# 設計契約 (台帳 designs/game-desk-clamp-holder.md の確定値)
expect_echo holder 'CONTRACT earphone_mic_holder'
expect_echo holder 'CONTRACT earphone_mic_holder: clamp_plate = [24, 4.2, 40]'
expect_echo holder 'CONTRACT earphone_mic_holder: mount_seat = [24, 6, 40]'
expect_echo holder 'CONTRACT earphone_mic_holder: m8_pass_flat = 8.4'
expect_echo holder 'CONTRACT earphone_mic_holder: m8_head_flat = 16'
expect_echo holder 'CONTRACT earphone_mic_holder: m8_head_depth = 4.5'
# 皿の逃げは直壁ではなく、外面16.0 → 深さ4.5 で通し8.4 へ絞る六角錐台
expect_echo holder 'CONTRACT earphone_mic_holder: m8_head_taper = [16, 8.4, 4.5]'
# 部品の上端はクランプ板の上端より 4.5 低い。部品の datum (底面 Z=0) は
# 動かさないので、この 4.5 は M8 中心の Z が 20 → 24.5 へ上がる形で現れる
expect_echo holder 'CONTRACT earphone_mic_holder: top_drop = 4.5'
expect_echo holder 'CONTRACT earphone_mic_holder: m8_center = [0, 24.5]'
# 皿込み全長8.6 - 座の厚み6 = 2.6mm がクランプ板 (4.2) の M8 メスへ掛かる
expect_echo holder 'CONTRACT earphone_mic_holder: screw_engagement = 2.6'
expect_echo holder 'CONTRACT earphone_mic_holder: clearance = 0.4'
expect_echo holder 'CONTRACT earphone_mic_holder: ear_inner = [61.4, 29.9, 34]'
expect_echo holder 'CONTRACT earphone_mic_holder: mic_inner = [81.2, 38.1, 32]'
expect_echo holder 'CONTRACT earphone_mic_holder: mic_channel = [12.7, 8.7]'
expect_echo holder 'CONTRACT earphone_mic_holder: usb_slot = [14, 8.5]'
# 前 = デスク接触面側。長穴はその前壁の内面から 7.5..16.0 に置く
expect_echo holder 'CONTRACT earphone_mic_holder: usb_slot_from_front = [7.5, 16]'
# 両ポケットの前壁内面 = デスク接触面 4.2 から wall 3 だけ内側
expect_echo holder 'CONTRACT earphone_mic_holder: front_inner_y = 1.2'
expect_echo holder 'CONTRACT earphone_mic_holder: wall = 3'
# 上端を Z40 の一平面へ揃えるため、床厚は左 (イヤホン) 6・右 (マイク) 8
expect_echo holder 'CONTRACT earphone_mic_holder: floor_t = [6, 8]'
# デスク側の段: 逃げの幅 24.4 (板24 + クリアランス0.4) × 板厚 4.2
expect_echo holder 'CONTRACT earphone_mic_holder: desk_step = [24.4, 4.2]'
# 外形の奥行きは bbox の Y 幅 (4.2 - (-48.6)) と一致すること。デスク側の段は
# ポケットの外形に含まれるので、旧構成の 52.8 + 4.2 = 57 は superseded
expect_echo holder 'CONTRACT earphone_mic_holder: outer = [178.6, 52.8, 40]'
expect_echo holder 'CONTRACT earphone_mic_holder: pocket_r = 4'
expect_echo holder 'CONTRACT earphone_mic_holder: corner_r = 2'
# 取付座とポケット側壁の凹角を埋める 45度 三角の脚長
expect_echo holder 'CONTRACT earphone_mic_holder: gusset = 2'

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "game-desk tests passed"
