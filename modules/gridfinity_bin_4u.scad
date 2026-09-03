include <gridfinity_bin.scad>

// assets/gridfinity-bin/ の bin 群の共通値と、サイズ 3 引数の払い出し口。
// 単体では何も描かない。設計の経緯と確定値は
// ledger/designs/gridfinity-bin-4u.md が正本。 保証する範囲は bin が cols 1..5 ×
// rows 1..5 × units 4 (assets に並ぶ 25 種)、カードケースが 2x3x4。 cols が X (横)、rows が Y
// (ラベルの壁から奥へ)、units が高さ (7mm 単位)。
wall = 1.2;    // 0.4 ノズル 3 本
floor_t = 1.2; // 底 (4.75) の上に載せる床。床の天面 z = 5.95
label_d = 13;  // 12mm 幅のラベルシールを貼る天板の張り出し
label_t = 1; // 天板の厚さ (user 指定)。下は 45° の無垢のくさび
label_r = 1; // 天板の先端と 45° 面の境目の R (user 指定)
// カードケース (card_case_{c}x{r}x4u.scad) の値。カードは実測 53.7 × 85.5 × 0.8 で、
// 長辺を Y (rows 方向) に寝かせる。ポケットはカードより 1 大きい (片側 0.5)
card_w = 53.7;  // カードの短辺 (X)
card_d = 85.5;  // カードの長辺 (Y)
card_clear = 1; // ポケットの余裕 (user 指定「1mmずつ大きい」)
finger_w = 20;  // 指穴の X (横幅)
finger_d = 30;  // 指穴の Y (縦幅。手前から斜めに入る指のぶん長い)
card_r = 4;     // ポケットと指穴の平面の隅 R (user 指定)

function bin_contract(cols, rows, units) = str("CONTRACT units=",
                                               units,
                                               " pitch=",
                                               gf_pitch,
                                               " outer=",
                                               gfb_outer,
                                               " h=",
                                               units* gfb_unit,
                                               " lip=",
                                               gfb_lip_h,
                                               " base=",
                                               gfb_base_bot,
                                               "/",
                                               gfb_base_mid,
                                               "/",
                                               gfb_outer,
                                               " base_h=",
                                               gfb_base_h,
                                               " wall=",
                                               wall,
                                               " floor_top=",
                                               gfb_base_h + floor_t,
                                               " label=",
                                               label_d,
                                               "x",
                                               label_t,
                                               " wedge=45 fillet=",
                                               label_r,
                                               " bin=",
                                               cols,
                                               "x",
                                               rows,
                                               " size=",
                                               cols* gf_pitch - 0.5,
                                               "x",
                                               rows* gf_pitch - 0.5);

// (cols, rows, units) でラベル付き bin を払い出す。例: gridfinity_bin(2, 4, 4)
module
gridfinity_bin(cols, rows, units = 4)
{
    echo(bin_contract(cols, rows, units));
    gfb_bin(cols, rows, units, wall, floor_t, label_d, label_t, label_r);
}

function card_contract(cols, rows, units) = str("CONTRACT card units=",
                                                units,
                                                " bin=",
                                                cols,
                                                "x",
                                                rows,
                                                " size=",
                                                cols* gf_pitch - 0.5,
                                                "x",
                                                rows* gf_pitch - 0.5,
                                                " h=",
                                                units* gfb_unit,
                                                " lip=",
                                                gfb_lip_h,
                                                " floor_top=",
                                                gfb_base_h + floor_t,
                                                " card=",
                                                card_w,
                                                "x",
                                                card_d,
                                                " pocket=",
                                                card_w + card_clear,
                                                "x",
                                                card_d + card_clear,
                                                " finger=",
                                                finger_w,
                                                "x",
                                                finger_d,
                                                " r=",
                                                card_r,
                                                " center=",
                                                (rows * gf_pitch - 0.5) / 2);

// (cols, rows, units) でカードケースを払い出す。例: gridfinity_card_case(2, 3, 4)
module
gridfinity_card_case(cols, rows, units = 4)
{
    echo(card_contract(cols, rows, units));
    gfb_card_case(cols,
                  rows,
                  units,
                  wall,
                  floor_t,
                  [ card_w, card_d ],
                  card_clear,
                  [ finger_w, finger_d ],
                  card_r);
}
