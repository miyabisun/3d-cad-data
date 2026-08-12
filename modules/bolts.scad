module nut_trap(d, h, center = true) {
  linear_extrude(height = h, center = center)
  circle(d = d / cos(30), $fn = 6);
}

module bolt_hole(d, h, center = true) {
  linear_extrude(height = h, center = center)
  circle(d = d, $fn = 64);
}

// Hex holes for self-tapping (nominal - 0.2mm)
module hex_hole(flat_d, h) {
  linear_extrude(height = h, center = true)
  circle(d = flat_d / cos(30), $fn = 6);
}

module m3_bolt_hexhole(h) {
  rotate([0, 0, 90]) hex_hole(flat_d = 2.8, h = h);
}

module m4_bolt_hexhole(h) {
  rotate([0, 0, 90]) hex_hole(flat_d = 3.8, h = h);
}

module m6_bolt_hexhole(h) {
  rotate([0, 0, 90]) hex_hole(flat_d = 5.8, h = h);
}

module m8_bolt_hexhole(h) {
  rotate([0, 0, 90]) hex_hole(flat_d = 7.8, h = h);
}

// M3
module m3_bolt_hole(h, center = false) { bolt_hole(d = 3.4, h = h, center = center); }
module m3_nut_trap(h, center = false) { nut_trap(d = 5.7, h = h, center = center); }

// M4
module m4_bolt_hole(h, center = false) { bolt_hole(d = 4.4, h = h, center = center); }
module m4_nut_trap(h, center = false) { nut_trap(d = 7.5, h = h, center = center); }

// M6
module m6_bolt_hole(h, center = false) { bolt_hole(d = 6.2, h = h, center = center); }
module m6_nut_trap(h, center = false) { nut_trap(d = 10.2, h = h, center = center); }

// M8
module m8_bolt_hole(h, center = false) { bolt_hole(d = 8.4, h = h, center = center); }
module m8_nut_trap(h, center = false) { nut_trap(d = 13.3, h = h, center = center); }
