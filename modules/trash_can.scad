// assets/trash-can/ の各部品が include する30Lゴミ袋用ゴミ箱。単体では何も描かない。
$fn = 96;

// nocoo sanipac 30L: flat 550 x 700. The bag folds 70 mm over the rim.
bag_length = 700;
bag_overhang = 70;

// [x, y]. The long side runs along Y so the lid clears the bed exclusion zone.
inner = [220, 240];
inner_radius = 10;
wall = 3;
printer_size = 256;      // Bambu Lab P1S build volume per axis.
bed_exclude = [ 18, 28 ]; // P1S front-left exclusion zone in the slicer's machine profile.

// Largest cm value that keeps both rings within the printer height.
inner_height = 480;
floor_thickness = 4;
height = floor_thickness + inner_height;

// Lap joint: the lower ring's inner tongue enters the upper ring's outer skirt.
// The outer face bulges to joint_wall around the joint so each half stays thick.
bottom_ring_height = 250; // Including the tongue.
lap = 12;
joint_wall = 4.2; // Tongue, gap and skirt side by side.
lap_gap = 0.1;    // Beside and above the tongue.
bulge_angle = 30; // Outer face overhang from vertical, as both rings print.
snap_width = 20;
snap_depth = 1.2;
snap_bottom = 4;       // Where the catch starts, above the joint plane.
snap_catch = 45;       // Catch underside overhang from vertical; no flat face in mid-air.
snap_ramp = 6;
snap_clearance = 0.4;  // Window edge below the catch, absorbs bridge sag on the inverted top ring.

// Bag pack pockets on the front and back inner walls.
pocket_width = 220;
pocket_gap = 6;
pocket_height = 240;
pocket_u_width = 140;
pocket_u_depth = 100;

lid_clearance = 0.5;
lid_skirt = 75;
hole_margin = 20; // Lid rim inside the walls around the hole.
hole_radius = 20;

tongue = (joint_wall - lap_gap) / 2;
skirt_void = tongue + lap_gap;
skirt = lap + lap_gap;
bulge_rise = (joint_wall - wall) / tan(bulge_angle);
snap_rise = snap_depth / tan(snap_catch);
snap_top = snap_bottom + snap_rise + snap_ramp;
window_bottom = snap_bottom + lap_gap / tan(snap_catch) - snap_clearance;
joint1 = bottom_ring_height - lap;
top_ring_height = height - joint1;
lid_inner = wall + lid_clearance;
lid_size = inner + 2 * [ 1, 1 ] * (lid_inner + wall);
eps = 0.01;

assert(bottom_ring_height <= printer_size && top_ring_height <= printer_size, "ring exceeds printer height");
assert(bag_length - bag_overhang - wall >= inner_height, "bag must reach the floor");
assert(lid_size[0] <= printer_size - bed_exclude[0] && lid_size[1] <= printer_size, "lid overlaps the bed exclusion zone");
assert(pocket_width <= inner[1] - 2 * inner_radius, "pocket must fit the flat wall");
assert(floor_thickness + pocket_height <= bottom_ring_height, "pocket must fit the bottom ring");
assert(pocket_u_width / 2 <= pocket_u_depth && pocket_u_depth < pocket_height);
assert(joint_wall >= wall && lap_gap < snap_depth && tongue + snap_depth < joint_wall);
assert(bulge_angle <= 45 && snap_catch <= 45, "overhang beyond 45 degrees");
assert(window_bottom > 0 && snap_top + 0.4 < lap && snap_width + 1 < pocket_width);

// Offset d from the inner wall face.
module outline(d) {
  rounded_square(inner + 2 * [ d, d ], inner_radius + d);
}

module rounded_square(size, radius) {
  offset(r = radius) square(size - 2 * [ radius, radius ], center = true);
}

// Children in each wall's frame: x along the wall from its centre, y inward from its inner face.
module at_walls(angles = [0:90:270]) {
  for (a = angles)
    rotate(a) translate([ 0, -inner[a % 180 == 0 ? 1 : 0] / 2, 0 ]) children();
}

module slab(z, d) {
  translate([0, 0, z]) linear_extrude(eps) outline(d);
}

module tongue(z) {
  translate([0, 0, z]) linear_extrude(lap) difference() {
    outline(tongue);
    outline(0);
  }
  // Catch underneath, ramp on top. The ends sink eps into the tongue: ends on its face leave zero-area slivers.
  at_walls() hull() {
      for (h = [snap_bottom, snap_top - eps])
        translate([-snap_width / 2, -tongue + eps, z + h]) cube([snap_width, 0.5, eps]);
      translate([-snap_width / 2, -tongue - snap_depth, z + snap_bottom + snap_rise])
        cube([snap_width, snap_depth + 0.5, eps]);
    }
}

module pockets() {
  top = floor_thickness + pocket_height;
  side = pocket_width / 2 + wall;
  // On the long walls.
  at_walls([ 90, 270 ]) difference() {
      translate([-side, 0, 0]) cube([2 * side, pocket_gap + wall, top]);
      translate([-pocket_width / 2, -eps, floor_thickness]) cube([pocket_width, pocket_gap + eps, top]);
      translate([0, pocket_gap - eps, top - pocket_u_depth + pocket_u_width / 2])
        rotate([-90, 0, 0]) linear_extrude(wall + 2 * eps) {
          circle(d = pocket_u_width);
          translate([-pocket_u_width / 2, -pocket_u_depth]) square([pocket_u_width, pocket_u_depth]);
        }
    }
}

module bottom_ring() {
  difference() {
    union() {
      linear_extrude(joint1) outline(wall);
      hull() {
        slab(joint1 - bulge_rise, wall);
        slab(joint1 - eps, joint_wall);
      }
    }
    translate([0, 0, floor_thickness]) linear_extrude(joint1) outline(0);
  }
  tongue(joint1);
  pockets();
}

// Print orientation: the rim on the bed, the skirt on top.
module top_ring() {
  translate([0, 0, top_ring_height]) mirror([0, 0, 1]) difference() {
    union() {
      linear_extrude(top_ring_height) outline(wall);
      linear_extrude(skirt) outline(joint_wall);
      hull() {
        slab(skirt - eps, joint_wall);
        slab(skirt + bulge_rise - eps, wall);
      }
    }
    translate([0, 0, -eps]) linear_extrude(top_ring_height + 2 * eps) outline(0);
    translate([0, 0, -eps]) linear_extrude(skirt + eps) outline(skirt_void);
    at_walls()
        translate([-snap_width / 2 - 0.5, -joint_wall - eps, window_bottom])
          cube([snap_width + 1, joint_wall - skirt_void + 2 * eps, snap_top + 0.4 - window_bottom]);
  }
}

// Print orientation: top plate on the bed.
module lid() {
  difference() {
    linear_extrude(wall + lid_skirt) outline(lid_inner + wall);
    translate([0, 0, wall]) linear_extrude(lid_skirt + eps) outline(lid_inner);
    translate([0, 0, -eps]) linear_extrude(wall + 2 * eps) rounded_square(inner - 2 * [ hole_margin, hole_margin ], hole_radius);
  }
}
