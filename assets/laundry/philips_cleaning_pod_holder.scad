$fn = 128;

// Pod envelope; clearance is per side. Radius 50 gives a circular 100 mm pod.
pod_width = 100;
pod_depth = 100;
pod_corner_radius = 50;
pod_clearance = 0.5;
retaining_height = 20;
floor_thickness = 8;
wall_thickness = 3;
rib_width = 10;
edge_chamfer = 1;

// X: along the shelf edge; Y: toward the pod; Z: upward in use.
shelf_thickness = 3;
slot_clearance = 0.4; // Total allowance, not per side.
slot_length = 60;
slot_depth = 45;
hook_thickness = 6;

inner_width = pod_width + 2 * pod_clearance;
inner_depth = pod_depth + 2 * pod_clearance;
slot_gap = shelf_thickness + slot_clearance;
hook_height = slot_depth + hook_thickness;
tray_height = floor_thickness + retaining_height;
front_y = wall_thickness - hook_thickness;
back_y = front_y - slot_gap - hook_thickness;
eps = 0.01;

assert(pod_width > 0 && pod_depth > 0 && pod_clearance >= 0);
assert(pod_corner_radius >= 0 && 2 * pod_corner_radius <= min(pod_width, pod_depth));
assert(slot_length > 0 && slot_length <= 60, "slot_length must be <= 60 mm");
assert(slot_depth > 0 && slot_depth <= 45, "slot_depth must be <= 45 mm");
assert(shelf_thickness > 0 && slot_clearance >= 0);
assert(wall_thickness > 0 && hook_thickness > wall_thickness);
assert(floor_thickness > 0 && retaining_height > 0);
assert(rib_width > 0 && rib_width < min(inner_width, inner_depth));
assert(edge_chamfer > 0 && 2 * edge_chamfer < min(floor_thickness, wall_thickness, hook_thickness, slot_length));

module pod_profile(extra = 0) {
  radius = pod_corner_radius + pod_clearance + extra;
  translate([0, wall_thickness + inner_depth / 2])
    if (radius == 0) {
      square([pod_width, pod_depth], center = true);
    } else {
      hull()
        for (x = [-1, 1], y = [-1, 1])
          translate([x * (pod_width / 2 - pod_corner_radius), y * (pod_depth / 2 - pod_corner_radius)])
            circle(r = radius);
    }
}

// Convex outlines: a 1:1 inset at the top/bottom gives a 45 degree chamfer.
module chamfered_extrude(height) {
  hull() {
    translate([0, 0, edge_chamfer])
      linear_extrude(height - 2 * edge_chamfer) children();
    linear_extrude(height) offset(delta = -edge_chamfer) children();
  }
}

difference() {
  union() {
    // Fill the full hook width into the tray before cutting the pod cavity.
    chamfered_extrude(tray_height)
      hull() {
        pod_profile(wall_thickness);
        translate([-slot_length / 2, front_y])
          square([slot_length, hook_thickness]);
      }
    chamfered_extrude(hook_height)
      translate([-slot_length / 2, back_y])
        square([slot_length, 2 * hook_thickness + slot_gap]);
  }
  // Keep the slot faces straight; only the exterior outline is chamfered.
  translate([-slot_length / 2 - eps, front_y - slot_gap, -eps])
    cube([slot_length + 2 * eps, slot_gap, slot_depth + eps]);
  difference() {
    translate([0, 0, -eps])
      linear_extrude(max(tray_height, hook_height) + 2 * eps) pod_profile();
    translate([0, 0, -2 * eps])
      linear_extrude(floor_thickness + 2 * eps)
        translate([0, wall_thickness + inner_depth / 2])
          for (angle = [0:45:135])
            rotate(angle)
              square([2 * max(inner_width, inner_depth), rib_width], center = true);
  }
}
