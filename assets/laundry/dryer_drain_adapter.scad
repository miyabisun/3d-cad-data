$fn = 64;

// Side A (Dryer - Top)
hose_a_target_od = 15.2;
hose_a_shrinkage_comp = 0.6; // adjusted from 1.0 based on test print
hose_a_id = hose_a_target_od + hose_a_shrinkage_comp;
hose_a_depth = 35.0;

// Side B (Washer - Bottom)
hose_b_target_od = 14.5;
hose_b_shrinkage_comp = 1.0;
hose_b_id = hose_b_target_od + hose_b_shrinkage_comp;
hose_b_depth = 35.0;

wall_thickness = 2.5;
max_id = max(hose_a_id, hose_b_id);
adapter_od = max_id + (wall_thickness * 2);

module drain_adapter() {
  union() {
    difference() {
      cylinder(d = adapter_od, h = hose_b_depth);
      translate([0, 0, -0.1])
        cylinder(d = hose_b_id, h = hose_b_depth + 0.2);
    }

    translate([0, 0, hose_b_depth])
    difference() {
      cylinder(d = adapter_od, h = hose_a_depth);
      translate([0, 0, -0.1])
        cylinder(d = hose_a_id, h = hose_a_depth + 0.2);
    }
  }
}

drain_adapter();
