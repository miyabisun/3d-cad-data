$fn = 64;
part = "stand"; // stand, cover, assembly (preview)

// X: former speaker height; Y: front (-) to back (+); left end faces down.
speaker_side_width = 90.4; // Bose first-generation published envelope, rounded to 0.1 mm.
speaker_depth = 52.3;
speaker_clearance = 1; // Per side; tune against the actual silicone shell.
// Photo-based approximation, NOT a dimensioned Bose drawing. See README sources.
front_radius = 5;
back_radius = 22;
end_radius = 6; // Left-end edge blend, from the seating face to the full body section.
guide_height = 25;
front_height = 8; // Lower the grille-side wall.
wall = 3;
foot_margin = 10;

// Measured housing: 14.3 x 22.1 x 10.5. Tip: 12 along USB-C's long axis, 7.5 across.
port_x = 5; // Provisional: 5 mm toward the buttons from the left-end center.
port_y = 0;
adapter_width = 14.3; // Cable-side housing envelope, X/Y/Z with contact facing up.
adapter_depth = 22.1;
adapter_height = 10.5;
adapter_clearance = 0.3; // Per side and above the housing.
contact_offset_y = -5; // Unmeasured: contact center relative to the housing center.
contact_width = 12.6; // USB-C long axis is X in the official left-side photo.
contact_depth = 8.1; // Measured tip + 0.3 mm each side; verify the adapter's axis.
tip_projection = 3; // Seated speaker end to the coupled housing's top shoulder.
cable_width = 12; // Envelope of cable AND USB-C plug; exit toward +Y.
cable_height = 8;
pilot_diameter = 2.6; // M3 thread-forming pilot; tune for the printed material.

cover_thickness = 3;
lip = 1.5;
eps = 0.01;
inner_w = speaker_side_width + 2 * speaker_clearance;
inner_d = speaker_depth + 2 * speaker_clearance;
base_w = inner_w + 2 * (wall + foot_margin);
base_d = inner_d + 2 * (wall + foot_margin);
pocket_w = adapter_width + 2 * adapter_clearance;
pocket_d = adapter_depth + 2 * adapter_clearance;
holder_x = port_x;
holder_y = port_y - contact_offset_y;
shoulder_z = cover_thickness + adapter_height + adapter_clearance;
seat_z = shoulder_z + tip_projection;
plate_w = pocket_w + 14;
plate_d = pocket_d + 6;
screw_x = pocket_w / 2 + 3.5;

assert(part == "stand" || part == "cover" || part == "assembly");
assert(speaker_side_width > 0 && speaker_depth > 0 && speaker_clearance >= 0);
assert(wall >= 3 && foot_margin >= 3 && guide_height > 2);
assert(front_radius > 0 && back_radius >= front_radius && 2 * back_radius < min(speaker_side_width, speaker_depth));
assert(end_radius > 0 && end_radius <= front_height && front_height < guide_height - 1);
assert(adapter_width > 0 && adapter_depth > 0 && adapter_height >= 8 && adapter_clearance >= 0);
assert(contact_width > 0 && contact_width <= adapter_width - 1.5,
  "The contact opening must leave housing shoulders to retain");
assert(contact_depth > 0 && abs(contact_offset_y) + contact_depth / 2 + lip <= adapter_depth / 2);
assert(tip_projection >= lip, "The device tip must reach below the retaining shoulder");
assert(cable_width > 0 && cable_width <= adapter_width && cable_height > 0 && cable_height <= adapter_height);
assert(pilot_diameter >= 2 && pilot_diameter < 3.4);
assert(abs(holder_x) + plate_w / 2 + 3 < base_w / 2 && abs(holder_y) + plate_d / 2 + 3 < base_d / 2,
  "The recessed cover must fit inside the foot");
assert(abs(port_x) + contact_width / 2 + 3 < inner_w / 2 - end_radius &&
       abs(port_y) + contact_depth / 2 + 3 < inner_d / 2 - end_radius,
  "Leave a supporting seat around the contact opening");

