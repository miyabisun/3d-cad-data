module drilling_guide(
  hole_from_edge = 17.5,
  hole_diameter = 4.2,
  lip_size = 5
) {
  bottom_plate_thickness = 4;
  drilling_bore_depth = 10;
  guide_size = hole_from_edge + 15;
  fillet_radius = 4;

  difference() {
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

    // Stepped pocket (leaves bottom_plate_thickness at bottom)
    translate([lip_size, lip_size, drilling_bore_depth - bottom_plate_thickness])
      cube([guide_size, guide_size, bottom_plate_thickness + 1]);

    // Drill guide hole
    translate([hole_from_edge + lip_size, hole_from_edge + lip_size, -1])
      cylinder(d = hole_diameter, h = drilling_bore_depth + 2, $fn = 50);
  }
}

drilling_guide();
