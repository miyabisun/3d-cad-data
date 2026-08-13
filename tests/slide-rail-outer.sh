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
# - hex_x_flat_up(10): 部品Z方向 (2D X) = 二面幅10.00、部品Y方向 (2D Y) = 対角11.55
# - hex_y_flat_up(3): 部品X方向 (2D X) = 対角3.46、部品Z方向 (2D Y) = 二面幅3.00
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
check_hex m6_flat_up hex_x_flat_up 10 10.00 11.55 "0, -90, 0"
# rotate([90,0,0]): 部品Y軸→2D法線。2D X=部品X、2D Y=部品Z(反転)
check_hex screw_flat_up hex_y_flat_up 3 3.46 3.00 "90, 0, 0"

# 共通契約 (台帳 designs/steel-rack-500x400.md の確定値)
for name in front rear; do
  expect_echo $name 'height = 45'
  expect_echo $name 'flange_t = 10'
  expect_echo $name 'inner_r = 4'
  expect_echo $name 'm6_z = [10.5, 34.5]'
  expect_echo $name 'm6_pass_flat = 6'
  expect_echo $name 'm6_nut_flat = 10'
  expect_echo $name 'screw_z = 22.5'
  expect_echo $name 'screw_flat = 3'
  expect_echo $name 'guard_d = 14'
  expect_echo $name 'edge_margin = 8'
  expect_echo $name 'angle_t = 2.2'
done

# 派生値の回帰固定: 8mm余白を flat-up の実半径 (対角/2) で導出した値。
# helper だけ flat-up のまま導出を二面幅/2 へ戻す退行を検知する
# (M6: 対角/2 = 5.7735、木ネジ: 対角/2 = 1.7321)
for name in front rear; do
  expect_echo $name 'm6_y = 27.7735, short_len = 41.547'
done
expect_echo front 'arm_end = 107.732'
expect_echo rear 'arm_end = 182.232'

# 木ネジ位置: 各パーツ自身の datum (そのアングル外側面) 基準
expect_echo front 'screw_x = [34, 98]'
expect_echo rear 'screw_x = [76.5, 172.5]'

# rear はラック手前 datum への正規化値も宣言する (400 - x)
expect_echo rear 'screw_x_front_datum = [227.5, 323.5]'

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "slide-rail-outer tests passed"
