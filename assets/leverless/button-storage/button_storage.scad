include <../../../modules/gridfinity_bin.scad>

// FlashTap収納: part="upper" / "lower"を各1個印刷。assemblyは確認用。
part = "assembly";
hole_clearance = 0.4; // 穴径の実プリント調整。中心間距離は変えない。
cols = 3.5;
rows = 5;
plate_t = 3;
depth = rows * gf_pitch - 0.5;
row_pitch = 29 * sqrt(3) / 2;
large_offset = sqrt(pow(31.5, 2) - pow(14.5, 2));
field_depth = 14.5 + 5 * row_pitch + large_offset + 17;
first_y = (depth - field_depth) / 2 + 14.5;
buttons = concat(
    [for (r = [0:5], c = [0:3])
        [-50.75 + 29 * c + (r % 2) * 14.5, first_y + r * row_pitch, 24]],
    [for (x = [-21.75, 36.25])
        [x, first_y + 5 * row_pitch + large_offset, 30]]);
// 薄いリップへの理論着座は約21.06。表示は丸めて0.04mm逃がす。
stack_z = 21.1;

module storage_upper() {
    difference() {
        union() {
            gfb_bin(cols, rows, 1);
            // 全域を1個の足にして、底のセル境界をすべて繋ぐ。
            translate([0, depth / 2, 0])
                gfb_base_cell([cols * gf_pitch, rows * gf_pitch]);
        }
        // 底から3mmを残す。外周3mmは嵌合面と壁を繋ぐ枠として残す。
        translate([0, 0, plate_t])
            linear_extrude(12) gfb_footprint(cols, rows, 3);
        for (b = buttons)
            translate([b[0], b[1], -gf_over])
                cylinder(d = b[2] + hole_clearance, h = 12, $fn = 96);
    }
}

assert(hole_clearance >= 0 && hole_clearance <= 1,
       "hole_clearance must be between 0 and 1mm");
assert(part == "upper" || part == "lower" || part == "assembly",
       "part must be upper, lower or assembly");
if (part == "upper")
    storage_upper();
else if (part == "lower")
    gfb_bin(cols, rows, 3);
else {
    color("lightgray") gfb_bin(cols, rows, 3);
    color("steelblue") translate([0, 0, stack_z]) storage_upper();
}
