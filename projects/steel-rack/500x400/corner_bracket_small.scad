use <../../../modules/bolts.scad>;
width = 147;
height = 26;
deps = 8;
radius = 4;

difference() {
  union(){
    translate([0, 0, height])
    rotate([90, 180, 180])
    short_bar(25, height, deps);
    
    translate([0, 0, 0])
    rotate([90, 0, 90])
    long_bar(width, height, deps);
  }

  translate([deps / 2, deps / 2 + 3, 0])
  rotate([0, 0, 180])
  fillet_profile(radius, height * 2 + 1);
  
  translate([deps / 2, 0, 0])
  cube([50, 6, height * 2 + 1], center = true);
}

module fillet_profile(r, h) {
  linear_extrude(height = h, center = true)
  difference() {
    square([r, r]);
    circle(r = r, $fn = 64);
  }
}

module short_bar (w, y, h) {
  difference() {
    translate([w / 2, y / 2, h / 2])
    cube([w, y, h], center=true);

    translate([15, y / 2, 0])
    m6_bolt_hole_with_nut(h);
  }
}

module long_bar (w, y, h) {
  difference() {
    translate([w / 2, y / 2, h / 2])
    cube([w, y, h], center=true);

    translate([15, y / 2, 0])
    m6_bolt_hole_with_nut(h);
    translate([15 + 98, y / 2, 0])
    m6_bolt_hole_with_nut(h);
    translate([15 + 98 + 24, y / 2, 0])
    m6_bolt_hole_with_nut(h);
  }
}
