$fn = 128;

// Pod envelope; clearance is per side. Radius 50 gives a circular 100 mm pod.
pod_width = 100;
pod_depth = 100;
pod_corner_radius = 50;
pod_clearance = 0.5;
retaining_height = 20;
floor_thickness = 8;
wall_thickness = 3;
drain_diameter = 8;

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
assert(drain_diameter > 0 && drain_diameter < min(inner_width, inner_depth));

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

difference() {
  union() {
    linear_extrude(tray_height) pod_profile(wall_thickness);
    // The slot opens downwards and through both X ends.
    difference() {
      translate([-slot_length / 2, back_y, 0])
        cube([slot_length, 2 * hook_thickness + slot_gap, hook_height]);
      translate([-slot_length / 2 - eps, front_y - slot_gap, -eps])
        cube([slot_length + 2 * eps, slot_gap, slot_depth + eps]);
    }
  }
  translate([0, 0, floor_thickness])
    linear_extrude(max(tray_height, hook_height) + eps) pod_profile();
  translate([0, wall_thickness + inner_depth / 2, -eps])
    cylinder(d = drain_diameter, h = floor_thickness + 2 * eps);
}
