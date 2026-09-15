include <gridfinity_bin.scad>

// assets/gridfinity-bin/ の bin 群の共通値と、サイズ 3 引数の払い出し口。
// 単体では何も描かない。設計の経緯と確定値は
// ledger/designs/gridfinity-bin-4u.md が正本。
// 通常binは4U/9U、X={1,1.5,2,2.5,3} × Y={1,2,3,4,5,5.5}。
// 両軸に端数を持つ組み合わせはassetに置かない（各高さ28種）。
// Xが横、Yがラベルの壁から奥、unitsが高さ（7mm単位）。
wall = 1.2;    // 0.4 ノズル 3 本
floor_t = 1.2; // 底 (4.75) の上に載せる床。床の天面 z = 5.95
label_d = 13;  // 12mm 幅のラベルシールを貼る天板の張り出し
label_t = 1; // 天板の厚さ (user 指定)。下は 45° の無垢のくさび
label_r = 1; // 天板の先端と 45° 面の境目の R (user 指定)
// カードケース (goods/card_case_2x3x4u.scad) の値。カードは ISO/IEC 7810 ID-1 (85.6 × 54 ×
// 0.76、隅 R3) で、長辺を Y (rows 方向) に寝かせ、X 中央・手前の壁から 10 奥に置く。ポケットは
// カードより 1 大きい (片側 0.5)。右奥のマスは壁の内面まで抜き、床と底を外形に平行な 45° の窪みにする。
// ポケットの左右の埋めの天面 (幅 13.05) が 12mm のラベルを貼る帯。ポケットと穴の交点の
// 縦エッジは丸める (開口の上縁は丸めない: 壁を上端まで垂直に保ち、収まる枚数を減らさない)
card_w = 54;    // カードの短辺 (X)。user 指定「高さ 54」
card_d = 85.6;  // カードの長辺 (Y)。user 指定「幅 85.6」
card_clear = 1; // ポケットの余裕 (user 指定「+1mm」)
// ポケットの手前の辺の、手前の壁の内面からの距離 (user 指定「10mm」)
card_off = 10;
// ポケットの平面の隅 R (user 指定「角の丸み 3mm」。ID-1 の隅は 2.88..3.48)
card_r = 3;
// ポケットと穴が交わる所の、埋めの凸の縦エッジの R (指の当たる角)
card_edge_r = 2;
recess_skin = floor_t + 1.75; // 窪みの床 z (底の皮)。user 指定「壁厚と同じ 1.2 は過剰、1.75 返す」

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
                                                " at=",
                                                -(card_w + card_clear) / 2,
                                                ",",
                                                wall + card_off,
                                                " hole=",
                                                (cols - 1) / 2 * gf_pitch - gfb_outer / 2,
                                                ",",
                                                (rows - 0.5) * gf_pitch - 0.25 - gfb_outer / 2,
                                                " hole_r=",
                                                gfb_outer_r - wall,
                                                " recess=",
                                                gfb_outer - 2 * wall,
                                                "/",
                                                gfb_base_mid - 2 * wall,
                                                " recess_floor=",
                                                recess_skin,
                                                " r=",
                                                card_r,
                                                " edge_r=",
                                                card_edge_r);

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
                  card_off,
                  card_r,
                  recess_skin,
                  card_edge_r);
}
