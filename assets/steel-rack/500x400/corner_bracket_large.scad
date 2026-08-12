use <../../../modules/bolts.scad>;
use <../../../modules/steel_rack.scad>;

width = 147;
height = 26;
deps = 8;
inner_radius = 4;
plate_corner_radius = 8;

difference() {
  union() {
    translate([0, 0, height])
      rotate([90, 180, 180])
      long_bar(width, height, deps);

    translate([0, 0, 0])
      rotate([90, 0, 90])
      long_bar(width, height, deps);

    cube([30, 30, 6]);
  }

  // Inner corner fillet
  translate([inner_radius, inner_radius, -0.1])
    rotate([0, 0, 180])
    fillet_profile(inner_radius, (height * 2) + 1.2);

  // Outer corner fillet (plate)
  translate([30 - plate_corner_radius, 30 - plate_corner_radius, -0.1])
    linear_extrude(height = 6.2)
    difference() {
      square([plate_corner_radius, plate_corner_radius]);
      circle(r = plate_corner_radius, $fn = 64);
    }

  // M4 bolt + nut (plate)
  translate([17.5, 17.5, -0.1])
    m4_bolt_hole(h = 6.5);

  translate([17.5, 17.5, 4])
    m4_nut_trap(h = 2.5);
}
