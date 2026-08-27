# modules

プロジェクト横断で再利用する共通モジュール。

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

Gridfinity ベースプレートの共通モジュール。ピッチ 42mm、ソケット輪郭は
上端開口 41.5（R4）→ 45° 面取り 2.15 → 垂直 1.8（37.2 角・R1.85）→
45° 面取り 0.7 → 底 35.8 角（R1.15）、深さ 4.65。

| モジュール | 用途 |
|-----------|------|
| `gf_socket_cut(clearance)` | ソケット 1 個の切削体（z=0 がソケット底、+Z へ抜ける）。`clearance` で輪郭を全周へ逃がす（幅 +2c、角 R +c。既定 0 = 公称） |
| `gf_baseplate(cols, rows, rim, floor_t, clearance)` | cols×rows のソケットを床 `floor_t` の上に彫った板。`rim=[left,right,front,back]` でソケット列の外側に縁を残す |

座標系は X が列方向（中央 0）、Y が行方向（板の前端 0）、Z=0 が底面。

## xbrace.scad

2D の X 筋交い窓。板の肉抜きへ `difference` で使う。

| モジュール | 用途 |
|-----------|------|
| `xbrace_window(size, line)` | 矩形 `size=[w,d]` (中心が原点) の窓から、対角 2 本の筋交い (幅 `line`) を残した 4 つの三角形の開口 |

## letter_case.scad

`assets/letter-case/` の前片・奥片が include する project 固有の共通値と
`letter_case_plate(rows, rim)`。共有モジュールではないが、単体では何も描かない
ので render 対象の `assets/` には置かない。

## gridfinity_bin.scad

Gridfinity bin (箱) の共有 module。`gridfinity.scad` のピッチ・角丸を共有する。

| モジュール | 用途 |
|-----------|------|
| `gfb_base_cell()` | 1 マスぶんの無垢の底 (35.6 → 37.2 → 41.5、高さ 4.75) |
| `gfb_bin(cols, rows, units, wall, floor_t, label_d, label_t, label_r)` | 薄いリップの bin。`label_d > 0` で手前の壁上端に内側へ張り出すラベル天板と、その下の 45° 無垢くさび (先端の境目 R `label_r`) |

## gridfinity_bin_4u.scad

`assets/gridfinity-bin/` の 4U bin 群の共通値 (壁 1.2・床 1.2・ラベル天板 13×1・
境目 R1) と `bin_4u(cols, rows)`。単体では何も描かない。
