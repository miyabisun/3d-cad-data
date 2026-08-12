use <../../../modules/bolts.scad>;
use <../../../modules/steel_rack.scad>;

width = 147;
height = 26;
deps = 8;
radius = 4;

difference() {
  union() {
    translate([0, 0, height])
      rotate([90, 180, 180])
      short_bar(25, height, deps);

    translate([0, 0, 0])
      rotate([90, 0, 90])
      long_bar(width, height, deps);
  }

  // Offset to align with the 6mm wall clearance cut
  translate([deps / 2, deps / 2 + 3, 0])
    rotate([0, 0, 180])
    fillet_profile(radius, height * 2 + 1);

  // Cut 6mm clearance to avoid wall interference
  translate([deps / 2, 0, 0])
    cube([50, 6, height * 2 + 1], center = true);
}
