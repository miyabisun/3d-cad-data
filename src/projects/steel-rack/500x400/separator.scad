module separator(diameter = 20, height = 3.5, bolt_diameter = 4) {
  difference() {
    cylinder(d = diameter, h = height, $fn = 100);
    translate([0, 0, -1])
      cylinder(d = bolt_diameter, h = height + 2, $fn = 50);
  }
}

separator();
