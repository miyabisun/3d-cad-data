include <gridfinity_bin.scad>

// assets/gridfinity-bin/ の 4U bin 群の共通値。単体では何も描かない。
// 設計の経緯と確定値は ledger/designs/gridfinity-bin-4u.md が正本。
units = 4; // 高さ 4U = 28 (壁の上端)。リップ 4.4 を足して全高 32.4
wall = 1.2;    // 0.4 ノズル 3 本
floor_t = 1.2; // 底 (4.75) の上に載せる床。床の天面 z = 5.95
label_d = 13;  // 12mm 幅のラベルシールを貼る棚の張り出し
label_t = 1.6; // 棚の厚さ (ブリッジで渡るので 4 層)
rib_t = 2;     // 棚を支える 45° リブの厚さ (user 指定)
label_ribs = 3; // リブの本数。内幅の 25% / 50% / 75% に置く (user 指定)

function bin_contract(cols, rows) = str("CONTRACT units=",
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
                                        " ribs=",
                                        label_ribs,
                                        "x",
                                        rib_t,
                                        " bin=",
                                        cols,
                                        "x",
                                        rows,
                                        " size=",
                                        cols* gf_pitch - 0.5,
                                        "x",
                                        rows* gf_pitch - 0.5);

module
bin_4u(cols, rows)
{
    echo(bin_contract(cols, rows));
    gfb_bin(
        cols, rows, units, wall, floor_t, label_d, label_t, rib_t, label_ribs);
}
