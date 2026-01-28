module drilling_guide(
  hole_from_edge = 17.5,
  hole_diameter = 4.2,
  lip_size = 5
) {
  // 当てる板の厚さ
  bottom_plate_thickness = 4;
  // くり抜いた後に残る厚み (ドリルのガイドとなる穴の深さ)
  drilling_bore_depth = 10;

  guide_size = hole_from_edge + 15;  // 十分な大きさ
  fillet_radius = 4;                 // 角の丸み

  difference() {
    // 外側のブロックにフィレット処理を適用
    x_size = guide_size + lip_size;
    y_size = guide_size + lip_size;
    hull() {
      translate([fillet_radius, fillet_radius, 0])
      cylinder(h = drilling_bore_depth, r = fillet_radius, $fn = 50);
      translate([x_size - fillet_radius, fillet_radius, 0])
      cylinder(h = drilling_bore_depth, r = fillet_radius, $fn = 50);
      translate([fillet_radius, y_size - fillet_radius, 0])
      cylinder(h = drilling_bore_depth, r = fillet_radius, $fn = 50);
      translate([x_size - fillet_radius, y_size - fillet_radius, 0])
      cylinder(h = drilling_bore_depth, r = fillet_radius, $fn = 50);
    }

    // 内側の上部をくり抜いて段差を作る
    // Z方向に (drilling_bore_depth - bottom_plate_thickness) だけずらして、底面を残す
    translate([lip_size, lip_size, drilling_bore_depth - bottom_plate_thickness]) {
      cube([guide_size, guide_size, bottom_plate_thickness + 1]); // 上に貫通させるため +1 は有効
    }

    // 穴を開ける
    translate([hole_from_edge + lip_size, hole_from_edge + lip_size, -1]) {
      cylinder(d = hole_diameter, h = drilling_bore_depth + 2, $fn = 50);
    }
  }
}

drilling_guide();
