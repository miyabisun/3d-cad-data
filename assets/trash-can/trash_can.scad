$fn = 96;

part = "assembly"; // [assembly, bottom_ring, middle_ring, top_ring, lid]

// nocoo sanipac 30L: flat 550 x 700. The bag folds 70 mm over the rim.
bag_length = 700;
bag_overhang = 70;

inner_size = 240;
inner_radius = 10;
wall = 3;
printer_size = 256; // Bambu Lab P1S build volume per axis.

// Bottomless tube; the bag bottom reaches the floor. Rounded down to cm.
height = floor((bag_length - bag_overhang - wall) / 10) * 10;

// Lap joint: the lower ring's inner tongue enters the upper ring's outer skirt.
bottom_ring_height = 250; // Including the tongue.
lap = 12;
lap_gap = 0.2;
tongue = 1.4;
snap_width = 20;
snap_depth = 1.2;
snap_bottom = 4; // Above the joint plane.
snap_ramp = 6;

// Bag pack pockets on the front and back inner walls.
pocket_width = 220;
pocket_gap = 6;
pocket_height = 240;
pocket_u_width = 140;
pocket_u_depth = 100;

lid_clearance = 0.5;
lid_skirt = 75;
hole_size = 200;
hole_radius = 20;

half = inner_size / 2;
skirt_void = tongue + lap_gap;
joint1 = bottom_ring_height - lap;
upper_ring_height = (height - joint1 + lap) / 2;
joint2 = joint1 + upper_ring_height - lap;
lid_inner = wall + lid_clearance;
eps = 0.01;

assert(bottom_ring_height <= printer_size && upper_ring_height <= printer_size, "ring exceeds printer height");
assert(inner_size + 2 * (lid_inner + wall) <= printer_size, "lid exceeds printer bed");
assert(pocket_width <= inner_size - 2 * inner_radius, "pocket must fit the flat wall");
assert(wall + pocket_height <= bottom_ring_height, "pocket must fit the bottom ring");
assert(pocket_u_width / 2 <= pocket_u_depth && pocket_u_depth < pocket_height);
assert(tongue + lap_gap < wall && snap_depth < wall - tongue);
assert(snap_bottom + snap_ramp + 0.4 < lap && snap_width + 1 < pocket_width);

// Offset d from the inner wall face.
module outline(d) {
  offset(r = inner_radius + d) square(inner_size - 2 * inner_radius, center = true);
}

module rounded_square(size, radius) {
  offset(r = radius) square(size - 2 * radius, center = true);
}

module slab(z, d) {
  translate([0, 0, z]) linear_extrude(eps) outline(d);
}

module walls(z0, z1, skirt) {
  difference() {
    translate([0, 0, z0]) linear_extrude(z1 - z0) outline(wall);
    translate([0, 0, z0 - eps]) linear_extrude(z1 - z0 + 2 * eps) outline(0);
    if (skirt) {
      translate([0, 0, z0 - eps]) linear_extrude(lap + lap_gap + eps) outline(skirt_void);
      // 45 degree shoulder so the full wall prints without an overhang.
      hull() {
        slab(z0 + lap + lap_gap - eps, skirt_void);
        slab(z0 + lap + lap_gap + skirt_void - eps, 0);
      }
      for (a = [0:90:270])
        rotate(a)
          translate([-snap_width / 2 - 0.5, -half - wall - eps, z0 + snap_bottom - 0.2])
            cube([snap_width + 1, wall - tongue + eps, snap_ramp + 0.6]);
    }
  }
}

module tongue(z) {
  translate([0, 0, z]) linear_extrude(lap) difference() {
    outline(tongue);
    outline(0);
  }
  // Flat catch underneath, ramp on top.
  for (a = [0:90:270])
    rotate(a) hull() {
      translate([-snap_width / 2, -half - tongue - snap_depth, z + snap_bottom])
        cube([snap_width, snap_depth + 0.5, eps]);
      translate([-snap_width / 2, -half - tongue, z + snap_bottom + snap_ramp - eps])
        cube([snap_width, 0.5, eps]);
    }
}

module pockets() {
  top = wall + pocket_height;
  side = pocket_width / 2 + wall;
  for (a = [0, 180])
    rotate(a) difference() {
      translate([-side, -half, 0]) cube([2 * side, pocket_gap + wall, top]);
      translate([-pocket_width / 2, -half - eps, wall]) cube([pocket_width, pocket_gap + eps, top]);
      translate([0, -half + pocket_gap - eps, top - pocket_u_depth + pocket_u_width / 2])
        rotate([-90, 0, 0]) linear_extrude(wall + 2 * eps) {
          circle(d = pocket_u_width);
          translate([-pocket_u_width / 2, -pocket_u_depth]) square([pocket_u_width, pocket_u_depth]);
        }
    }
}

module bottom_ring() {
  walls(0, joint1, false);
  tongue(joint1);
  pockets();
}

module middle_ring() {
  translate([0, 0, -joint1]) {
    walls(joint1, joint2, true);
    tongue(joint2);
  }
}

module top_ring() {
  translate([0, 0, -joint2]) walls(joint2, height, true);
}

// Print orientation: top plate on the bed.
module lid() {
  difference() {
    linear_extrude(wall + lid_skirt) outline(lid_inner + wall);
    translate([0, 0, wall]) linear_extrude(lid_skirt + eps) outline(lid_inner);
    translate([0, 0, -eps]) linear_extrude(wall + 2 * eps) rounded_square(hole_size, hole_radius);
  }
}

module trash_can_part(name) {
  if (name == "bottom_ring") bottom_ring();
  else if (name == "middle_ring") middle_ring();
  else if (name == "top_ring") top_ring();
  else if (name == "lid") lid();
  else if (name == "assembly") {
    bottom_ring();
    translate([0, 0, joint1]) middle_ring();
    translate([0, 0, joint2]) top_ring();
    translate([0, 0, height + wall]) mirror([0, 0, 1]) lid();
  }
  else assert(false, str("unknown part: ", name));
}

trash_can_part(part);
