include <gridfinity_bin.scad>

// 天馬用。STLの初期配置で横5.5マス、奥行rowsマス、左半セル。
gfc_cols = 5.5;
gfc_units = 9;
gfc_wall = 1.2;
gfc_floor_t = 1.2;
gfc_pitch = 10;
gfc_slot_count = 22;
gfc_plate_t = 2;
gfc_slot_clearance = 0.4; // 板厚に足す総量。実プリントで調整する
gfc_slot_depth = 2;
gfc_end_clearance = 0.2; // 板の前後端と溝底の片側の余裕
gfc_leg = 10;
gfc_center_ratio = 0.7;
gfc_frame = 10;
gfc_web = 10;
gfc_cross_y = 22.5;
gfc_window_r = 2;

gfc_width = gfc_cols * gf_pitch - 0.5;
gfc_floor_top = gfb_base_h + gfc_floor_t;
gfc_top = gfc_units * gfb_unit + gfb_lip_h;
gfc_plate_h = gfc_units * gfb_unit - gfc_floor_top;

function gfc_depth(rows) = rows * gf_pitch - 0.5;
function gfc_divider_length(rows) =
    gfc_depth(rows) - 2 * (gfc_wall + gfc_end_clearance);

// ラベル棚は設けず、前後の補強壁の内側へ上端まで開いた溝を作る。
module gfc_holder(rows)
{
    depth = gfc_depth(rows);
    slot_w = gfc_plate_t + gfc_slot_clearance;
    difference()
    {
        union()
        {
            gfb_bin(gfc_cols, rows, gfc_units, gfc_wall, gfc_floor_t);
            intersection()
            {
                translate([ 0, 0, gfc_floor_top - gf_eps ])
                    linear_extrude(gfc_top - gfc_floor_top + gf_eps)
                        gfb_footprint(gfc_cols, rows);
                for (y = [ 0, depth - gfc_wall - gfc_slot_depth ])
                    translate([ -gfc_width / 2, y, gfc_floor_top - gf_eps ])
                        cube([ gfc_width, gfc_wall + gfc_slot_depth,
                               gfc_top - gfc_floor_top + gf_eps ]);
            }
        }
        for (i = [0:gfc_slot_count - 1], rear = [0:1])
            translate([
                (i - (gfc_slot_count - 1) / 2) * gfc_pitch - slot_w / 2,
                rear ? depth - gfc_wall - gfc_slot_depth - gf_over : gfc_wall,
                gfc_floor_top
            ]) cube([ slot_w, gfc_slot_depth + gf_over,
                      gfc_top - gfc_floor_top + gf_over ]);
    }
}

// 中央と両端で水平になる浅いU字。溝と床に合わせ、外形の四隅は直角。
module gfc_divider_outline(length)
{
    span = length / 2 - gfc_leg;
    low = gfc_plate_h * gfc_center_ratio;
    polygon(concat(
        [[-length / 2, 0], [length / 2, 0], [length / 2, gfc_plate_h]],
        [for (i = [0:100]) let(x = span * (1 - 2 * i / 100))
            [x, low + (gfc_plate_h - low) * (1 - cos(180 * x / span)) / 2]],
        [[-length / 2, gfc_plate_h]]));
}

// 2つの大窓へ幅10mmの十字桟を残し、計8つの小窓に分ける。
// 組立時は床z=5.95に載り、板上端はz=63（リップより4.4mm低い）。
module gfc_divider(rows)
{
    length = gfc_divider_length(rows);
    window_w = (length - 2 * gfc_leg - gfc_web) / 2;
    small_w = (window_w - gfc_web) / 2;
    linear_extrude(gfc_plate_t) difference()
    {
        gfc_divider_outline(length);
        for (x = [-length / 2 + gfc_leg, gfc_web / 2], col = [0:1], row = [0:1])
            offset(r = gfc_window_r, $fn = gf_fn * 2)
                offset(delta = -gfc_window_r) intersection()
                {
                    offset(delta = -gfc_frame) gfc_divider_outline(length);
                    translate([x + col * (small_w + gfc_web),
                               row ? gfc_cross_y + gfc_web / 2 : 0])
                        square([small_w, row ? gfc_plate_h : gfc_cross_y - gfc_web / 2]);
                }
    }
}
