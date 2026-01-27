use <../../../modules/bolts.scad>;
width = 147;
height = 26;
deps = 8;
inner_radius = 4; // Radius for the main bracket's inner fillet.
plate_corner_radius = 8; // Radius for the plate's outer corner.

// A single difference operation defines the final shape, ensuring all fillets and holes are processed correctly.
difference() {
  // 1. First, unify all solid components to form a single solid body.
  union() {
    // Main bracket bars
    translate([0, 0, height])
      rotate([90, 180, 180])
      long_bar(width, height, deps);

    translate([0, 0, 0])
      rotate([90, 0, 90])
      long_bar(width, height, deps);

    // The connection plate
    cube([30, 30, 6]);
  }

  // 2. Now, subtract all the negative spaces (fillets and holes) from the unified body.

  // Inner corner fillet: Applies to the entire height of the unified body, ensuring a consistent inner radius.
  translate([inner_radius, inner_radius, -0.1])
    rotate([0, 0, 180])
    fillet_profile(inner_radius, (height * 2) + 1.2);

  // Outer corner fillet: Applies only to the plate's outer corner.
  translate([30 - plate_corner_radius, 30 - plate_corner_radius, -0.1])
    linear_extrude(height = 6.2)
    difference() {
      square([plate_corner_radius, plate_corner_radius]);
      circle(r = plate_corner_radius, $fn = 64);
    }

  // Bolt and nut holes using M4-specific modules
  translate([17.5, 17.5, -0.1])
    m4_bolt_hole(h = 6.5);

  translate([17.5, 17.5, 4])
    m4_nut_trap(h = 2.5);
}

// Module for creating an inner fillet profile.
module fillet_profile(r, h) {
  linear_extrude(height = h, center = true)
    difference() {
      square([r, r]);
      circle(r = r, $fn = 64);
    }
}

// Module for the long bar of the bracket
module long_bar (w, y, h) {
  difference() {
    translate([w / 2, y / 2, h / 2])
      cube([w, y, h], center=true);

    translate([15, y / 2, 0])
      union() {
        nut_thickness = 5; // M6 nut height

        // Replicates hole from z~0 to z~h
        translate([0, 0, h / 2])
          m6_bolt_hole(h + 1, center = true);

        // Replicates nut trap at the top surface (from z=h-thickness to z=h)
        translate([0, 0, h - nut_thickness / 2])
          rotate([0, 0, 90])
          m6_nut_trap(nut_thickness, center = true);
      }
    translate([15 + 98, y / 2, 0])
      union() {
        nut_thickness = 5; // M6 nut height

        // Replicates hole from z~0 to z~h
        translate([0, 0, h / 2])
          m6_bolt_hole(h + 1, center = true);

        // Replicates nut trap at the top surface (from z=h-thickness to z=h)
        translate([0, 0, h - nut_thickness / 2])
          rotate([0, 0, 90])
          m6_nut_trap(nut_thickness, center = true);
      }
    translate([15 + 98 + 24, y / 2, 0])
      union() {
        nut_thickness = 5; // M6 nut height

        // Replicates hole from z~0 to z~h
        translate([0, 0, h / 2])
          m6_bolt_hole(h + 1, center = true);

        // Replicates nut trap at the top surface (from z=h-thickness to z=h)
        translate([0, 0, h - nut_thickness / 2])
          rotate([0, 0, 90])
          m6_nut_trap(nut_thickness, center = true);
      }
  }
}
