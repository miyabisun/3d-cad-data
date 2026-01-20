// Dryer Drain Hose Adapter
//
// Description:
// Adapts a dryer drain hose (Male) to a washing machine drain port (Male).
// Both sides are Female (Holes).
//
// Dimensions (with shrinkage compensation +1.0mm applied):
// - Side A (Dryer): Hose OD 15.2mm -> Hole ID 16.2mm
// - Side B (Washer): Port OD 14.5mm -> Hole ID 15.5mm
// - Insertion Depth: 25mm each

$fn = 64;

// --- Parameters ---

// Side A (Dryer - Top)
hose_a_target_od = 15.2;
hose_a_shrinkage_comp = 0.6; // Reduced from 1.0 based on feedback (Total -0.4mm)
hose_a_id = hose_a_target_od + hose_a_shrinkage_comp; // 15.8mm
hose_a_depth = 35.0; // Increased from 25.0

// Side B (Washer - Bottom)
hose_b_target_od = 14.5;
hose_b_shrinkage_comp = 1.0; // Good fit, kept as is
hose_b_id = hose_b_target_od + hose_b_shrinkage_comp; // 15.5mm
hose_b_depth = 35.0; // Increased from 25.0

// Adapter Wall
wall_thickness = 2.5;

// Outer Diameter (Unified for printability)
// Use the largest ID to determine the minimum OD, then apply consistent OD.
max_id = max(hose_a_id, hose_b_id);
adapter_od = max_id + (wall_thickness * 2);

// --- Modules ---

module drain_adapter() {
  union() {
    // Side B (Bottom) - Washer Side
    difference() {
      cylinder(d = adapter_od, h = hose_b_depth);
      translate([0, 0, -0.1])
        cylinder(d = hose_b_id, h = hose_b_depth + 0.2);
    }
    
    // Side A (Top) - Dryer Side
    // Stacked on top of Side B
    translate([0, 0, hose_b_depth])
    difference() {
      cylinder(d = adapter_od, h = hose_a_depth);
      translate([0, 0, -0.1])
        cylinder(d = hose_a_id, h = hose_a_depth + 0.2);
    }
    
    // Internal Stopper / Transition
    // Since IDs are different (16.2 vs 15.5), there is a naturally formed step of 0.35mm radius.
    // This serves as a stopper so the hoses don't slide through indefinitely.
    // If a more prominent stopper is needed, we could add a ring in between.
    // For now, the natural step plus the fact that they meet in the middle is good.
  }
}

drain_adapter();
