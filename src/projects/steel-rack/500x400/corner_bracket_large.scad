use <../../../modules/bolts.scad>;
width = 147;
height = 26;
deps = 8;
radius = 4;

difference() {
  union(){
    translate([0, 0, height])
    rotate([90, 180, 180])
    long_bar(width, height, deps);
    
    translate([0, 0, 0])
    rotate([90, 0, 90])
    long_bar(width, height, deps);
  }

  translate([deps / 2, deps / 2, 0])
  rotate([0, 0, 180])
  fillet_profile(radius, height * 2 + 1);
}

module fillet_profile(r, h) {
  linear_extrude(height = h, center = true)
  difference() {
    square([r, r]);
    circle(r = r, $fn = 64);
  }
}

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
    };
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
    };
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
    };
  }
}
