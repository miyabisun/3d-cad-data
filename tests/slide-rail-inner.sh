#!/bin/bash
# スライドレール内側のケース支持部品 (対称型・奥用L/R) のレンダリング検証。
# - openscad が exit 0 で非空の STL を生成すること
# - console に ERROR / WARNING が出ないこと
# - 設計契約 (CONTRACT echo) が台帳の確定値と一致すること
# - production STL の断面実測で穴位置・スタンドオフの偏心・左右の鏡像性を
#   実形状として固定すること (echo は自己申告なので形状で裏を取る)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0
err() {
  echo "slide-rail-inner: $*" >&2
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

render support assets/steel-rack/500x400/slide_rail_inner_support.scad
render rear_l assets/steel-rack/500x400/slide_rail_inner_rear_l.scad
render rear_r assets/steel-rack/500x400/slide_rail_inner_rear_r.scad

# X-Z 断面の実測: production STL を指定 y で切り、六角穴の bbox・中心と
# 外形の範囲を測る。rotate([90,0,0]) で部品Y軸が切断面法線になり、
# 2D X = 部品X、SVG の生 y = 部品Z (openscad の SVG は y 軸を反転して書く)。
# spec の節:
#   hex <cx> <cz> <span_x> <span_z> — 指定位置に指定 bbox の loop がある
#   outline <x1> <x2> <z1> <z2>     — 最大 loop (外形) の bbox
#   solid <x> <z> / void <x> <z>    — 指定点に材料が有る/無い
# solid/void は全 loop を偶奇規則で数える内外判定なので、穴・窪み・切り欠きの
# 中は外側 (材料無し) になる。bbox では見えない「肉の抜け」を直接測る
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


ok = True
for cond in spec.split(";"):
    kind, *args = cond.split()
    if kind == "hex":  # hex <cx> <cz> <span_x> <span_z>
        cx, cz, sx, sz = map(float, args)
        hit = [l for l in map(bbox, loops)
               if abs((l[0] + l[1]) / 2 - cx) < 0.1 and abs((l[2] + l[3]) / 2 - cz) < 0.1
               and abs((l[1] - l[0]) - sx) < 0.05 and abs((l[3] - l[2]) - sz) < 0.05]
        if not hit:
            print(f"section {name}: missing hex ({cx},{cz}) span ({sx},{sz})")
            ok = False
        else:
            l = hit[0]
            print(f"section {name}: hex x=[{l[0]:.3f},{l[1]:.3f}] z=[{l[2]:.3f},{l[3]:.3f}]")
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
print(f"section {name}: {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PYEOF
}

# 水平断面 (X-Y) の実測: 指定 z で切る。2D X = 部品X、生 y = -部品Y。
# spec の節:
#   loops <n>                  — loop の数 (柱だけの帯に材料が1本だけ)
#   rect <x1> <x2> <y1> <y2>   — 最大 loop の bbox
#   sharp <cx> <cy>            — 指定の角位置に頂点がある (直角のまま)
#   nosharp <cx> <cy>          — 指定の角位置の 0.5mm 以内に頂点が無い (R済み)
#   arc <cx> <cy> <r> <n>      — 中心(cx,cy)・半径 r の弧上に n 個以上の頂点
#   solid <cx> <cy> / void <cx> <cy> — 指定点に材料が有る/無い
#   void_rect <x1> <x2> <y1> <y2>    — 矩形領域の内部が完全に空 (材料ゼロ)
# sharp/nosharp/arc は最大 loop (外形) の頂点だけを見る。
# 「角の鋭点が無い」+「弧上に頂点が載る」の2条件で垂直フィレットを実測する。
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
    elif kind in ("sharp", "nosharp"):  # <cx> <cy>
        cx, cy = map(float, args)
        near = min(math.dist(p, (cx, cy)) for p in body)
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
        on = [p for p in body if abs(math.dist(p, (cx, cy)) - r) < 0.05]
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
        # (1) 材料の境界が領域内へ入ってくるか: 全 loop の全辺 × 矩形の交差。
        #     頂点が領域内にある場合もその頂点を端点とする辺が引っ掛かる
        edges = [(pts[i], pts[(i + 1) % len(pts)])
                 for pts in loops for i in range(len(pts))]
        crossing = [e for e in edges if seg_crosses(e[0], e[1], *rect)]
        # (2) 辺が1本も入らないなら領域は「全部材料」か「全部空」のどちらか。
        #     偶奇判定 (4隅 + 中心) で materialに包含されている側を弾く
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

# 外形: ブロック 42×10×14 (X ∈ [-21,21]・Y ∈ [0,10]・Z ∈ [0,14]) に
# 24×24 の柱が Z=34 まで伸び、Y は柱の後端 26 まで張り出す。
# 奥用は柱の偏心 ±21 (柱の半分12) で X 側にも 33 まで張り出す
check_bbox support -21 21 0 26 0 34
check_bbox rear_l -21 33 0 26 0 34
check_bbox rear_r -33 21 0 26 0 34

# y=1.4 / y=5 (通し区間・ナット窪み帯 7.2..10 の手前): M4通し六角 二面幅4.4
# (対角5.08) が X=±14・Z=7 に2つだけ開く。窪みが以前のようにレール接触面
# (y=0) 側にあればこの位置の loop は対角8.54になり span 一致に失敗するため、
# 特に y=1.4 が「窪みがレール側に無い」ことの直接検証になる。
# y=1.4 は柱 (y 2..26) の手前なので外形はブロックだけ = Z ∈ [0,14] で、
# X 端は全幅 ±21。R2 はナットのある y=10 側だけなのでレール接触面 (y=0)
# 側は直角のまま = 当たり面が全幅で平坦であることの直接検証
# (丸めが y=0 側にあった頃はここが 20.907 に食われていた)。
# y=5 は柱を通るため外形は Z=34 まで伸びる
for name in support rear_l rear_r; do
  check_section $name "$name-pass1.4" 1.4 \
    "hex -14 7 5.08 4.40; hex 14 7 5.08 4.40; outline -21 21 0 14"
done
# y=5 / y=7.1 は通し六角だけ、y=7.3 / y=8.6 (ナット窪み帯 7.2..10 の中) は
# ナット六角 二面幅7.4 (対角8.54)。窪みの底が 7.2 = 通し7.2 + 窪み2.8 で
# M4×10 がナットへ全掛かりする配分の実測になる。窪みはケース側 (y=10 の面)
# 開口で、M4ボルトはレールの向こう側から刺さって「頭｜レール壁｜土台｜
# ナット」を締め上げる。どの断面も柱 (y 2..26) を通るので外形は Z=34 まで
# (check_section は name/stl/spec を書き潰すので、部品名は part で持つ)
#
# y=8.6 だけは R2 の帯 (y 8..10) の中なので、柱に覆われていない側の X 端が
# 21 - (2 - sqrt(2^2 - 0.6^2)) = 20.907 に食われる (丸めは y=10 側だけ)
for part in support rear_l rear_r; do
  case $part in
    support)
      col_outline="outline -21 21 0 34"
      col_outline_r="outline -20.907 20.907 0 34"
      ;;
    rear_l)
      col_outline="outline -21 33 0 34"
      col_outline_r="outline -20.907 33 0 34"
      ;;
    rear_r)
      col_outline="outline -33 21 0 34"
      col_outline_r="outline -33 20.907 0 34"
      ;;
  esac
  for cut in 5 7.1; do
    check_section $part "$part-pass$cut" $cut \
      "hex -14 7 5.08 4.40; hex 14 7 5.08 4.40; $col_outline"
  done
  check_section $part "$part-pocket7.3" 7.3 \
    "hex -14 7 8.54 7.40; hex 14 7 8.54 7.40; $col_outline"
  check_section $part "$part-pocket8.6" 8.6 \
    "hex -14 7 8.54 7.40; hex 14 7 8.54 7.40; $col_outline_r"
