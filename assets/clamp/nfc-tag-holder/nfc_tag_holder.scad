use <../../../modules/bolts.scad>

// X/Y=M8穴の中心、Z=0は印刷底面 (=クランプ天板の上面)。天面にΦ25のNFCタグを貼る。
d = 28;
chamfer = 1; // 上下とも45度の直線
clamp_t = 4; // クランプ天板の厚さ
screw_length = 7.9; // 頭を除く軸長の実測
head_d = 13.8; // 平たい頭の直径
head_h = 3;
head_clearance = 0.4; // 頭径に加える総すきま
tag_d = 25;
$fn = 180;
eps = 0.05;

seat_t = round(screw_length) - clamp_t; // 頭の座面から天板までの樹脂厚
height = seat_t + head_h; // 頭の上面が天面と揃う

assert(screw_length - seat_t <= clamp_t, "ネジ先端が天板の下へ出る");
assert(tag_d <= d - 2 * chamfer, "タグが面取りに掛かる");
assert(head_d + head_clearance < d - 2 * chamfer);
assert(2 * chamfer < height);

difference() {
  rotate_extrude() polygon([
    [0, 0], [d / 2 - chamfer, 0], [d / 2, chamfer],
    [d / 2, height - chamfer], [d / 2 - chamfer, height], [0, height]
  ]);
  translate([0, 0, -eps]) m8_bolt_hole(height + 2 * eps);
  translate([0, 0, seat_t])
    cylinder(d = head_d + head_clearance, h = head_h + eps);
}
