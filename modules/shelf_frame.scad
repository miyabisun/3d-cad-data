use <bolts.scad>
use <slide_rail_outer_bracket.scad>

// 30cm材（北島カラーアングル30型）の枠でオープンフレームケースを受ける棚。
// 座標: 原点は手前左の柱（90cm材）の内側2面の交点。+X = ラック右、+Y = 奥、
// Z = 0 は30cm材の下面。柱の内角どうしは500×400（アクリル板と同じ）。
// 30cm材は9.1mm面を外（縦）、7.7mm面を下にし、外面を柱の内面にそろえて各辺の中央に置く。
// 後ろ側は手前の部品を180度回して使う。右用は左用の鏡像。

rack = [ 500, 400 ];
case_size = [ 430, 240 ];

angle = 30; // 30cm材の断面外寸
angle_t = 2;
slot_len = 30;
slot_w = 7;
slot_pitch = 50; // 長穴30 + 穴間20
slot_count = 6;
end_margin = [ 7.3, 7.7 ]; // 材端→最初の長穴。両端で異なる
// 長穴の縁は各面の自由端から: 外（縦）面9.1、下面7.7。
outer_slot_z = angle - 9.1 - slot_w / 2;  // 17.4
bottom_slot_y = angle - 7.7 - slot_w / 2; // 18.8
column_slot = 29.2 - 2 - 8 - 7 / 2;       // 90cm材: 内側基準15.7

bolt_d = 6;
bolt_shift = slot_len / 2 - bolt_d / 2; // 長穴の両端へ当てる: 中心±12
gap_bolt = (slot_pitch - slot_len) / 2 + bolt_d / 2; // 穴間20を挟む: 中心±13
m6_pass_flat = 6.4;
m6_nut_flat = 10.4;
m6_nut_depth = 5.4;
m6_seat = 4.6; // M6×12: 板厚2 + 座面4.6 + ナット5
m6_tip = 4;    // ナット溝の奥でボルト先端を逃がす長さ
m6_nut_diag = m6_nut_flat / cos(30);

margin = 6;       // ナット経路の縁→部品端
gap_clear = 1;    // 30cm材の端との隙間
z_clear = 0.3;    // 30cm材の下面との隙間
side_clear = 0.3; // 下面に置く部品と縦面との隙間
bend = 3;         // 曲げ内Rの逃げ（45度）
corner_r = 2;
fillet_r = 10;
arm_w = 20; // 角の腕の幅。柱間に460を空け、ケースの横から金具を留める余地を残す

base_t = 10; // 筋交い・辺の支えの土台
base_top = angle_t + base_t;
post = 20;
post_inset = 2;   // ケース外周から柱の面まで
post_top = angle; // 30cm材の上端にそろえる
brace_w = 20;

case_min = (rack - case_size) / 2; // [35, 80]

// 辺の長さ edge の中央へ置いた30cm材の i 番目の長穴の中心
function slot_center(edge, i) = edge / 2 +
                                (i - (slot_count - 1) / 2) * slot_pitch;

corner_bolts = [
    [for (s = [ -1, 1 ]) slot_center(rack[0], 0) + s * bolt_shift],
    [for (s = [ -1, 1 ]) slot_center(rack[1], 0) + s * bolt_shift]
]; // [113,137], [63,87]
// 腕の端: flat-upのナット溝は長手方向に対角で広がる
arm_end =
    [for (b = corner_bolts) b[1] + m6_nut_diag / 2 + margin]; // [149.0, 99.0]
gap_end = [for (e = rack) slot_center(e, 0) - slot_len / 2 - max(end_margin) -
    gap_clear]; // [101.3, 51.3]
brace_bolts = [
    [for (s = [ -1, 1 ]) slot_center(rack[0], 1) + s * bolt_shift],
    [for (s = [ -1, 1 ]) slot_center(rack[1], 1) + s * bolt_shift]
]; // [163,187], [113,137]
brace_pad = [for (b = brace_bolts)[b[0] - m6_nut_flat / 2 - margin,
                                   b[1] + m6_nut_flat / 2 + margin]];

// 面 y = y0 から +Y へ刺す
// M6。通しもナットもflat-up。ナットは上面まで抜けた溝へ落とし、
// 六角の下半分の受けに座らせる
module
m6_y_with_channel(x, y0, z, top)
{
    translate([ x, y0 + m6_seat / 2, z ])
        hex_y_flat_up(m6_pass_flat, m6_seat + 0.2);
    translate([ x, y0 + m6_seat + m6_nut_depth + m6_tip / 2 - 0.1, z ])
        hex_y_flat_up(m6_pass_flat, m6_tip + 0.2);
    hull() for (zz = [ z, top + 1 ])
        translate([ x, y0 + m6_seat + m6_nut_depth / 2, zz ])
            hex_y_flat_up(m6_nut_flat, m6_nut_depth);
}

