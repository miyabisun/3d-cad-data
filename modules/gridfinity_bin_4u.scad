include <gridfinity_bin.scad>

// assets/gridfinity-bin/ の bin 群の共通値と、サイズ 3 引数の払い出し口。
// 単体では何も描かない。設計の経緯と確定値は
// ledger/designs/gridfinity-bin-4u.md が正本。 保証する範囲は cols 1..5 ×
// rows 1..5 × units 4 (assets に並ぶ 25 種)。 cols が X (横)、rows が Y
// (ラベルの壁から奥へ)、units が高さ (7mm 単位)。
wall = 1.2;    // 0.4 ノズル 3 本
floor_t = 1.2; // 底 (4.75) の上に載せる床。床の天面 z = 5.95
label_d = 13;  // 12mm 幅のラベルシールを貼る天板の張り出し
label_t = 1; // 天板の厚さ (user 指定)。下は 45° の無垢のくさび
label_r = 1; // 天板の先端と 45° 面の境目の R (user 指定)

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
