use <../../modules/bolts.scad>

// X=左右中心、Y=内側前端(工具側)、+Y=クランプ側、Z=底面。
charger_w = 69.2;
charger_d = 30.8;
charger_h = 73.6;
clearance = 1; // 幅・奥行きそれぞれの総クリアランス
inner_r = 4;
wall = 3;
mount_wall = 4;
floor_t = 3;

mount_pitch = 40;
mount_from_top = 15; // 未実測の仮値。穴中心から上端まで
screw_flat = 6.4;
head_flat = 12.4; // 皿頭未実測の仮値 (対辺)
head_depth = 3;
driver_flat = 8.5;

jack_w = 17;
jack_d = 9;
jack_front = 11;
jack_back = 9.5;
jack_margin = 2; // 四方へそれぞれ追加
jack_r = 2;
arc_fn = 64;
eps = 0.05;

inner_w = charger_w + clearance;
inner_d = charger_d + clearance;
height = charger_h + floor_t;
mount_z = height - mount_from_top;
// 両側の測定から推定した中心を平均し、前側のクリアランス半分を加える。
jack_y = (jack_front + jack_d / 2 + charger_d - jack_back - jack_d / 2) / 2 + clearance / 2;
head_slope = (head_flat - screw_flat) / head_depth;

module cavity_2d() {
  translate([-inner_w / 2 + inner_r, inner_r])
    offset(r = inner_r, $fn = arc_fn)
      square([inner_w - 2 * inner_r, inner_d - 2 * inner_r]);
}

module outline_2d() {
  offset(r = wall, $fn = arc_fn) hull() {
    cavity_2d();
    translate([0, mount_wall - wall]) cavity_2d();
  }
}

// 軸は+Y。開始面の対辺aから、長さhで対辺bへ絞る。
module hex_taper_y(a, b, h) {
  rotate([-90, 0, 0]) linear_extrude(height = h, scale = b / a)
    circle(d = a / cos(30), $fn = 6);
}

module lx_charger_holder() {
  assert(mount_wall >= wall && head_depth > 0 && head_depth < mount_wall);
  assert(head_flat > screw_flat && driver_flat > 6.35 / cos(30));
  assert(mount_from_top > max(head_flat, driver_flat) / 2);
  assert(mount_z - max(head_flat, driver_flat) / 2 > floor_t);
  difference() {
    linear_extrude(height = height) outline_2d();
    translate([0, 0, floor_t]) linear_extrude(height = charger_h + eps) cavity_2d();

    // 底穴は21×13の角丸矩形。くびれを作らずプラグの通り道を確保する。
    translate([-jack_w / 2 - jack_margin + jack_r,
               jack_y - jack_d / 2 - jack_margin + jack_r, -eps])
      linear_extrude(height = floor_t + 2 * eps)
        offset(r = jack_r, $fn = arc_fn)
          square([jack_w + 2 * jack_margin - 2 * jack_r,
                  jack_d + 2 * jack_margin - 2 * jack_r]);

    for (x = [-mount_pitch / 2, mount_pitch / 2]) {
      translate([x, inner_d + mount_wall / 2, mount_z])
        rotate([-90, 0, 0]) hex_hole(screw_flat, mount_wall + 2 * eps);
      // 皿座は充電器側の面。クランプ接触面側は通し穴のまま1mm残す。
      translate([x, inner_d - eps, mount_z])
        hex_taper_y(head_flat + eps * head_slope, screw_flat, head_depth + eps);
      translate([x, -wall / 2, mount_z])
        rotate([-90, 0, 0]) hex_hole(driver_flat, wall + 2 * eps);
    }
  }
}

echo(str("CONTRACT lx_holder: inner = ", [inner_w, inner_d, charger_h]));
echo(str("CONTRACT lx_holder: mount = ", [mount_pitch, screw_flat, mount_z]));
echo(str("CONTRACT lx_holder: jack = ", [jack_w + 2 * jack_margin, jack_d + 2 * jack_margin, jack_y]));
lx_charger_holder();
