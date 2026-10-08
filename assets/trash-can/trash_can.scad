include <../../modules/trash_can.scad>

// Assembly view, not printed.
bottom_ring();
translate([0, 0, height]) mirror([0, 0, 1]) top_ring();
translate([0, 0, height + wall]) mirror([0, 0, 1]) lid();
