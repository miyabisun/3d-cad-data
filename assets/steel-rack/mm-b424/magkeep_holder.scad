// print: 側面をZ=0へ置く。mounted: X=左右、Y=手前、Z=上。
part = "print";
tilt_deg = 20; // 直立0度。正なら上端が棚側、下端が手前。
slit_width = 5;
slit_height = 22;
face_size = 64;
wall = 4;
chamfer = 1;

assert(part == "print" || part == "mounted");
assert(tilt_deg >= 0 && tilt_deg <= 45, "tilt_deg must be 0..45");
assert(slit_width > 0 && slit_height > 0 && wall > 0);
assert(face_size >= 61 && slit_height < face_size * cos(tilt_deg));
assert(chamfer >= 0 && 2 * chamfer < wall && face_size - 2 * chamfer >= 61);

// 断面の座標は[手前, 上]。スリットの天井が高さ0、開口端が-slit_height。
top = [2 * wall, wall];
bottom = top + face_size * [sin(tilt_deg), -cos(tilt_deg)];
back_bottom = bottom - wall * [cos(tilt_deg), sin(tilt_deg)];

// 局所座標の角から各軸1mm、45度の切断線。範囲外まで延ばす。
module bevel_cut(point, angle) {
  reach = 2 * (face_size + slit_height + slit_width + wall);
  translate(point) rotate(angle)
    polygon([[-reach, reach - chamfer], [reach, reach], [reach, -reach - chamfer]]);
}

module holder() {
  linear_extrude(height = face_size) difference() {
      polygon([
        [-slit_width - wall, -slit_height],
        [-slit_width, -slit_height], [-slit_width, 0], [0, 0],
        [0, -slit_height], [wall, -slit_height],
        back_bottom, bottom, top, [-slit_width - wall, wall]
      ]);
      if (chamfer > 0) {
        // 貼付面の上下端と、下端の裏角。
        translate(top) rotate(tilt_deg) {
          bevel_cut([0, 0], 0);
          bevel_cut([0, -face_size], -90);
          bevel_cut([-wall, -face_size], 180);
        }
        // フックの上外角と、下向き開口の先端。
        translate([-slit_width - wall, wall])
          polygon([[0, 0], [chamfer, 0], [0, -chamfer]]);
        for (x = [-slit_width - wall, -slit_width, 0])
          translate([x, -slit_height]) scale([x == -slit_width ? -1 : 1, 1])
            polygon([[0, 0], [chamfer, 0], [0, chamfer]]);
      }
    }
}

if (part == "mounted")
  multmatrix([[0, 0, 1, -face_size / 2], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1]])
    holder();
else
  holder();