done

# y=20 (ブロック y 0..10 の外・柱の張り出し帯): 柱の断面だけが残る。
# 柱は地面まで下りているので Z ∈ [0,34] (宙に浮いた柱はプリントできない)。
# ナット窪みを外へ24mm押し出した六角トンネルがここを貫くので、M4位置には
# 六角の断面 (二面幅7.4 = z 3.3..10.7) が void で現れ、その上下は材料に
# 戻る。柱の側面から見ると「◇」形の切り欠きになる。
# z=8 での六角の半幅は 4.2724 - 2.1362*(1/3.7) = 3.695 なので、
# support では x=-11 がトンネルの中・x=-9 は柱の材料。
# z=1 (六角帯 3.3..10.7 の下) が全点 solid = 柱の接地の直接検証
check_section support support-column 20 \
  "outline -12 12 0 34;
   void -11 8; void 11 8; solid -9 8; solid 0 8;
   solid -11 12; solid 11 12; solid 0 33;
   solid -11 1; solid 11 1; solid 0 1"
check_section rear_l rear_l-column 20 \
  "outline 9 33 0 34;
   void 14 8; solid 9.5 8; solid 19 8;
   solid 14 12; solid 32 8;
   solid 14 1; solid 9.5 1; solid 32 1"
check_section rear_r rear_r-column 20 \
  "outline -33 -9 0 34;
   void -14 8; solid -9.5 8; solid -19 8;
   solid -14 12; solid -32 8;
   solid -14 1; solid -9.5 1; solid -32 1"

