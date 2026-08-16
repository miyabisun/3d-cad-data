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
check_section() {
  stl=$1 name=$2 cut_y=$3 spec=$4
  cat > "$WORK/sec_$name.scad" <<EOF
projection(cut = true) rotate([ 90, 0, 0 ]) translate([ 0, -$cut_y, 0 ])
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
    pts = [(float(a), float(b)) for a, b in re.findall(r'(-?\d+\.?\d*),(-?\d+\.?\d*)', sub)]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    loops.append((min(xs), max(xs), min(ys), max(ys)))
ok = True
for cond in spec.split(";"):
    kind, *args = cond.split()
    if kind == "hex":  # hex <cx> <cz> <span_x> <span_z>
        cx, cz, sx, sz = map(float, args)
        hit = [l for l in loops
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
        body = max(loops, key=lambda l: (l[1] - l[0]) * (l[3] - l[2]))
        print(f"section {name}: outline x=[{body[0]:.3f},{body[1]:.3f}]"
              f" z=[{body[2]:.3f},{body[3]:.3f}]")
        if any(abs(a - b) > 0.05 for a, b in zip(body, (x1, x2, z1, z2))):
            print(f"section {name}: outline want x=[{x1},{x2}] z=[{z1},{z2}]")
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
# sharp/nosharp/arc は最大 loop (外形) の頂点だけを見る。
# 「角の鋭点が無い」+「弧上に頂点が載る」の2条件で垂直フィレットを実測する
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

# y=5 / y=9 (通し区間・ケース側の面 y=10 の手前): M4通し六角 二面幅4.4
# (対角5.08) が X=±14・Z=7 に2つだけ開く。窪みが以前のように y=10 側に
# あればこの位置の loop は対角8.54になり span 一致に失敗するため、
# この2断面がナット窪みの向き (レール接触面側) の直接検証になる。
# どちらも柱 (y 2..26) を通るため外形は Z=34 まで伸びる
for cut in 5 9; do
  check_section support "support-pass$cut" $cut \
    "hex -14 7 5.08 4.40; hex 14 7 5.08 4.40; outline -21 21 0 34"
  check_section rear_l "rear_l-pass$cut" $cut \
    "hex -14 7 5.08 4.40; hex 14 7 5.08 4.40; outline -21 33 0 34"
  check_section rear_r "rear_r-pass$cut" $cut \
    "hex -14 7 5.08 4.40; hex 14 7 5.08 4.40; outline -33 21 0 34"
done

# y=1.4 (ナット窪み帯 0..2.8 の中): ナット六角 二面幅7.4 (対角8.54) が
# X=±14・Z=7 に開く。窪みはレール接触面 (y=0) 側にあり、レール板が
# ナットの背中を押さえて脱落を防ぐ。柱 (y 2..26) の外なので外形は
# ブロックだけ = Z ∈ [0,14]。X 端は土台ナット側の R2 に食われて
# 21 - (2 - sqrt(2^2 - 0.6^2)) = 20.907 まで縮む
for name in support rear_l rear_r; do
  check_section $name "$name-pocket" 1.4 \
    "hex -14 7 8.54 7.40; hex 14 7 8.54 7.40; outline -20.907 20.907 0 14"
done

# y=20 (ブロック y 0..10 の外・柱の張り出し帯): 柱の断面だけが残り、
# Z ∈ [0,34] に連続して存在する = 柱が z=0 まで下りて接地している直接検証。
# X 範囲は柱24 の実測 (偏心 0 / +21 / -21)
check_section support support-column 20 "outline -12 12 0 34"
check_section rear_l rear_l-column 20 "outline 9 33 0 34"
check_section rear_r rear_r-column 20 "outline -33 -9 0 34"

# z=13 (ブロック上部・六角穴より上): 土台 42×10 に柱 (y 2..26) が繋がった
# 1つの loop。ナット側 (y=0) の2隅だけ R2 で、ケース側 (y=10) の隅は直角の
# まま — 垂直フィレットの非対称を頂点位置で直接検証する。
# 奥用は柱が X=+21 (鏡像は -21) 側の y=10 の隅を覆うため、直角の検証は
# 柱に覆われない側の隅で行う
for name in support rear_l rear_r; do
  case $name in
    support) plan_rect="rect -21 21 0 26" ;;
    rear_l) plan_rect="rect -21 33 0 26" ;;
    rear_r) plan_rect="rect -33 21 0 26" ;;
  esac
  check_plan $name "$name-block" 13 \
    "loops 1; $plan_rect; nosharp -21 0; nosharp 21 0;
     arc -19 2 2 8; arc 19 2 2 8"
done
check_plan support support-square 13 "sharp -21 10; sharp 21 10"
check_plan rear_l rear_l-square 13 "sharp -21 10"
check_plan rear_r rear_r-square 13 "sharp 21 10"

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
  # 柱はケース四隅のネジ穴を跨ぐ 24×24 で、土台から16mm張り出して接地する
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
