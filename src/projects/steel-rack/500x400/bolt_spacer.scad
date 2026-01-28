// Based on the latest simplified design from the user.

// Part B dimensions (Now the main part)
part_b_outer_d = 6.6; // Changed to be the main outer diameter
part_b_h = 2.5; // Changed from 2.1 to 2.5

// Common dimensions
hole_d = 6.6; // Diameter of the through-hole.
dist = 12.7; // Distance between the centers of the two original circles.

/*
 * Creates a shape by hulling two circles.
 *
 * @param d The diameter of the circles.
 * @param dist The distance between the circle centers.
 */
module hull_shape(d, dist) { // y_offset parameter removed as it's no longer needed for alignment
  hull() {
    translate([0, dist / 2, 0])
      circle(d = d, $fn = 50);
    translate([0, -dist / 2, 0])
      circle(d = d, $fn = 50);
  }
}

// --- Main Model ---
difference() {
  // Step 1: Create the base solid body (only Part B now).
  // The main layer, starting from z=0.
  linear_extrude(height = part_b_h) {
    hull_shape(
      d = part_b_outer_d, 
      dist = dist
    );
  }

  // From the solid body above, perform two cuts:

  // Step 2: Cut the through-hole.
  // This hole is located at the center of the "top" original circle.
  total_height = part_b_h; // Only Part B's height now.
  translate([0, dist / 2, -1]) {
    cylinder(d = hole_d, h = total_height + 2, $fn = 50);
  }

  // Step 3: Cut off the entire top part of the object, making it flat.
  // The cut happens along the center-line of the through-hole.
  cut_size = 30; // A large value to ensure a clean cut across the whole model.
  translate([ -cut_size / 2, dist / 2, -1]) {
    cube([cut_size, cut_size, total_height + 2]);
  }
}
