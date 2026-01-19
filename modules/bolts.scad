module nut_trap(d, h) {
  linear_extrude(height = h, center = true)
  circle(d = d / cos(30), $fn = 6);
}

module bolt_hole(d, h) {
  linear_extrude(height = h, center = true)
  circle(d = d, $fn = 64);
}

module m3_bolt_hole_with_nut (x, y, h) {
  nut_thickness = 2.4;

  union() {
    translate([0, 0, h / 2])
    bolt_hole(d = 3.4, h = h + 1);
    
    // cylinder center is at h/2, so we need to move it up.
    // We want the nut to be from (h - nut_thickness) to h.
    // The center of the nut will be at h - (nut_thickness / 2).
    translate([0, 0, h - nut_thickness / 2])
    rotate([0, 0, 90])
    nut_trap(d = 5.7, h = nut_thickness);
  }
}

module m4_bolt_hole_with_nut (h) {
  nut_thickness = 3.2;

  union() {
    translate([0, 0, h / 2])
    bolt_hole(d = 4.4, h = h + 1);
    
    translate([0, 0, h - nut_thickness / 2])
    rotate([0, 0, 90])
    nut_trap(d = 7.2, h = nut_thickness);
  }
}

module m6_bolt_hole_with_nut (h) {
  nut_thickness = 5;

  union() {
    translate([0, 0, h / 2])
    bolt_hole(d = 6.2, h = h + 1);
    
    translate([0, 0, h - nut_thickness / 2])
    rotate([0, 0, 90])
    nut_trap(d = 10.2, h = nut_thickness);
  }
}

module m8_bolt_hole_with_nut (h) {
  nut_thickness = 6.5;

  union() {
    translate([0, 0, h / 2])
    bolt_hole(d = 8.4, h = h + 1);
    
    translate([0, 0, h - nut_thickness / 2])
    rotate([0, 0, 90])
    nut_trap(d = 13.3, h = nut_thickness);
  }
}

// Hex holes for self-tapping (nominal - 0.2mm)
module hex_hole(flat_d, h) {
  linear_extrude(height = h, center = true)
  circle(d = flat_d / cos(30), $fn = 6);
}

module m3_bolt_hexhole(h) {
  rotate([0, 0, 90])
  hex_hole(flat_d = 2.8, h = h);
}

module m4_bolt_hexhole(h) {
  rotate([0, 0, 90])
  hex_hole(flat_d = 3.8, h = h);
}

module m6_bolt_hexhole(h) {
  rotate([0, 0, 90])
  hex_hole(flat_d = 5.8, h = h);
}

module m8_bolt_hexhole(h) {
  rotate([0, 0, 90])
  hex_hole(flat_d = 7.8, h = h);
}