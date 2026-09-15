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

// bin 1 マスぶんの底 (無垢)。半セルは幅だけ21mm短縮し、角Rと面取りを保つ。
module
gfb_base_cell(pitch = [ gf_pitch, gf_pitch ])
{
    delta = pitch - [ gf_pitch, gf_pitch ];
    z1 = gfb_base_chamfer_bot;
    z2 = z1 + gfb_base_wall_h;
    z3 = gfb_base_h;
    hull()
    {
        gf_slab([ gfb_base_bot, gfb_base_bot ] + delta, gfb_base_bot_r, 0);
        gf_slab([ gfb_base_mid, gfb_base_mid ] + delta, gfb_base_mid_r, z1 - gf_eps);
    }
    hull()
    {
        gf_slab([ gfb_base_mid, gfb_base_mid ] + delta, gfb_base_mid_r, z1 - gf_eps);
        gf_slab([ gfb_base_mid, gfb_base_mid ] + delta, gfb_base_mid_r, z2 - gf_eps);
    }
    hull()
    {
        gf_slab([ gfb_base_mid, gfb_base_mid ] + delta, gfb_base_mid_r, z2 - gf_eps);
        gf_slab([ gfb_outer, gfb_outer ] + delta, gfb_outer_r, z3 - gf_eps);
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
    first = [ cols - ceil(cols) + 1, rows - ceil(rows) + 1 ] * gf_pitch;
    union()
    {
        // 端数の足を左/手前へ置き、残りは42mmピッチの標準の足にする。
        for (c = [0:ceil(cols) - 1], r = [0:ceil(rows) - 1])
            translate([
                -cols * gf_pitch / 2 +
                    (c == 0 ? first[0] / 2 : first[0] + (c - 0.5) * gf_pitch),
                (r == 0 ? first[1] / 2 : first[1] + (r - 0.5) * gf_pitch) - 0.25,
                0
            ]) gfb_base_cell([ c == 0 ? first[0] : gf_pitch,
                              r == 0 ? first[1] : gf_pitch ]);
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

// 底 1 マスぶんの窪み (くり抜き用の cut)。gfb_base_cell の 3 段の輪郭を、壁厚 wall
// だけ内側へ・床厚 floor_t だけ上へ寄せた相似形を、z = skin (窪みの床) で切り落とした
// もの。天面 (z = 底の高さ + floor_t = 床の天面) の隅は半径 r で、下るほど幅と同じ分
// だけ半径を減らして 45° を保つ (r を内壁と同じ 外形 R − wall にすると外形の平行
// オフセットになる)。天面は床の天面と一致するので、その上へ gf_over だけ同じ幅の
// 柱を伸ばして面の一致を避ける。各段は壁の内面との面の一致を避けるため gf_eps 小さい
module
gfb_recess(wall, floor_t, r, skin)
{
    inset = wall + gf_eps;
    w1 = gfb_base_bot - 2 * inset;
    w2 = gfb_base_mid - 2 * inset;
    w3 = gfb_outer - 2 * inset;
    z0 = floor_t;
    z1 = z0 + gfb_base_chamfer_bot;
    z2 = z1 + gfb_base_wall_h;
    z3 = z0 + gfb_base_h; // = 床の天面
    r2 = r - (w3 - w2) / 2;
    r1 = max(r - (w3 - w1) / 2, gf_eps);
    intersection()
    {
        union()
        {
            hull()
            {
                gf_slab(w1, r1, z0);
                gf_slab(w2, r2, z1 - gf_eps);
            }
            hull()
            {
                gf_slab(w2, r2, z1 - gf_eps);
                gf_slab(w2, r2, z2 - gf_eps);
            }
            hull()
            {
                gf_slab(w2, r2, z2 - gf_eps);
                gf_slab(w3, r, z3 - gf_eps);
            }
            translate([ 0, 0, z3 - gf_eps ]) linear_extrude(gf_over + gf_eps)
                gf_rounded_square(w3, r);
        }
        translate([ -gfb_outer, -gfb_outer, skin ])
            cube([ 2 * gfb_outer, 2 * gfb_outer, z3 + gf_over - skin ]);
    }
}

// カードケース。gfb_bin (ラベル無し) の内側を床の天面から壁の上端 (units*7) まで
// 無垢で埋め、そこから 2 つを抜く:
// - カード (card = [X, Y]、寝かせる) + clearance のポケット。X は中央、手前の壁の
//   内側から offset だけ奥に置く (offset は 0 より大きいこと: 壁に付けると隅の
//   円弧が壁面に接線で触れ、その STL を CGAL が projection で再読込できない)。
//   床は bin の床。平面の隅は半径 r (カードの隅と同じ R にして、隅で突っ掛から
//   ないようにする)。左右の埋めの天面は (内幅 − ポケット幅) / 2 の平面で、
//   ラベルを貼る帯になる
// - 右奥のマスの穴。埋めは壁の内面まで抜き (隅は hole_r = 内壁と同じ 外形 R − wall)、
//   床と底のマスは gfb_recess の窪みにする (外形に平行に 45° で下がり、床は z = skin)
// ポケットと穴は角で繋がり、カードの右奥の角が窪みの上に張り出すので、指をその下へ
// 入れて 1 枚目を掬える。リップはそのまま。
// ポケットと穴が交わる所には埋めの凸の縦エッジが 2 本できる (ポケットの右の辺 × 穴の
// 手前の辺、穴の左の辺 × ポケットの奥の辺)。指が痛くないよう、この縦エッジを半径
// edge_r で丸める: 抜く輪郭 (ポケット ∪ 穴) に閉演算 (offset +edge_r → −edge_r) を
// 掛けると、輪郭の凹の角だけが半径 edge_r の弧になり (= 埋めの凸の角が丸くなる)、
// 凸の角 (ポケットの隅 r、穴の隅 hole_r) は変わらない。壁は上端まで垂直のままなので
// カードの収まる枚数は減らない
module
gfb_card_case(cols,
              rows,
              units = 4,
              wall = 1.2,
              floor_t = 1.2,
              card = [ 54, 85.6 ],
              clearance = 1,
              offset = 10,
              r = 3,
              skin = 2.95,
              edge_r = 2)
{
    h = units * gfb_unit;
    floor_top = gfb_base_h + floor_t;
    inner_w = cols * gf_pitch - 0.5 - 2 * wall;
    inner_d = rows * gf_pitch - 0.5 - 2 * wall;
    pw = card[0] + clearance;
    pd = card[1] + clearance;
    hole_r = gfb_outer_r - wall;
    // 右奥のマスの中心と、そのマスの手前左の角 (埋めの穴の縁)
    cx = (cols - 1) / 2 * gf_pitch;
    cy = (rows - 0.5) * gf_pitch - 0.25;
    hx0 = cx - gfb_outer / 2;
    hy0 = cy - gfb_outer / 2;
    difference()
    {
        union()
        {
            gfb_bin(cols, rows, units, wall, floor_t);
            // 埋め: 壁へ gf_eps 食い込ませて胴体と溶かす。ポケットと穴は 2D で
            // 引く (交点の凹の角は閉演算で丸める)
            translate([ 0, 0, floor_top - gf_eps ])
                linear_extrude(h - floor_top + gf_eps) difference()
            {
                gfb_card_fill(cols, rows, wall);
                offset(r = -edge_r, $fn = gf_fn) offset(r = edge_r, $fn = gf_fn)
                {
                    gfb_card_pocket(wall, pw, pd, offset, r);
                    gfb_card_hole(inner_w, inner_d, wall, hx0, hy0, hole_r);
                }
            }
        }
        translate([ cx, cy, 0 ]) gfb_recess(wall, floor_t, hole_r, skin);
    }
}

// 埋めの輪郭: 壁の内面より gf_eps 外 (胴体と溶かす)
module
gfb_card_fill(cols, rows, wall)
{
    gfb_footprint(cols, rows, wall - gf_eps);
}

// ポケットの輪郭: X 中央、手前の壁の内面から offset 奥
module
gfb_card_pocket(wall, pw, pd, offset, r)
{
    translate([ 0, wall + offset + pd / 2 ]) gf_rounded_square_wd(pw, pd, r);
}

// 穴の輪郭: 右奥のマスの手前左の角 (hx0, hy0) から壁の内面まで。壁に接する辺は壁へ
// gf_eps だけ食い込ませる (面の一致と隅の円弧の接線接触を避ける)
module
gfb_card_hole(inner_w, inner_d, wall, hx0, hy0, hole_r)
{
    translate([
        (hx0 + inner_w / 2 + gf_eps) / 2,
        (hy0 + wall + inner_d + gf_eps) / 2
    ]) gf_rounded_square_wd(inner_w / 2 + gf_eps - hx0,
                            wall + inner_d + gf_eps - hy0,
                            hole_r);
}
