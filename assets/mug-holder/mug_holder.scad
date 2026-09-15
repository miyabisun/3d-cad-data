// X/Y=カップ中心、+Y=クランプ側、Z=印刷底面。上端はデスク上面。
inner_d = 83.6;
inner_h = 32.6;
wall = 2;
floor_t = 2;
drain_flat = 6;
drain_web = 2;
drain_rim = 3;
clamp_w = 24;
clamp_t = 3.8;
clamp_h = 28.1; // コの字の外高として計算。内高の実測なら上下板厚を加える。
clamp_clearance = 0.4; // 幅方向の総すきま
screw_d = 7.8;
screw_length = 8; // 頭を除く軸長
head_d = 13.8;
head_h = 3;
hole_clearance = 0.6; // 直径方向の総すきま
head_clearance = 0.2; // 頭を収納内径の外へ沈める量
tip_clearance = 0.2; // デスク側に残すネジ先端の逃げ
$fn = 180;
eps = 0.05;

inner_r = inner_d / 2;
outer_r = inner_r + wall;
height = floor_t + inner_h;
drain_r = drain_flat / sqrt(3);
pitch = drain_flat + drain_web;
cells = ceil(2 * inner_r / pitch);
slot_w = clamp_w + clamp_clearance;
mount_w = slot_w + 2 * wall;
seat_t = screw_length - clamp_t + tip_clearance;
head_seat_y = inner_r + head_h + head_clearance;
mount_y = head_seat_y + seat_t;
desk_y = mount_y + clamp_t;
mount_z = height + clamp_t - clamp_h / 2;
// 取付座と円筒が幅全体で重なる位置から押し出す。
mount_start_y = sqrt(outer_r * outer_r - mount_w * mount_w / 4) - wall;

assert(inner_d > 0 && inner_h > 0 && wall > 0 && floor_t > 0);
assert(drain_flat > 0 && drain_web > 0 && drain_rim > 0);
assert(drain_r + drain_rim < inner_r);
assert(clamp_w > 0 && clamp_t > 0 && clamp_h > 2 * clamp_t);
assert(clamp_clearance >= 0 && hole_clearance >= 0 && head_clearance >= 0);
assert(tip_clearance > 0 && tip_clearance < clamp_t && seat_t >= wall);
assert(screw_d > 0 && head_d > screw_d && head_h > 0);
assert(mount_w < 2 * outer_r && slot_w > head_d + hole_clearance + 2 * wall);
assert(mount_z - (head_d + hole_clearance) / 2 > floor_t);
assert(mount_z + (head_d + hole_clearance) / 2 < height);

difference() {
  linear_extrude(height = height) difference() {
    union() {
      circle(r = outer_r);
      translate([-mount_w / 2, mount_start_y]) square([mount_w, desk_y - mount_start_y]);
    }
    translate([-slot_w / 2, mount_y]) square([slot_w, clamp_t + eps]);
  }
  translate([0, 0, floor_t]) cylinder(r = inner_r, h = inner_h + eps);
  // 座面まで大径、座面からクランプへ小径。頭はカップの内径に出ない。
  translate([0, 0, mount_z]) rotate([-90, 0, 0])
    cylinder(d = head_d + hole_clearance, h = head_seat_y);
  translate([0, head_seat_y - eps, mount_z]) rotate([-90, 0, 0])
    cylinder(d = screw_d + hole_clearance, h = seat_t + 2 * eps);
  translate([0, 0, -eps]) linear_extrude(height = floor_t + 2 * eps)
    for (col = [-cells:cells], row = [-cells:cells]) {
      x = col * pitch * sqrt(3) / 2;
      y = (row + col / 2) * pitch;
      // 六角全体が外周の無垢帯に入らないものだけを抜く。
      if (norm([x, y]) + drain_r <= inner_r - drain_rim)
        translate([x, y]) circle(r = drain_r, $fn = 6);
    }
}
