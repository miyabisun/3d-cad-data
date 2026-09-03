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

// ラベル天板の Y-Z 断面 (y = 壁の内面からの距離、z = 高さ)。天板 (厚さ t) の
// 先端から 45° の斜面が壁まで下りる無垢のくさび。先端の垂直面と斜面の境目
// (135°) を半径 r で丸める: 円弧の中心は先端の角から (-r, r·tan22.5°)、接点は
// 垂直面上の角 + (0, r·tan22.5°) と斜面上の角 + 0.4142r·(-1,-1)。壁の内側へ
// 1 だけ食い込ませて胴体と溶かす
function gfb_label_profile(d, t, h, r) =
    let(y0 = d, z0 = h - t, cy = y0 - r, cz = z0 + r * tan(22.5))
        concat([ [ -1, h ], [ d, h ] ],
               [for (a = [0:-5:-45])[cy + r * cos(a), cz + r* sin(a)]],
               [[ -1, h - t - d - 1 ]]);

// bin 本体。units は高さ (U)。wall / floor_t は壁と床の厚さ。
// label_d > 0 なら手前 (y=0) の壁の上端 (z = units*7) と面一で内側へ label_d
// 張り出す厚さ label_t のラベル天板を付ける。天板の下は 45° の無垢のくさびが
// 壁まで下りる (ブリッジもリブも無い。中身はスライサのインフィル任せ)。
// 天板の先端と 45° 面の境目は半径 label_r で丸める
module
gfb_bin(cols,
        rows,
        units = 4,
        wall = 1.2,
        floor_t = 1.2,
        label_d = 0,
        label_t = 1,
        label_r = 1)
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
        // ラベル天板と 45° くさび (内幅いっぱい、同じ断面)。壁へ 1 食い込ませた
        // 矩形の柱なので、角の丸み (R3.75) の外へ出ないよう外形で切り取る
        if (label_d > 0)
            intersection()
            {
                translate([ -inner_w / 2, wall, 0 ]) rotate([ 90, 0, 90 ])
                    linear_extrude(inner_w) polygon(
                        gfb_label_profile(label_d, label_t, h, label_r));
                linear_extrude(top) gfb_footprint(cols, rows);
            }
    }
}

// カードケース。gfb_bin (ラベル無し) の内側を床の天面から壁の上端 (units*7)
// まで無垢で埋め、中央にカード (card = [X, Y]、寝かせる) + clearance のポケットを
// 床の天面から上へ抜き、その中心に finger = [X, Y] の指穴を底まで貫通させる
// (指が床より下、ベースプレートのソケットの底まで届く)。ポケットと指穴の平面の
// 隅は半径 r。リップ (壁の上端から上) はそのまま残す
module
gfb_card_case(cols,
              rows,
              units = 4,
              wall = 1.2,
              floor_t = 1.2,
              card = [ 53.7, 85.5 ],
              clearance = 1,
              finger = [ 20, 30 ],
              r = 4)
{
    h = units * gfb_unit;
    top = h + gfb_lip_h;
    floor_top = gfb_base_h + floor_t;
    cy = (rows * gf_pitch - 0.5) / 2;
    difference()
    {
        union()
        {
            gfb_bin(cols, rows, units, wall, floor_t);
            // 埋め: 壁へ gf_eps 食い込ませて胴体と溶かす
            translate([ 0, 0, floor_top - gf_eps ])
                linear_extrude(h - floor_top + gf_eps)
                    gfb_footprint(cols, rows, wall - gf_eps);
        }
        translate([ 0, cy, floor_top ]) linear_extrude(top - floor_top + gf_over)
            gf_rounded_square_wd(card[0] + clearance, card[1] + clearance, r);
        translate([ 0, cy, -gf_over ]) linear_extrude(top + 2 * gf_over)
            gf_rounded_square_wd(finger[0], finger[1], r);
    }
}
