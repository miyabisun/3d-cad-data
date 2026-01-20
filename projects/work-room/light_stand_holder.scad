// Light Stand Wall Mount
//
// Description:
// A wall mount bracket designed to hold a light stand pole (12mm diameter).
// It attaches to a wooden pillar using wood screws.

$fn = 64;

// --- Parameters ---

// Pole Dimensions
pole_diameter = 12.0;
pole_insert_depth = 30.0;
pole_clearance = 1.4; // Increased from 0.4 to compensate for 3D printer shrinkage (~1mm observed)

// Holder Dimensions
holder_wall_thickness = 3.0;
holder_od = pole_diameter + pole_clearance + (holder_wall_thickness * 2);

// Wall Mount Base Dimensions
base_thickness = 5.0;
// Base height is primarily determined by the pole insert depth
base_height = pole_insert_depth; 

// Screw Position Parameters
screw_hole_spacing = holder_od + 20.0; // Distance between screw hole centers
base_width = screw_hole_spacing + 15.0; // Total width to accommodate screws

// Mounting Screw Parameters (Countersunk Wood Screw)
screw_hole_diameter = 4.0;       // Shank diameter
screw_head_diameter = 8.0;       // Head diameter
screw_head_countersink_depth = 3.0; 

// --- Modules ---

module screw_hole_countersunk() {
  rotate([0, 90, 0]) {
    // Shank hole
    cylinder(d = screw_hole_diameter, h = base_thickness * 3, center = true);
    
    // Countersink head (positioned to be flush with surface)
    // The surface is at global X=0.
    // Inside rotate([0,90,0]), global X corresponds to local Z.
    // We want the wide part (d2) at Z=0, and narrow part (d1) at Z = -screw_head_countersink_depth.
    translate([0, 0, -screw_head_countersink_depth])
      cylinder(d1 = screw_hole_diameter, d2 = screw_head_diameter, h = screw_head_countersink_depth + 0.01);
      
    // Head clearance (cylindrical cutout for the head itself entering from outside)
    // From Z=0 outwards to +Z
    translate([0, 0, 0])
      cylinder(d = screw_head_diameter, h = 10);
  }
}

module light_stand_holder() {
  difference() {
    union() {
      // 1. Base Plate Body (Wider now)
      translate([-base_thickness/2, 0, 0])
        cube([base_thickness, base_width, base_height], center = true);

      // 2. Connector (Hull) between Base and Holder
      // We hull the cylinder with a thin slice of the base plate to create a strong joint
      hull() {
        // Slice of base plate (central part only)
        translate([-base_thickness/2 + 0.1, 0, 0])
           cube([0.1, holder_od, base_height], center = true);
        
        // The Holder Cylinder Outer Shell
        translate([holder_od/2 + base_thickness/2, 0, 0])
           cylinder(d = holder_od, h = base_height, center = true);
      }
    }

    // --- Subtractions ---

    // 1. Pole Hole (Blind hole, solid bottom)
    // Positioned so the top is open.
    // Cylinder is centered in Z (range -base_height/2 to +base_height/2)
    // We want the hole to start at top (+base_height/2) and go down 'pole_insert_depth'
    
    translate([holder_od/2 + base_thickness/2, 0, base_height/2 - pole_insert_depth/2 + 0.1])
      // slightly strictly speaking, if base_height == insert_depth, it goes all the way through minus bottom if we adjust.
      // Current base_height = 30, depth = 30. It will be open at bottom.
      // Let's add a floor.
      // To have a floor, the base_height should be slightly larger than insert depth, OR we shift the hole up.
      // Let's make the hole NOT go all the way through designated depth, but stopped by variable.
      // Actually, let's allow it to be through-hole if height matches, but user wants to "rest" it.
      // Let's add a solid bottom cap to the geometry, or just don't drill all the way.
      // Let's shift the hole up so it leaves 2mm at bottom.
      translate([0, 0, 2]) 
        cylinder(d = pole_diameter + pole_clearance, h = pole_insert_depth + 1, center = true);

    // 2. Screw Holes (Left and Right)
    // Located at Y = +/- screw_hole_spacing/2
    translate([0, screw_hole_spacing/2, 0])
      screw_hole_countersunk();
      
    translate([0, -screw_hole_spacing/2, 0])
      screw_hole_countersunk();
  }
}

// Render the part
light_stand_holder();
