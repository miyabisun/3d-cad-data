jig_width = 10;
hinge_length = 34;
frame_lip = 4;
base_thickness = 3;
leaf_offset = 1.5;
jig_thickness = base_thickness + leaf_offset;
raised_edge_height = 2;

total_length = hinge_length + frame_lip;

union() {
  cube([jig_width, total_length, jig_thickness]);
  cube([2, total_length, jig_thickness + raised_edge_height]);
  cube([jig_width, 2, jig_thickness + raised_edge_height]);
  translate([0, total_length - 2, 0])
    cube([jig_width, 2, jig_thickness + raised_edge_height]);
}
