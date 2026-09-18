use <../../../modules/bolts.scad>

// X/Y=カップ中心、+Y=クランプ側、Z=印刷底面。上端はデスク上面。
inner_d = 84.6;
inner_h = 32.6;
wall = 2;
floor_t = 3;
floor_r = 2;
top_r = 1;
bottom_chamfer = 0.4;
drain_flat = 6;
drain_web = 2;
drain_rim = 3;
clamp_w = 24;
clamp_t = 3.8;
clamp_h = 28.1; // コの字の外高として計算。内高の実測なら上下板厚を加える。
clamp_clearance = 0.4; // 幅方向の総すきま
screw_flat = 8.4; // 上下が平らな六角の対辺
screw_length = 8; // 頭を除く軸長
head_d = 13.8;
head_h = 3;
head_flat_clearance = 0.4; // 頭径に加える対辺方向の総すきま
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
head_flat = head_d + head_flat_clearance;
head_seat_y = inner_r + head_h + head_clearance;
mount_y = head_seat_y + seat_t;
desk_y = mount_y + clamp_t;
mount_z = height + clamp_t - clamp_h / 2;
mount_start_y = sqrt(outer_r * outer_r - mount_w * mount_w / 4) - wall;

assert(inner_d > 0 && inner_h > 0 && wall > 0 && floor_t > 0);
assert(floor_r > 0 && floor_r < inner_r && 2 * top_r <= wall && top_r > 0);
assert(bottom_chamfer > 0 && bottom_chamfer < min(floor_t, top_r));
assert(floor_r + top_r < inner_h);
assert(drain_flat > 0 && drain_web > 0 && drain_rim >= floor_r);
assert(drain_r + drain_rim < inner_r);
assert(clamp_w > 0 && clamp_t > 0 && clamp_h > 2 * clamp_t);
assert(clamp_clearance >= 0 && head_flat_clearance >= 0 && head_clearance >= 0);
assert(tip_clearance > 0 && tip_clearance < clamp_t && seat_t >= wall);
assert(screw_flat > 0 && head_d > screw_flat && head_h > 0);
assert(mount_w < 2 * outer_r && slot_w > head_flat / cos(30) + 2 * wall);
assert(mount_z - head_flat / 2 > floor_t + floor_r);
assert(mount_z + head_flat / 2 < height - top_r);

// 円柱の外側を先に仕上げる。下は直線のC0.4、上はR1の円弧。
module edged_cylinder(r) {
  rotate_extrude() polygon(concat(
    [[0, 0], [r - bottom_chamfer, 0], [r, bottom_chamfer]],
    [for (a = [0:5:90]) [r - top_r + (a == 90 ? 0 : top_r * cos(a)),
                          height - top_r + top_r * sin(a)]],
    r > top_r ? [[0, height]] : []
  ));
}

// 四隅の丸め済み円柱を包み、四角柱の上R1・下C0.4も先に仕上げる。
module edged_box(x0, x1, y0, y1) {
  hull() for (x = [x0 + top_r, x1 - top_r], y = [y0 + top_r, y1 - top_r])
    translate([x, y]) edged_cylinder(top_r, $fn = 48);
}

difference() {
  union() {
    edged_cylinder(outer_r);
    edged_box(-mount_w / 2, mount_w / 2, mount_start_y, mount_y);
    for (sign = [-1, 1]) translate([sign * (slot_w + wall) / 2, 0])
      edged_box(-wall / 2, wall / 2, mount_start_y, desk_y);
  }
  // 底Z3から内壁Z5へR2、上の1mmは内径を広げてR1にする。
  rotate_extrude() polygon(concat(
    [[0, floor_t]],
    [for (a = [-90:5:0]) [inner_r - floor_r + floor_r * cos(a), floor_t + floor_r + floor_r * sin(a)]],
    [for (a = [180:-5:90]) [inner_r + top_r + top_r * cos(a), height - top_r + top_r * sin(a)]],
    [[inner_r + top_r, height + eps], [0, height + eps]]
  ));
  // 上下flatの六角穴。大径の座面から先を小径の通し穴にする。
  translate([0, head_seat_y / 2, mount_z]) rotate([-90, 0, 0])
    hex_hole(head_flat, head_seat_y);
  translate([0, head_seat_y + seat_t / 2, mount_z]) rotate([-90, 0, 0])
    hex_hole(screw_flat, seat_t + 2 * eps);
  translate([0, 0, -eps]) linear_extrude(height = floor_t + 2 * eps)
    for (col = [-cells:cells], row = [-cells:cells]) {
      x = col * pitch * sqrt(3) / 2;
      y = (row + col / 2) * pitch;
      if (norm([x, y]) + drain_r <= inner_r - drain_rim)
        translate([x, y]) circle(r = drain_r, $fn = 6);
    }
}
