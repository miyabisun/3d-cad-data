#!/bin/bash
# 簡易クランプ M8 ボルトの手回しノブのレンダリング検証。
# - openscad が exit 0 で非空の STL を生成すること
# - console に ERROR / WARNING が出ないこと
# - 設計契約 (CONTRACT echo) が台帳の確定値と一致すること
# - production STL の水平断面実測で、レバーの全長・M8 通し穴・ボルト先端の
#   六角ポケットを実形状として固定すること (echo は自己申告なので形状で裏を取る)
# - STL が1連結成分であること (ボスが本体から浮いていないこと)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail=0
err() {
  echo "clamp: $*" >&2
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

render knob assets/clamp/hand_knob.scad

# ---------------------------------------------------------------------------
# 1. 下段 (Z 0..5) = レバー本体。楕円ローブ2枚 ∪ 中央ハブ円の平面輪郭に、
#    M8 軸の通し穴 Φ8.4 が同軸で開く。全長 (X) はちょうど 36。
#    ハブ円 (Φ21.473 = 六角対角15.473 + 壁3×2) はローブの短径 16 より太いので、
#    外形の Y 幅はハブが決める
# ---------------------------------------------------------------------------
# z=2.5: 外形1本 + 通し穴1本 = 2 loop。全長36 は rect の X 幅で実測する
check_plan knob lever 2.5 \
  "loops 2;
   rect -18 18 -10.736 10.736;
   loop 0 0 8.4 8.4;
   void 0 0; solid 0 5; solid 12 0; solid 17.5 0; void 18.5 0"
# ローブが楕円であること (矩形の腕なら x=17.5 で y=3 まで材料が続く)。
# 楕円 26×16 を中心 x=±5 に置くと、x=17.5 での半高は 2.198 しかない
check_plan knob lobe-taper 2.5 "solid 17.5 0; void 17.5 3; solid 17.5 2"

# ---------------------------------------------------------------------------
# 2. 上段 (Z 5..10) = 中央ハブだけのボス。ボルト先端の六角 (二面幅13.4) を
#    上から受けるポケットが開く。ローブはこの高さに無い
# ---------------------------------------------------------------------------
# z=7.5: ハブの外形1本 + 六角ポケット1本 = 2 loop。六角は $fn=6 で対角が
# X (15.473)、二面幅が Y (13.4) に出る。ローブが上段まで伸びていれば
# rect の X 幅が 36 になって red
check_plan knob boss 7.5 \
  "loops 2;
   rect -10.736 10.736 -10.736 10.736;
   loop 0 0 15.473 13.4;
   void 0 0; solid 0 8; solid 9 0; void 0 11.5;
   void 17 0; void -17 0"

# ---------------------------------------------------------------------------
# 3. 段の切り替わる高さ (Z=5) と、穴が Z 0..10 で連続して上へ抜けること。
#    水平断面は「その高さに何が在るか」しか見えないので、境界を Z=4 へ
#    ずらした形状や、Z=5 付近で穴を塞ぐ薄い天井を素通しにしてしまう。
#    ここは境界を跨ぐ2枚の水平断面と、軸を通る縦断面で測る
# ---------------------------------------------------------------------------
# 境界の直下 (z=4.9): まだ下段。外形は全長36 のまま (ローブが在る) で、穴は
# Φ8.4 の丸。境界が Z=4 へ下がっていれば、ここに六角と 21.473 の外形が出て red
check_plan knob step-below 4.9 \
  "loops 2; rect -18 18 -10.736 10.736; loop 0 0 8.4 8.4; solid 6 0"
# 境界の直上 (z=5.1): もう上段。外形はハブ径 21.473 だけになり、穴は六角。
# 境界が Z=6 へ上がっていれば、ここに丸穴と全長36 の外形が出て red
check_plan knob step-above 5.1 \
  "loops 2; rect -10.736 10.736 -10.736 10.736; loop 0 0 15.473 13.4; void 6 0"
# 軸を通る縦断面 (y=0)。穴が部品を上下に貫くので断面は左右2枚に割れ、
# それぞれが x ±4.2..18 (下段の穴壁から全長端まで)・z 0..10 の bbox を持つ。
#   ① 段の位置: x=±6 は「下段では材料・上段では六角の中」なので、
#      z=4.9 で solid・z=5.1 で void になる。境界が 4.9..5.1 に在る実測で、
#      Z=4 へずらせば 4.9 が void になって red
#   ② 天井が無いこと: 中心穴の帯 (x -4.2..4.2) を全高 z 0..10 にわたり
#      void_rect で測る。材料の境界がこの矩形へ1辺も入って来なければ、
#      穴を横切る水平な膜 (ブリッジ) は無く、上開きのまま抜けている。
#      点で拾うと 0.4mm 級の薄膜を見逃すので、幾何交差で測る
check_section knob axis 0 \
  "loop -11.1 5 13.8 10; loop 11.1 5 13.8 10;
   void_rect -4.2 4.2 0 10;
   solid -6 4.9; void -6 5.1; solid 6 4.9; void 6 5.1;
   solid -6 0.2; solid 6 0.2; void -6 9.8; void 6 9.8;
   solid -9 9.8; solid 9 9.8"

# ---------------------------------------------------------------------------
# 4. 形状健全性: 外形 bbox と単一連結成分。
#    Z は 5 + 5 = 10、X は全長 36、Y はハブ径 21.473
# ---------------------------------------------------------------------------
check_bbox knob -18 18 -10.736 10.736 0 10
check_single_solid knob

# 設計契約 (台帳 designs/clamp-hand-knob.md の確定値)。
# 照合は console の行全体との完全一致で、値の桁を1つも動かせない
# クランプの実測値 (コの字ステンレス板・ネジ穴は M8 相当の 7.8Φ)
expect_echo knob 'CONTRACT hand_knob: clamp_plate = [3.8, 28.4, 24]'
expect_echo knob 'CONTRACT hand_knob: clamp_thread_d = 7.8'
# ボルト先端の六角は実測 12.8。ここへ差し込むので嵌合クリアランスは呼び+0.6
expect_echo knob 'CONTRACT hand_knob: tip_hex_measured = 12.8'
expect_echo knob 'CONTRACT hand_knob: clearance = 0.6'
# 手回しレバーの全長 (user 指定の 36mm)
expect_echo knob 'CONTRACT hand_knob: knob_len = 36'
expect_echo knob 'CONTRACT hand_knob: lobe = [26, 16]'
expect_echo knob 'CONTRACT hand_knob: lobe_offset = 5'
# M8 軸の通し穴 (7.8 + 0.6)
expect_echo knob 'CONTRACT hand_knob: m8_pass_d = 8.4'
# 六角ポケットの二面幅 (12.8 + 0.6) と、そこから決まる対角
expect_echo knob 'CONTRACT hand_knob: tip_hex_flat = 13.4'
expect_echo knob 'CONTRACT hand_knob: tip_hex_diag = 15.473'
# ハブ径は六角対角 + 壁3mm×2 の導出値
expect_echo knob 'CONTRACT hand_knob: hub_wall = 3'
expect_echo knob 'CONTRACT hand_knob: hub_d = 21.473'
# 下段 (通し穴) 5mm + 上段 (六角ポケット) 5mm
expect_echo knob 'CONTRACT hand_knob: heights = [5, 5]'

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "clamp tests passed"
