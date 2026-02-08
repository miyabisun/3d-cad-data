part_b_outer_d = 6.6;
part_b_h = 2.5;

hole_d = 6.6;
hole_center_distance = 12.7;

module hull_shape(d, hole_center_distance) {
  hull() {
    translate([0, hole_center_distance / 2, 0])
      circle(d = d, $fn = 50);
    translate([0, -hole_center_distance / 2, 0])
      circle(d = d, $fn = 50);
  }
}

module main_body() {
  difference() {
    linear_extrude(height = part_b_h) {
      hull_shape(
        d = part_b_outer_d,
        hole_center_distance = hole_center_distance
      );
    }

    total_height = part_b_h;
    translate([0, hole_center_distance / 2, -1])
      cylinder(d = hole_d, h = total_height + 2, $fn = 50);

    // Cut above the bolt hole centerline to create a flat top
    cut_size = 30;
    translate([-cut_size / 2, hole_center_distance / 2, -1])
      cube([cut_size, cut_size, total_height + 2]);
  }
}

module anti_slip_flare() {
    y_center = -hole_center_distance / 2;
    flare_height = 0.5;
    flare_radius_increase = flare_height;

    d_top = part_b_outer_d;
    d_bottom = part_b_outer_d + 2 * flare_radius_increase;

    intersection() {
        // Full cone
        translate([0, y_center, 0])
            cylinder(h = flare_height, d1 = d_bottom, d2 = d_top, $fn = 50);

        // Keep -Y half only
        cut_box_size = d_bottom * 1.5;
        translate([-cut_box_size / 2, y_center - cut_box_size, -1])
            cube([cut_box_size, cut_box_size, flare_height + 2]);

        // Constrain width to +/-3.3mm
        x_constraint = 3.3;
        y_size = d_bottom * 2;
        translate([-x_constraint, y_center - y_size / 2, -1])
            cube([x_constraint * 2, y_size, flare_height + 2]);
    }
}

union() {
    main_body();
    anti_slip_flare();
}