# z=5 (M4軸より下の帯): 柱は地面まで下りているので土台 (Y 0..10) の奥にも
# 柱 (Y 10..26) の材料がある。ナットと干渉する六角トンネルだけが抜けており、
# z=5 での六角の半幅は 4.2724 - 2.1362*(2/3.7) = 3.1177 なので、
# x = 14 ∓ 3.1177 から柱の側面までの帯が柱の全奥行きにわたって空になる。
# 通し六角が土台を全厚貫通するので loop は左・中央・右の3本
check_plan support support-floor 5 \
  "loops 3; void_rect -12 -10.883 10 26; void_rect 10.883 12 10 26;
   solid 0 18; solid -9 18; solid 9 18; solid 0 5"
check_plan rear_l rear_l-floor 5 \
  "loops 3; void_rect 10.883 17.117 10 26;
   solid 9.5 18; solid 20 18; solid 0 5"
check_plan rear_r rear_r-floor 5 \
  "loops 3; void_rect -17.117 -10.883 10 26;
   solid -9.5 18; solid -20 18; solid 0 5"

# z=8 (柱の帯・M4軸の1mm上): 柱が土台の上に載り、ナット窪みを外へ24mm
# 押し出した六角トンネルが柱を Y 方向に貫いて void になる。トンネルの半幅は
# z=8 で 3.695 (上記の導出) なので、x = m4_dx ∓ 3.695 から柱の側面までの帯が
# 柱の全奥行き (Y 10..26) にわたって空であること = トンネルの開通を測る
check_plan support support-tunnel 8 \
  "void_rect -12 -10.305 10 26; void_rect 10.305 12 10 26;
   solid 0 18; solid -9 18; solid 9 18"
check_plan rear_l rear_l-tunnel 8 \
  "void_rect 10.305 17.695 10 26; solid 9.5 18; solid 20 18"
check_plan rear_r rear_r-tunnel 8 \
  "void_rect -17.695 -10.305 10 26; solid -9.5 18; solid -20 18"

# z=13 (ブロック上部・六角穴より上): 土台 42×10 に柱 (y 2..26) が繋がった
# 1つの loop。ナットのある ケース側 (y=10) の2隅だけ R2 で、レール接触面
# (y=0) 側の隅は直角のまま — 垂直フィレットの非対称を頂点位置で直接検証する。
# y=0 側を丸めると当たり面が減ってガタつき、y=10 側が尖ると手に刺さる。
# 奥用は柱が X=+21 (鏡像は -21) 側の y=10 の隅を覆うため、R2 の検証は
# 柱に覆われない側の隅で行う
for name in support rear_l rear_r; do
  case $name in
    support) plan_rect="rect -21 21 0 26" ;;
    rear_l) plan_rect="rect -21 33 0 26" ;;
    rear_r) plan_rect="rect -33 21 0 26" ;;
  esac
  check_plan $name "$name-block" 13 \
    "loops 1; $plan_rect; sharp -21 0; sharp 21 0"
