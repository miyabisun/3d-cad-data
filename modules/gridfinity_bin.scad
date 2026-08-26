include <gridfinity.scad>

// Gridfinity bin (箱) の共有 module。ピッチと角丸は gridfinity.scad
// と共有する。 底の輪郭は Gridfinity 仕様の bin base (下から):
//   35.6 角 (R0.8) → 45° 0.8 → 37.2 角 (R1.6) → 垂直 1.8 → 45° 2.15 → 41.5 角
//   (R3.75) 高さ 0.8 + 1.8 + 2.15 = 4.75。磁石穴・ネジ穴は持たない (無垢)
// 外形はピッチ − 0.5 (1 マス 41.5)、角 R3.75。高さ単位 7 (4U = 28 が壁の上端)。
// リップは「薄いリップ」: 壁 (1.2) をそのまま lip_h (4.4) 伸ばし、内側の上端を
// 45° に落とすだけ。内側に棚 (厚い肉) を持たないので、上に載せる bin は底の
// 面取りをこの 45° に座らせる。
//
// 座標系: X が列方向 (中央 0)、Y が行方向 (手前 = ラベル側が 0)、Z=0 が底面。

gfb_outer = gf_pitch - 0.5; // 41.5
gfb_outer_r = 3.75;
gfb_base_bot = 35.6;
gfb_base_bot_r = 0.8;
gfb_base_mid = 37.2;
gfb_base_mid_r = 1.6;
gfb_base_chamfer_bot = 0.8;
gfb_base_wall_h = 1.8;
gfb_base_chamfer_top = 2.15;
gfb_base_h =
    gfb_base_chamfer_bot + gfb_base_wall_h + gfb_base_chamfer_top; // 4.75
gfb_unit = 7;
gfb_lip_h = 4.4;
gfb_lip_chamfer = 0.8;

// bin 1 マスぶんの底 (無垢)。z=0 が底面、gfb_base_h で外形 41.5 角に達する
module
gfb_base_cell()
{
    z1 = gfb_base_chamfer_bot;
    z2 = z1 + gfb_base_wall_h;
    z3 = gfb_base_h;
    hull()
    {
        gf_slab(gfb_base_bot, gfb_base_bot_r, 0);
        gf_slab(gfb_base_mid, gfb_base_mid_r, z1 - gf_eps);
    }
    hull()
    {
        gf_slab(gfb_base_mid, gfb_base_mid_r, z1 - gf_eps);
        gf_slab(gfb_base_mid, gfb_base_mid_r, z2 - gf_eps);
    }
    hull()
    {
        gf_slab(gfb_base_mid, gfb_base_mid_r, z2 - gf_eps);
        gf_slab(gfb_outer, gfb_outer_r, z3 - gf_eps);
    }
}

// cols x rows の角丸矩形 (外形)
module
gfb_footprint(cols, rows, inset = 0)
{
    w = cols * gf_pitch - 0.5 - 2 * inset;
    d = rows * gf_pitch - 0.5 - 2 * inset;
    translate([ 0, d / 2 + inset ])
        gf_rounded_square_wd(w, d, gfb_outer_r - inset);
}

// 幅 w × 奥行き d の角丸矩形 (中心が原点)
module
gf_rounded_square_wd(w, d, r)
{
    offset(r = r, $fn = gf_fn) square([ w - 2 * r, d - 2 * r ], center = true);
}

// bin 本体。units は高さ (U)。wall / floor_t は壁と床の厚さ。
// label_d > 0 なら手前 (y=0) の壁の上端 (z = units*7) と面一で内側へ label_d
// 張り出す厚さ label_t の棚を付け、裏に 45° のリブ (厚さ rib_t) を label_ribs
// 本 立てる
// (側壁から離し、内幅を等分した位置)。棚はリブの間と両端をブリッジで渡る。
module
gfb_bin(cols,
        rows,
        units = 4,
        wall = 1.2,
        floor_t = 1.2,
        label_d = 0,
        label_t = 1.6,
        rib_t = 1.2,
        label_ribs = 3)
{
    h = units * gfb_unit; // 壁の上端
    top = h + gfb_lip_h;  // リップの上端
    inner_w = cols * gf_pitch - 0.5 - 2 * wall;
    floor_top = gfb_base_h + floor_t;
    union()
    {
        // 底: マスごとの無垢の base
        for (c = [0:cols - 1], r = [0:rows - 1])
            translate([
                (c - (cols - 1) / 2) * gf_pitch,
                (r + 0.5) * gf_pitch - 0.25,
                0
            ]) gfb_base_cell();
        // 胴体: base の上から top
        // まで。内側は床の上を抜く。リップの内側の上端は 45°
        difference()
        {
            translate([ 0, 0, gfb_base_h - gf_eps ])
                linear_extrude(top - gfb_base_h + gf_eps)
                    gfb_footprint(cols, rows);
            translate([ 0, 0, floor_top ])
                linear_extrude(top - floor_top + gf_over)
                    gfb_footprint(cols, rows, wall);
            // リップ内側の面取り: 上端で wall − 0.4 まで開く
            hull()
            {
                translate([ 0, 0, top - gfb_lip_chamfer ])
                    linear_extrude(gf_eps) gfb_footprint(cols, rows, wall);
                translate([ 0, 0, top ]) linear_extrude(gf_over)
                    gfb_footprint(cols, rows, wall - gfb_lip_chamfer);
            }
        }
        // ラベル棚とリブ
        if (label_d > 0) {
            translate([ -inner_w / 2, wall - gf_eps, h - label_t ])
                cube([ inner_w, label_d + gf_eps, label_t ]);
            for (i = [0:label_ribs - 1]) {
                // リブは側壁から離して内幅を等分した位置に置く
                // (3 本なら内幅の 25% / 50% / 75%)
                x = -inner_w / 2 + inner_w * (i + 1) / (label_ribs + 1);
                translate([ x - rib_t / 2, wall - gf_eps, 0 ])
                    rotate([ 90, 0, 90 ]) linear_extrude(rib_t) polygon([
                        [ 0, h - label_t + gf_eps ],
                        [ label_d + gf_eps, h - label_t + gf_eps ],
                        [ 0, h - label_t - label_d ]
                    ]);
            }
        }
    }
}