module screw_positions() {
  for (x = [-screw_x, screw_x]) translate([x, 0, 0]) children();
}

// Flat grille side (-Y), a fuller rear curve (+Y). The same contour shapes the foot.
module speaker_profile() {
  hull() for (side = [-1, 1]) {
    translate([side * (speaker_side_width / 2 - front_radius), -speaker_depth / 2 + front_radius])
      circle(r = front_radius);
    translate([side * (speaker_side_width / 2 - back_radius), speaker_depth / 2 - back_radius])
      circle(r = back_radius);
  }
}

module profile_slice(z, margin) {
  translate([0, 0, z]) linear_extrude(eps) offset(r = margin) speaker_profile();
}

// ponytail: constant section after the end blend; replace the photo-derived radii
// with a measured end profile if the silicone shell needs a closer fit.
function end_inset(z) = end_radius - sqrt(pow(end_radius, 2) - pow(end_radius - z, 2));

module end_relief() {
  for (i = [0:11]) hull() for (step = [i, i + 1]) {
    z = end_radius * step / 12;
    profile_slice(seat_z + z, speaker_clearance - end_inset(z));
  }
  translate([0, 0, seat_z + end_radius])
    linear_extrude(guide_height - end_radius + eps)
      offset(r = speaker_clearance) speaker_profile();
}

module stand() {
  difference() {
    union() {
      hull() {
        profile_slice(0, speaker_clearance + wall + foot_margin - 1);
        profile_slice(1, speaker_clearance + wall + foot_margin);
        profile_slice(seat_z, speaker_clearance + wall);
      }
      translate([0, 0, seat_z]) linear_extrude(guide_height)
        offset(r = speaker_clearance + wall) speaker_profile();
    }
    end_relief();
    translate([-base_w, -base_d, seat_z + front_height])
      cube([2 * base_w, base_d - speaker_depth / 2 + 8, guide_height]);
    // The final 1 mm opens outward to guide insertion.
    hull() {
      profile_slice(seat_z + guide_height - 1, speaker_clearance);
      profile_slice(seat_z + guide_height, speaker_clearance + 1);
    }
    translate([holder_x, holder_y, -eps])
      linear_extrude(shoulder_z + eps) square([pocket_w, pocket_d], center = true);
    translate([port_x, port_y, shoulder_z - eps])
      linear_extrude(tip_projection + 2 * eps) square([contact_width, contact_depth], center = true);
    translate([holder_x - cable_width / 2, holder_y, cover_thickness])
      cube([cable_width, base_d / 2 - holder_y + eps, cable_height]);
    translate([holder_x, holder_y, -eps])
      linear_extrude(cover_thickness + eps) square([plate_w + 0.4, plate_d + 0.4], center = true);
    translate([holder_x, holder_y, cover_thickness - eps])
      screw_positions() cylinder(d = pilot_diameter, h = 8 + eps);
  }
}

// Printed with the countersinks upward; flip over to assemble flush at Z=0.
module cover() {
  difference() {
    linear_extrude(cover_thickness) square([plate_w, plate_d], center = true);
    screw_positions() {
      translate([0, 0, -eps]) cylinder(d = 3.4, h = cover_thickness + 2 * eps);
      translate([0, 0, cover_thickness - 1.5]) cylinder(d1 = 3.4, d2 = 6.4 + 2 * eps, h = 1.5 + eps);
    }
  }
}

if (part == "cover") {
  cover();
} else {
  stand();
  if (part == "assembly") {
    translate([holder_x, holder_y, cover_thickness]) rotate([180, 0, 0]) cover();
    %union() {
      for (i = [0:11]) hull() for (step = [i, i + 1]) {
        z = end_radius * step / 12;
        profile_slice(seat_z + z, -end_inset(z));
        profile_slice(seat_z + 201.4 - z, -end_inset(z));
      }
    }
    %translate([holder_x, holder_y, cover_thickness])
      linear_extrude(adapter_height) square([adapter_width, adapter_depth], center = true);
  }
}