done
check_plan support support-round 13 \
  "nosharp -21 10; nosharp 21 10; arc -19 8 2 8; arc 19 8 2 8"
check_plan rear_l rear_l-round 13 "nosharp -21 10; arc -19 8 2 8"
check_plan rear_r rear_r-round 13 "nosharp 21 10; arc 19 8 2 8"

# z=25 (ブロック上・柱だけの帯): 24×24 の柱が1本。X 範囲が standoff_offset の
# 実測になり、対称型は偏心0、奥用L/Rは +21 / -21 の鏡像対であることが確定する。
# Y 範囲 [2, 26] は柱をレール接触面から 2mm 離した standoff_setback の実測。
# 四隅は R2 (角位置に頂点が無く、半径2の弧上に頂点が載る)
check_plan support support-standoff 25 \
  "loops 1; rect -12 12 2 26;
   nosharp -12 2; nosharp 12 2; nosharp -12 26; nosharp 12 26;
   arc -10 4 2 8; arc 10 4 2 8; arc -10 24 2 8; arc 10 24 2 8"
check_plan rear_l rear_l-standoff 25 \
  "loops 1; rect 9 33 2 26;
   nosharp 9 2; nosharp 33 2; nosharp 9 26; nosharp 33 26;
   arc 11 4 2 8; arc 31 4 2 8; arc 11 24 2 8; arc 31 24 2 8"
check_plan rear_r rear_r-standoff 25 \
  "loops 1; rect -33 -9 2 26;
   nosharp -9 2; nosharp -33 2; nosharp -9 26; nosharp -33 26;
   arc -11 4 2 8; arc -31 4 2 8; arc -11 24 2 8; arc -31 24 2 8"

# 共通契約 (台帳 designs/steel-rack-500x400.md の確定値)
expect_echo support 'CONTRACT inner_support'
expect_echo rear_l 'CONTRACT inner_rear_l'
expect_echo rear_r 'CONTRACT inner_rear_r'
for name in support rear_l rear_r; do
  case $name in
    support) part=inner_support ;;
    rear_l) part=inner_rear_l ;;
    rear_r) part=inner_rear_r ;;
  esac
  # 土台の奥行きは10 (M4×10 が通し7.2 + 窪み2.8 でナットに全掛かりする厚さ)
  expect_echo $name "CONTRACT $part: block = [42, 10, 14]"
  expect_echo $name "CONTRACT $part: m4_x = [-14, 14]"
  expect_echo $name "CONTRACT $part: m4_z = 7"
  # クリアランス基準は外側ブラケットと同じ呼び寸法+0.4 / 実測+実効0.6
  expect_echo $name "CONTRACT $part: m4_pass_flat = 4.4"
  expect_echo $name "CONTRACT $part: m4_nut_flat = 7.4"
  expect_echo $name "CONTRACT $part: m4_nut_depth = 2.8"
  # 柱はケース四隅のネジ穴を跨ぐ 24×24 で、上端は z=34
  expect_echo $name "CONTRACT $part: standoff = [24, 24, 34]"
  # 柱をレール接触面から離す量 (実物フィードバックの暫定値・現物合わせ予定)
  expect_echo $name "CONTRACT $part: standoff_setback = 2"
  # 垂直エッジのRだけ (上下の水平エッジはプリント難度のため未加工)
  expect_echo $name "CONTRACT $part: corner_r = 2"
done

# スタンドオフの偏心: 対称型は0 (鏡像不変で手前L/R・中央L/Rの4個に共用)、
# 奥用は自 datum で +21 (module は鏡像前の値を echo するため L/R とも 21)。
# 右用は mirror 後の実位置 -21 を自分で宣言する
expect_echo support 'CONTRACT inner_support: standoff_offset = 0'
expect_echo rear_l 'CONTRACT inner_rear_l: standoff_offset = 21'
expect_echo rear_r 'CONTRACT inner_rear_r: standoff_offset = 21'
expect_echo rear_r 'CONTRACT inner_rear_r: standoff_offset_mirrored = -21'

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "slide-rail-inner tests passed"
