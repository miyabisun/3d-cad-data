include <gridfinity.scad>
include <xbrace.scad>

// 天馬 ルームケースプチ A4-23 浅型。アイリスオーヤマ側とは独立した実測値。
drawer_w = 232;
drawer_d = 323;
fit_clearance = [ 0.5, 1 ]; // 片側の余裕 [左右, 前後]。左端を21mmの半セルにする
socket_clearance = 0.1;
back_corner_r = 5;
front_rows = 4;
win_line = 2;

plate_w = drawer_w - 2 * fit_clearance[0];
plate_d = drawer_d - 2 * fit_clearance[1];
cols = plate_w / gf_pitch;
rows = floor(plate_d / gf_pitch);
rear_rows = rows - front_rows;
back_rim = plate_d - rows * gf_pitch;
left_pitch = plate_w - (ceil(cols) - 1) * gf_pitch;

// X中央=0、各片の前端Y=0、プリント面Z=0。奥片だけに奥縁とRを持たせる。
module
roomcase_puchi_plate(part_rows, rear = false)
{
    back = rear ? back_rim : 0;
    len = part_rows * gf_pitch + back;
    cut_h = gf_socket_depth + 2 * gf_over;
    echo(str("CONTRACT plate=",
             plate_w,
             "x",
             plate_d,
             " left_pitch=",
             left_pitch,
             " rows=",
             rows,
             " rear=",
             rear,
             " len=",
             len,
             " corner=",
             back_corner_r));
    difference()
    {
        gf_baseplate(cols, part_rows, [ 0, 0, 0, back ], 0, socket_clearance);
        if (rear) {
            // 奥縁は位置決めだけなので厚さ2mm。ソケット天面と分けて軽量化する。
            translate([ -plate_w / 2, part_rows * gf_pitch, 2 ])
                cube([ plate_w, back + gf_over, gf_socket_depth ]);
            for (sx = [ -1, 1 ])
                translate([
                    sx * (plate_w / 2 - back_corner_r),
                    len - back_corner_r,
                    -gf_over
                ]) linear_extrude(cut_h) difference()
                {
                    translate([ sx > 0 ? 0 : -back_corner_r, 0 ])
                        square(back_corner_r + gf_over);
                    circle(r = back_corner_r, $fn = gf_fn * 2);
                }
            for (c = [0:ceil(cols) - 1]) {
                width = c == 0 ? left_pitch : gf_pitch;
                x = -plate_w / 2 + (c == 0 ? left_pitch / 2
                                           : left_pitch + (c - 0.5) * gf_pitch);
                translate([ x, len - back / 2, -gf_over ]) linear_extrude(cut_h)
                    xbrace_window([ width - 2 * win_line, back - 2 * win_line ],
                                  win_line);
            }
        }
    }
}
