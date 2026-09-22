# modules

OpenSCADモデルが参照するモジュール。

## bolts.scad

ボルト穴・ナットトラップ・六角穴の汎用モジュール。

### 基本モジュール

| モジュール | 用途 |
|-----------|------|
| `bolt_hole(d, h)` | 丸穴（ボルト通し穴） |
| `nut_trap(d, h)` | 六角ナットトラップ |
| `hex_hole(flat_d, h)` | セルフタッピング用六角穴（二面幅 - 0.2mm） |

### サイズ別モジュール

M3 / M4 / M6 / M8 の各サイズに対応。

- `mX_bolt_hole(h)` - ボルト通し穴
- `mX_nut_trap(h)` - ナットトラップ
- `mX_bolt_hexhole(h)` - セルフタッピング用六角穴

寸法はクリアランス込み（例: M6 bolt_hole = 6.2mm径）。

## steel_rack.scad

500x400 スチールラック用の共通モジュール。`bolts.scad` に依存。

### ボルト穴パターン

ラックのフレーム穴位置に基づく3点パターン:

| 位置 | オフセット | 累計 |
|------|-----------|------|
| 1st | 15mm（端から） | 15mm |
| 2nd | +98mm | 113mm |
| 3rd | +24mm | 137mm |

### モジュール

| モジュール | 用途 |
|-----------|------|
| `long_bar(w, y, h)` | 3穴付きバー |
| `short_bar(w, y, h)` | 1穴付きバー（先頭穴のみ） |
| `fillet_profile(r, h)` | 内側コーナーフィレット |
| `bolt_and_nut(y, h)` | M6 ボルト穴 + ナットトラップのペア |

## gridfinity.scad

Gridfinity ベースプレートの共通モジュール。ピッチは42mm。
ソケット輪郭は
上端開口 41.5（R4）→ 45° 面取り 2.15 → 垂直 1.8（37.2 角・R1.85）→
45° 面取り 0.7 → 底 35.8 角（R1.15）。深さは4.65。

| モジュール | 用途 |
|-----------|------|
| `gf_socket_cut(clearance, pitch_x)` | ソケット 1 個の切削体（z=0 がソケット底、+Z へ抜ける）。`clearance` で輪郭を全周へ逃がす（幅 +2c、角 R +c。既定 0 = 公称） |
| `gf_baseplate(cols, rows, rim, floor_t, clearance)` | cols×rows のソケットを床 `floor_t` の上に彫った板。`rim=[left,right,front,back]` でソケット列の外側に縁を残す |

座標系は X が列方向（中央 0）、Y が行方向（板の前端 0）、Z=0 が底面。
`gf_baseplate` の `cols` は端数を左端に配置できる（`rows` は整数）。
`gf_socket_cut` の `pitch_x` はX方向のセル幅（既定42mm）。角R・面取りは
保ったまま横幅だけを変更する。角Rが成立しない8.5mm以下の幅は拒否する。

## xbrace.scad

2D の X 筋交い窓。板の肉抜きへ `difference` で使う。

| モジュール | 用途 |
|-----------|------|
| `xbrace_window(size, line)` | 矩形 `size=[w,d]` (中心が原点) の窓から、対角 2 本の筋交い (幅 `line`) を残した 4 つの三角形の開口 |

## iris_oyama_a4_lcj.scad

`assets/letter-case/iris-oyama-a4-lcj/` の前片・奥片が include する共通値。
形状は `letter_case_plate(rows, rim)` で生成する。単体では何も描かない
ので render 対象の `assets/` には置かない。

## gridfinity_bin.scad

Gridfinity bin (箱) の共有 module。`gridfinity.scad` のピッチ・角丸を共有する。

| モジュール | 用途 |
|-----------|------|
| `gfb_base_cell(pitch = [42, 42])` | 1 マスぶんの無垢の底 (35.6 → 37.2 → 41.5、高さ 4.75)。半セルは該当軸のpitchを21にし、角Rと面取りは維持 |
| `gfb_bin(cols, rows, units, wall, floor_t, label_d, label_t, label_r)` | 薄いリップの bin。`label_d > 0` で奥側（+Y）の壁上端に内側へ張り出すラベル天板と、その下の 45° 無垢くさび (先端の境目 R `label_r`) |
| `gfb_recess(wall, floor_t, r, skin)` | 底 1 マスぶんの窪みの cut。`gfb_base_cell` の 3 段を `wall` だけ内側・`floor_t` だけ上へ寄せた相似形 (45°) を z=`skin` で切った形。天面の隅は R `r` |
| `gfb_card_case(cols, rows, units, wall, floor_t, card, clearance, offset, r, skin, edge_r)` | `gfb_bin` (ラベル無し) の内側を壁の上端まで埋め、X 中央・手前の壁の内面から `offset` (スカラー、Y) 奥に `card + clearance` のポケット (隅 R `r`)、右奥のマスに壁の内面までの穴 (隅は内壁と同じ R) + `gfb_recess` の窪み (床 z=`skin`) を抜いたカードケース。ポケットと穴が交わる所の埋めの凸の縦エッジは R `edge_r` (抜く輪郭の閉演算) |

## gridfinity_bins.scad

`assets/gridfinity-bin/` の bin 群の共通値と、サイズ3引数の生成モジュール。
共通値は壁1.2・床1.2・ラベル天板13×1・境目R1。
カードケースはカード54×85.6 (ID-1)・余裕1・手前の壁からの距離10・隅R3・縦エッジR2・窪みの床2.95。
生成には `gridfinity_bin(cols, rows, units)` / `gridfinity_card_case(cols, rows, units)` を使う。
単体では何も描かない。通常binはX={1,1.5,2,2.5,3} × Y={1,2,3,4,5,5.5} ×
units={4,9}から両軸端数を除く56種。端数の足はX左端・Y手前に置く。
カードケースはgoods配下の2×3×4。

## temna_roomcase_puchi.scad

`assets/letter-case/temna-roomcase-puchi/` の前後片が include する天馬専用の実測値・調整値。
形状は `roomcase_puchi_plate(part_rows, rear)` で生成する。横幅の端数は左端セル、
奥行きの端数はX筋交い付きの縁にし、奥の左右角をR4にする。
