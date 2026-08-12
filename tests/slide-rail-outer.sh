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

# 木ネジ位置: 各パーツ自身の datum (そのアングル外側面) 基準
expect_echo front 'screw_x = [34, 98]'
expect_echo rear 'screw_x = [76.5, 172.5]'

# rear はラック手前 datum への正規化値も宣言する (400 - x)
expect_echo rear 'screw_x_front_datum = [227.5, 323.5]'

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "slide-rail-outer tests passed"
