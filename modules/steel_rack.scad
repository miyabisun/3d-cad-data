use <bolts.scad>;

bolt_edge_offset = 15;
bolt_positions = [
  bolt_edge_offset,
  bolt_edge_offset + 98,
  bolt_edge_offset + 98 + 24,
];

module bolt_and_nut(y, h) {
  nut_thickness = 5;
  translate([0, y, h / 2])
    m6_bolt_hole(h + 1, center = true);
  translate([0, y, h - nut_thickness / 2])
    rotate([0, 0, 90])
    m6_nut_trap(nut_thickness, center = true);
}

module long_bar(w, y, h) {
  difference() {
    translate([w / 2, y / 2, h / 2])
      cube([w, y, h], center = true);

    for (x = bolt_positions) {
      translate([x, 0, 0])
        bolt_and_nut(y / 2, h);
    }
  }
}

module short_bar(w, y, h) {
  difference() {
    translate([w / 2, y / 2, h / 2])
      cube([w, y, h], center = true);

    translate([bolt_positions[0], 0, 0])
      bolt_and_nut(y / 2, h);
  }
}

module fillet_profile(r, h) {
  linear_extrude(height = h, center = true)
    difference() {
      square([r, r]);
      circle(r = r, $fn = 64);
    }
}
