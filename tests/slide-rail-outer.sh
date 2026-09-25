#!/bin/bash
# スライドレール外側ブラケット (front/rear) のレンダリング検証。
# - openscad が exit 0 で非空の STL を生成すること
# - console に ERROR / WARNING が出ないこと
# - 設計契約 (CONTRACT echo) が台帳の確定値と一致すること
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0
err() {
  echo "slide-rail-outer: $*" >&2
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

render front assets/steel-rack/500x400/slide_rail_outer_front.scad
render rear assets/steel-rack/500x400/slide_rail_outer_rear.scad

# 六角穴の向きの機械検査: helper の断面を軸方向へ投影して bbox を測る。
# 期待値は二面幅/対角 (= 二面幅/cos30) のペアで、向きが逆なら縦横が入れ替わり赤になる。
# - hex_x_flat_up(10.4): 部品Z方向 (2D X) = 二面幅10.40、部品Y方向 (2D Y) = 対角12.01
# - hex_y_flat_up(4.4): 部品X方向 (2D X) = 対角5.08、部品Z方向 (2D Y) = 二面幅4.40
check_hex() {
  name=$1 helper=$2 flat=$3 want_x=$4 want_y=$5
  cat > "$WORK/hex_$name.scad" <<EOF
use <$ROOT/modules/slide_rail_outer_bracket.scad>
projection() rotate([ $6 ]) $helper($flat, 5);
EOF
  if ! openscad -o "$WORK/hex_$name.svg" "$WORK/hex_$name.scad" > /dev/null 2>&1; then
    err "hex orientation: $name failed to render"
    return
  fi
  python3 - "$WORK/hex_$name.svg" "$name" "$want_x" "$want_y" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name, want_x, want_y = sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
pts = re.findall(r'(-?\d+\.?\d*),(-?\d+\.?\d*)', re.search(r'd="([^"]+)"', src).group(1))
xs = [float(a) for a, b in pts]
ys = [float(b) for a, b in pts]
span_x, span_y = max(xs) - min(xs), max(ys) - min(ys)
ok = abs(span_x - want_x) < 0.05 and abs(span_y - want_y) < 0.05
print(f"hex orientation {name}: span=({span_x:.2f},{span_y:.2f}) want=({want_x},{want_y})"
      + ("" if ok else " FAIL"))
sys.exit(0 if ok else 1)
PYEOF
}

# rotate([0,-90,0]): 部品X軸→2D法線。2D X=部品Z(反転)、2D Y=部品Y
check_hex m6_flat_up hex_x_flat_up 10.4 10.40 12.01 "0, -90, 0"
# rotate([90,0,0]): 部品Y軸→2D法線。2D X=部品X、2D Y=部品Z(反転)
check_hex m4_flat_up hex_y_flat_up 4.4 5.08 4.40 "90, 0, 0"

# 実 module の断面検査: front 実体の X-Z 断面 (2D X=部品X, 2D Y=-部品Z) を
# 指定 y で切り、穴の bbox・中心と外形の範囲を実測する。
# echo/helper 検査だけでは検知できない production 形状の退行
# (窪みの削除・開口面の反転・ガードの復活など) をここで捉える。
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
    pts = [(float(a), float(b)) for a, b in re.findall(r'(-?\d+\.?\d*),(-?\d+\.?\d*)', sub)]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    loops.append((min(xs), max(xs), min(ys), max(ys)))
ok = True
for cond in spec.split(";"):
    kind, *args = cond.split()
    if kind == "hex":  # hex <cx> <cz> <span_x> <span_z>
        # openscad の SVG は y 軸が反転して書かれるため、生の y が部品Zに一致する
        cx, cz, sx, sz = map(float, args)
        found = any(abs((x1 + x2) / 2 - cx) < 0.1 and abs((y1 + y2) / 2 - cz) < 0.1
                    and abs((x2 - x1) - sx) < 0.05 and abs((y2 - y1) - sz) < 0.05
                    for x1, x2, y1, y2 in loops)
        if not found:
            print(f"section {name}: missing hex ({cx},{cz}) span ({sx},{sz})")
            ok = False
    elif kind == "max_x":  # max_x <limit> — 外形がこの X を超えない
        limit = float(args[0])
        worst = max(x2 for _, x2, _, _ in loops)
        if worst > limit + 0.05:
            print(f"section {name}: outline reaches x={worst:.2f} > {limit}")
            ok = False
print(f"section {name}: {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PYEOF
}

# y=4 (通し区間): M4通し六角 4.4 (対角5.08) が補正後の座標に開く
check_section front pass 4 "hex 37 22.5 5.08 4.40; hex 101.5 22.5 5.08 4.40"
# y=6.5 (窪み区間 y∈[5.2,8]): M4ナット窪み 7.4 (対角8.54) が内側面 y=8 側に開く
check_section front pocket 6.5 "hex 37 22.5 8.54 7.40; hex 101.5 22.5 8.54 7.40"
# y=13 (旧ガード区間): 長辺の外 (x>12.3) に形状が無い = ガードが復活していない。
# ナット回廊 (x 7.2..12.2) の切り欠きはこの断面を z 帯で分断するが、
# どの loop も x=12.2 (短辺背面) を超えない
check_section front no-guard 13 "max_x 12.3"
# rear も補正後の座標 (自 datum 基準 79.5/176) に通しが開く
check_section rear rear-pass 4 "hex 79.5 22.5 5.08 4.40; hex 176 22.5 5.08 4.40"

# M6ナット挿入回廊の開通検査: ナット高さの水平断面 (X-Y、2D生yは-部品y) を実測。
# x=13 の Y-Z 断面では切り欠きが bbox を変えず検知できないため、水平断面で
# - clear: fillet 帯 (x 12.35..16.45) に長辺外面 (y=8、逃げ溝含め+0.05) を
#   超える材料が無い = fillet が局所カットされナットが +X から直進できる
# - island: 短辺の上部 (y>=16) が回廊+通し穴で分断されて孤立 loop になる
#   = ナット窪みが短辺を貫いている
# 回廊を塞ぐ退行では fillet の弧 (y 最大 11.4) が clear 検査に掛かり赤になる
check_corridor() {
  stl=$1 name=$2 cut_z=$3
  if ! python3 "$SCRIPT_DIR/stl_geometry.py" svg "$WORK/$stl.stl" z "$cut_z" "$WORK/cor_$name.svg" > /dev/null 2>&1; then
    err "corridor $name: failed to render"
    return
  fi
  python3 - "$WORK/cor_$name.svg" "$name" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name = sys.argv[2]
loops = []
worst = None
for sub in re.search(r'd="([^"]+)"', src).group(1).split("M")[1:]:
    pts = [(float(a), -float(b)) for a, b in re.findall(r'(-?\d+\.?\d*),(-?\d+\.?\d*)', sub)]
    loops.append(pts)
    for x, y in pts:
        if 12.35 < x < 16.45 and (worst is None or y > worst):
            worst = y
ok = True
if worst is not None and worst > 8.05:
    print(f"corridor {name}: fillet band not cleared (max y = {worst:.2f})")
    ok = False
if not any(min(y for _, y in pts) >= 16 for pts in loops):
    print(f"corridor {name}: nut slot does not sever the short flange")
    ok = False
print(f"corridor {name}: {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PYEOF
}

check_corridor front corridor-lo 10.5
check_corridor front corridor-hi 34.5

# M6 実穴の絶対位置検査: production STL の Y-Z 断面 (x=9.7、ナット窪み区間)。
# CONTRACT echo は自己申告のため、レール面 (y=0) から M6 穴中心までの実距離と
# 部品外端 (短辺の外縁 y=28.0089) を実形状で直接測定する。M6 穴の translate
# だけがずれる退行 (echo・導出値は正のまま) をここで捉える。
# rotate([0,-90,0]) の写像は SVG 生値で x = -部品Z、y = -部品Y (実測で確認済み)。
# 穴 bbox は Y に六角対角 12.0089、下端はさらに逃げ溝 0.2 が付くため、
# 中心は「bbox 上端 - 対角/2」で測る (= m6_y。逃げ溝の影響を受けない)
check_m6_position() {
  stl=$1 name=$2
  cat > "$WORK/m6p_$name.scad" <<EOF
projection(cut = true) rotate([ 0, -90, 0 ]) translate([ -9.7, 0, 0 ])
  import("$WORK/$stl.stl");
EOF
  if ! openscad -o "$WORK/m6p_$name.svg" "$WORK/m6p_$name.scad" > /dev/null 2>&1; then
    err "m6 position $name: failed to render"
    return
  fi
  python3 - "$WORK/m6p_$name.svg" "$name" <<'PYEOF' || fail=1
import re, sys
src = open(sys.argv[1]).read()
name = sys.argv[2]
loops = []  # (y_min, y_max, z_min, z_max) 部品座標
for sub in re.search(r'd="([^"]+)"', src).group(1).split("M")[1:]:
    pts = [(-float(b), -float(a)) for a, b in re.findall(r'(-?\d+\.?\d*),(-?\d+\.?\d*)', sub)]
    ys = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    loops.append((min(ys), max(ys), min(zs), max(zs)))
ok = True
# 部品外形: レール面 y=0 から短辺外縁 y=28.0089 まで
body = max(loops, key=lambda l: l[1] - l[0])
if abs(body[0] - 0) > 0.05 or abs(body[1] - 28.0089) > 0.05:
    print(f"m6 position {name}: body y=[{body[0]:.4f},{body[1]:.4f}] want [0,28.0089]")
    ok = False
# M6 ナット六角 ×2: bbox (対角12.0089 + 逃げ溝0.2) × (二面幅10.40)
diag = 12.0089
for cz in (10.5, 34.5):
    hole = [l for l in loops
            if abs((l[2] + l[3]) / 2 - cz) < 0.1 and abs((l[3] - l[2]) - 10.40) < 0.05
            and abs((l[1] - l[0]) - (diag + 0.2)) < 0.05]
    if not hole:
        print(f"m6 position {name}: nut hex at z={cz} not found")
        ok = False
        continue
    m6_y = hole[0][1] - diag / 2  # レール面から実穴中心までの実距離
    if abs(m6_y - 14.0044) > 0.1:
        print(f"m6 position {name}: z={cz} measured m6_y = {m6_y:.4f} want 14.0044")
        ok = False
    else:
        print(f"m6 position {name}: z={cz} m6_y = {m6_y:.4f}")
print(f"m6 position {name}: {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PYEOF
}

check_m6_position front m6-front
check_m6_position rear m6-rear

# 共通契約 (台帳 designs/steel-rack-500x400.md の確定値)
for name in front rear; do
  expect_echo $name 'height = 45'
  expect_echo $name 'flange_t = 10'
  expect_echo $name 'arm_t = 8'
  expect_echo $name 'rail_offset = 14'
  expect_echo $name 'inner_r = 4'
  expect_echo $name 'm6_z = [10.5, 34.5]'
  expect_echo $name 'm6_pass_flat = 6.4'
  expect_echo $name 'm6_nut_flat = 10.4'
  expect_echo $name 'screw_z = 22.5'
  expect_echo $name 'm4_pass_flat = 4.4'
  expect_echo $name 'm4_nut_flat = 7.4'
  expect_echo $name 'm4_nut_depth = 2.8'
  expect_echo $name 'edge_margin = 8'
  expect_echo $name 'angle_t = 2.2'
done

# 派生値の回帰固定: 8mm余白を flat-up の実半径 (対角/2) で導出した値から
# rail_offset=14 を引き、M6実穴の絶対位置を保ったままレール面を外へ出した値。
# helper だけ flat-up のまま導出を二面幅/2 へ戻す退行や offset の欠落を検知する
# (M6ナット10.4: 対角/2 = 6.0044、M4ナット7.4: 対角/2 = 4.2724)
for name in front rear; do
  expect_echo $name 'm6_y = 14.0044, short_len = 28.0089'
done
expect_echo front 'arm_end = 113.772'
expect_echo rear 'arm_end = 188.272'

# M4ネジ位置: 各パーツ自身の datum (そのアングル外側面) 基準。
# 両パーツとも実プリントの座標ズレ補正済み (各穴を自 datum から +3 / +3.5)
expect_echo front 'screw_x = [37, 101.5]'
expect_echo rear 'screw_x = [79.5, 176]'

# rear はラック手前 datum への正規化値も宣言する (400 - x)
expect_echo rear 'screw_x_front_datum = [224, 320.5]'

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "slide-rail-outer tests passed"
