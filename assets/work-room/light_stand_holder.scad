$fn = 64;

pole_diameter = 12.0;
pole_insert_depth = 30.0;
pole_clearance = 1.4; // includes ~1mm 3D print shrinkage compensation

holder_wall_thickness = 3.0;
holder_od = pole_diameter + pole_clearance + (holder_wall_thickness * 2);

base_thickness = 5.0;
base_height = pole_insert_depth;

screw_hole_spacing = holder_od + 20.0;
base_width = screw_hole_spacing + 15.0;

screw_hole_diameter = 4.0;
screw_head_diameter = 8.0;
screw_head_countersink_depth = 3.0;

module screw_hole_countersunk() {
  rotate([0, 90, 0]) {
    cylinder(d = screw_hole_diameter, h = base_thickness * 3, center = true);

    translate([0, 0, -screw_head_countersink_depth])
      cylinder(d1 = screw_hole_diameter, d2 = screw_head_diameter, h = screw_head_countersink_depth + 0.01); // +0.01 to avoid z-fighting

    cylinder(d = screw_head_diameter, h = 10);
  }
}

module light_stand_holder() {
  difference() {
    union() {
      translate([-base_thickness/2, 0, 0])
        cube([base_thickness, base_width, base_height], center = true);

      // Thin slice as hull source for smooth base-to-holder transition
      hull() {
        translate([-base_thickness/2 + 0.1, 0, 0])
           cube([0.1, holder_od, base_height], center = true);

        translate([holder_od/2 + base_thickness/2, 0, 0])
           cylinder(d = holder_od, h = base_height, center = true);
      }
    }

    // Pole hole (2mm floor at bottom)
    translate([holder_od/2 + base_thickness/2, 0, base_height/2 - pole_insert_depth/2 + 0.1])
      translate([0, 0, 2])
        cylinder(d = pole_diameter + pole_clearance, h = pole_insert_depth + 1, center = true);

    translate([0, screw_hole_spacing/2, 0])
      screw_hole_countersunk();

    translate([0, -screw_hole_spacing/2, 0])
      screw_hole_countersunk();
  }
}

light_stand_holder();