// 下面の長穴から上へ刺す M6。ナットは上から窪みへ入れる。
// 窪みの二面は材の長手と直交させる（along_x: X方向の材）
module
m6_z_with_well(x, y, along_x)
{
    translate([ x, y, angle_t - 0.1 ])
        cylinder(d = m6_pass_flat, h = m6_seat + 0.2, $fn = 48);
    translate([ x, y, angle_t + m6_seat ]) rotate(along_x ? 90 : 0)
        nut_trap(m6_nut_flat, base_t, center = false);
}

// X方向の30cm材が占める空間（x >= x0）。縦面・下面と曲げRの逃げ
module
angle_envelope_x(x0, x1)
{
    translate([ x0, 0, 0 ]) rotate([ 90, 0, 90 ])
        linear_extrude(x1 - x0) union()
    {
        translate([ -1, -1 ]) square([ angle_t + 1, angle + 2 ]);
        translate([ -1, -1 ]) square([ angle + 2, angle_t + z_clear + 1 ]);
        polygon([[angle_t - 0.01, angle_t - 0.01],
                 [angle_t + bend, angle_t - 0.01],
                 [angle_t - 0.01, angle_t + bend]]);
    }
}

// 下面に置く部品の、縦面側の下角を曲げRの分だけ落とす（X方向の材）
module
bend_relief_x(x0, x1)
{
    translate([ x0, 0, 0 ]) rotate([ 90, 0, 90 ]) linear_extrude(x1 - x0)
        polygon([
            [ -1, -1 ],
            [ angle_t + bend, -1 ],
            [ angle_t + bend, angle_t ],
            [ angle_t, angle_t + bend ],
            [ -1, angle_t + bend ]
        ]);
}

module
corner_footprint()
{
    offset(r = corner_r, $fn = 64) offset(delta = -corner_r) union()
    {
        square([ arm_end[0], arm_w ]);
        square([ arm_w, arm_end[1] ]);
        translate([ arm_w, arm_w ]) difference()
        {
            square(fillet_r);
            translate([ fillet_r, fillet_r ]) circle(r = fillet_r, $fn = 64);
        }
    }
}

// 角: 幅20×高さ30の腕をL字に組み、柱の2面へM6各1本、
// 30cm材の縦面の1番目の長穴へ両端に当てるM6を2本ずつ。
// 使用時の向き。印刷は上面をビルドプレートへ置く（shelf_frame_corner_print）
module
shelf_frame_corner()
{
    assert(gap_end[1] > arm_w + fillet_r, "corner gap is too short");
    difference()
    {
        linear_extrude(angle) corner_footprint();
        angle_envelope_x(gap_end[0], arm_end[0] + 1);
        mirror([ 1, -1, 0 ]) angle_envelope_x(gap_end[1], arm_end[1] + 1);

        m6_y_with_channel(column_slot, 0, angle / 2, angle);
        mirror([ 1, -1, 0 ])
            m6_y_with_channel(column_slot, 0, angle / 2, angle);
        for (x = corner_bolts[0])
            m6_y_with_channel(x, angle_t, outer_slot_z, angle);
        for (y = corner_bolts[1])
            mirror([ 1, -1, 0 ])
                m6_y_with_channel(y, angle_t, outer_slot_z, angle);
    }
}

module
shelf_frame_corner_print(mirrored = false)
{
    mirror([ mirrored ? 1 : 0, 0, 0 ]) translate([ 0, 0, angle ])
        rotate([ 180, 0, 0 ]) shelf_frame_corner();
}

// 土台の上に20×20の柱を立て、柱の頂部を30cm材の上端にそろえる
module
post_on_base()
{
    translate([ 0, 0, angle_t ]) linear_extrude(base_t) children(0);
    translate([ 0, 0, base_top - 0.01 ])
        linear_extrude(post_top - base_top + 0.01) children(1);
}

module
post_2d(origin)
{
    translate(origin) offset(r = corner_r, $fn = 64) offset(delta = -corner_r)
        square(post);
}

// 下面の長穴に置く台座（X方向の材）。縦面から side_clear 離す
module
pad_x_2d(x0, x1)
{
    translate([ x0, angle_t + side_clear ])
        square([ x1 - x0, angle - angle_t - side_clear ]);
}

