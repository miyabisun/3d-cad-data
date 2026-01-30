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

// --- Main Model Body ---
module main_body() {
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
}

/*
 * Creates a flared, semi-circular shape to act as an anti-slip grip.
 * This is added to the bottom of the -Y side of the main body to prevent it
 * from sliding forward.
 * The flare extends from z=0 to z=0.5 at a 45-degree angle.
 * The width is constrained to abs(x) <= 3.3mm.
 */
module anti_slip_flare() {
    y_center = -dist / 2;
    flare_height = 0.5; // The height of the flare, from z=0 to z=0.5
    
    // For a 45-degree flare, the radial increase equals the height.
    flare_radius_increase = flare_height; 

    d_top = part_b_outer_d; // Diameter at the top of the flare (z=0.5)
    d_bottom = part_b_outer_d + 2 * flare_radius_increase; // Diameter at the bottom (z=0)

    // Use intersection of three shapes:
    // 1. A conical frustum for the main flare shape.
    // 2. A cube to keep only the -Y half of the frustum.
    // 3. A cube to limit the width along the X-axis.
    intersection() {
        // 1. Create the full conical frustum.
        // It's placed at the center of the -Y circle.
        // cylinder(h, d1, d2) places the base (d1) at z=0 and the top (d2) at z=h.
        translate([0, y_center, 0])
            cylinder(h = flare_height, d1 = d_bottom, d2 = d_top, $fn = 50);

        // 2. Create a large cube to cut the frustum in half,
        // keeping only the part on the -Y side of its own center.
        cut_box_size = d_bottom * 1.5; // Ensure the box is large enough.
        translate([-cut_box_size / 2, y_center - cut_box_size, -1])
            cube([cut_box_size, cut_box_size, flare_height + 2]);
            
        // 3. Create a cube to constrain the width to abs(x) <= 3.3.
        x_constraint = 3.3;
        y_size = d_bottom * 2; // Make sure it covers the whole flare
        translate([-x_constraint, y_center - y_size / 2, -1])
            cube([x_constraint * 2, y_size, flare_height + 2]);
    }
}

// --- Final Assembly ---
// Combine the main body with the new anti-slip flare.
union() {
    main_body();
    anti_slip_flare();
}