// 筋交い: 手前の材と左の材の下面、2番目の長穴へ両端に当てるM6を2本ずつ。
// 角の腕の端で30cm材の内縁にあたる点から1mm離して30度で渡し、ケースの角を柱で受ける
corner_post = case_min + [ post_inset, post_inset ]; // [37, 82]
c1 = [ arm_end[0], angle ];
c2 = [ angle, arm_end[1] ];
brace_dir = (c2 - c1) / norm(c2 - c1);
brace_n = [ -brace_dir[1], brace_dir[0] ] *
          (brace_dir[0] < 0 ? -1 : 1); // 原点から離れる向き
brace_off = gap_clear + brace_w / 2;
brace_p = c1 + brace_n * brace_off;
// 中心線が手前の材の長穴線 (y = bottom_slot_y) と左の材の長穴線 (x =
// bottom_slot_y) に達する点
brace_e1 = brace_p + brace_dir * ((bottom_slot_y - brace_p[1]) / brace_dir[1]);
brace_e2 = brace_p + brace_dir * ((bottom_slot_y - brace_p[0]) / brace_dir[0]);

module
brace_strip_2d()
{
    l = norm(brace_e2 - brace_e1);
    translate(brace_e1) rotate(atan2(brace_dir[1], brace_dir[0]))
        translate([ 0, -brace_w / 2 ]) square([ l, brace_w ]);
}

module
shelf_frame_brace()
{
    assert(arm_end[0] < brace_pad[0][0] && arm_end[1] < brace_pad[1][0],
           "brace pad overlaps the corner arm");
    // 帯の両端の角が台座の中に収まる
    for (p = [
             brace_e1 + brace_n * brace_w / 2,
             brace_e1 - brace_n * brace_w / 2
         ])
        assert(p[0] > brace_pad[0][0] && p[0] < brace_pad[0][1] &&
                   p[1] > angle_t + side_clear && p[1] < angle,
               "brace misses the front pad");
    for (p = [
             brace_e2 + brace_n * brace_w / 2,
             brace_e2 - brace_n * brace_w / 2
         ])
        assert(p[1] > brace_pad[1][0] && p[1] < brace_pad[1][1] &&
                   p[0] > angle_t + side_clear && p[0] < angle,
               "brace misses the side pad");
    difference()
    {
        post_on_base()
        {
            offset(r = corner_r, $fn = 64) offset(delta = -corner_r)
                offset(r = -5, $fn = 64) offset(delta = 5) union()
            {
                pad_x_2d(brace_pad[0][0], brace_pad[0][1]);
                mirror([ 1, -1 ]) pad_x_2d(brace_pad[1][0], brace_pad[1][1]);
                brace_strip_2d();
                translate(corner_post) square(post);
            }
            post_2d(corner_post);
        }
        bend_relief_x(brace_pad[0][0] - 1, brace_pad[0][1] + 1);
        mirror([ 1, -1, 0 ])
            bend_relief_x(brace_pad[1][0] - 1, brace_pad[1][1] + 1);
        for (x = brace_bolts[0])
            m6_z_with_well(x, bottom_slot_y, true);
        for (y = brace_bolts[1])
            m6_z_with_well(bottom_slot_y, y, false);
    }
}

// 辺の支え:
// 材の中央、穴間20の金属を両側のM6で挟み、内側へ伸ばした先の柱でケースの辺を受ける。
// 手前用は X 方向の材、左右用はその X/Y 入替。中心 center、柱の外面までの距離
// reach
module
mid_support_x(center, reach)
{
    pad = [
        center - gap_bolt - m6_nut_flat / 2 - margin,
        center + gap_bolt + m6_nut_flat / 2 +
        margin
    ];
    origin = [ center - post / 2, reach ];
    difference()
    {
        post_on_base()
        {
            offset(r = corner_r, $fn = 64) offset(delta = -corner_r) hull()
            {
                pad_x_2d(pad[0], pad[1]);
                translate(origin) square(post);
            }
            post_2d(origin);
        }
        bend_relief_x(pad[0] - 1, pad[1] + 1);
    }
}

module
shelf_frame_mid_front()
{
    center = rack[0] / 2;
    difference()
    {
        mid_support_x(center, case_min[1] + post_inset);
        for (s = [ -1, 1 ])
            m6_z_with_well(center + s * gap_bolt, bottom_slot_y, true);
    }
}

module
shelf_frame_mid_side()
{
    center = rack[1] / 2;
    difference()
    {
        mirror([ 1, -1, 0 ]) mid_support_x(center, case_min[0] + post_inset);
        for (s = [ -1, 1 ])
            m6_z_with_well(bottom_slot_y, center + s * gap_bolt, false);
    }
}

// 下面に置く部品の印刷: 土台の下面をビルドプレートへ
module
shelf_frame_flat_print(mirrored = false)
{
    mirror([ mirrored ? 1 : 0, 0, 0 ]) translate([ 0, 0, -angle_t ]) children();
}
