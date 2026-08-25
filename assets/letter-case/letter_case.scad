include <../../modules/gridfinity.scad>
include <../../modules/honeycomb.scad>

// スタック式レターケースの引き出しへ敷く Gridfinity ベースプレートの共通値。
// 設計の経緯と確定値は ledger/designs/letter-case-gridfinity.md が正本。
// このファイルは前片・奥片の両 asset から include され、単体では何も描かない。
//
// 引き出しの床は、左右と奥の 14mm 幅が 3.5mm 低い (中央が高い)。板は高い
// 中央床 (212x304) の上に乗り、縁はくぼみの上を浮いて跨ぐ (くぼみの斜面には
// 触れない)。そのため板の外形は引き出し内寸いっぱいで、引き出し内で滑らない。
// 床は持たない (ソケットは底まで抜け、bin は引き出しの床に直接乗る)。
// くぼみを跨ぐ左右と奥の縁は、外周・ソケット際・端に無垢の枠を残して
// 貫通ハニカムで肉抜きする。前縁 (4mm) はそのまま。
//
// 座標系 (各片の datum):
//   X = 横方向。板の中央が 0
//   Y = 奥行き方向。各片の前端 (前片は引き出しの前、奥片は継ぎ目) が 0
//   Z = 0 が板の底面 (プリント面)。ソケットは +Z へ開く
//
// 印刷向き: 底面 (z=0) をビルドプレートへ置く。ソケットの面取りは 45° で
// サポート不要。

// --- 引き出しの実測値 (user のメジャー実測。誤差あり) ---
drawer_w = 240;    // 内寸 横
drawer_d = 318;    // 内寸 奥行き
recess_w = 14;     // 左右・奥のくぼみの幅
recess_drop = 3.5; // くぼみの深さ (中央床との段差)。板は跨ぐだけで使わない

// --- 設計値 ---
fit_clearance = 1; // 引き出し内壁との片側クリアランス (メジャー実測の誤差込み)
floor_t = 0; // ソケット底の床厚。0 = 床なし (bin が引き出しの床に乗る)
cols = 5;       // 横のマス数 (240/42 = 5.71)
rows = 7;       // 奥行きのマス数 (318/42 = 7.57)
front_rows = 4; // 前片の行数。残りが奥片。分割は 42mm 境界で行う
rear_rows = rows - front_rows;
// 縁のハニカム。0.4mm ノズルで枠 6 本・壁 4 本相当
hex_hole = 3.6;   // 六角穴の二面幅
hex_wall = 1.6;   // 穴同士の壁
hex_border = 2.4; // 外周・ソケット際・端に残す無垢の枠

// --- 派生値 ---
plate_w = drawer_w - 2 * fit_clearance; // 238
plate_d = drawer_d - 2 * fit_clearance; // 316
grid_w = cols * gf_pitch;               // 210
grid_d = rows * gf_pitch;               // 294
side_rim = (plate_w - grid_w) / 2;      // 14 (= くぼみの幅)
// 奥行きは高い床 (drawer_d − recess_w = 304) の中央へ grid を置く
raised_d = drawer_d - recess_w;                     // 304
raised_slack = (raised_d - grid_d) / 2;             // 5
front_rim = raised_slack - fit_clearance;           // 4
back_rim = recess_w + raised_slack - fit_clearance; // 18
front_len = front_rim + front_rows * gf_pitch;      // 172
rear_len = rear_rows * gf_pitch + back_rim;         // 144
hex_side_w = side_rim - 2 * hex_border; // 9.2: 左右の縁の肉抜き幅
hex_back_w = back_rim - 2 * hex_border; // 13.2: 奥の縁の肉抜き幅

contract = str("CONTRACT plate=",
               plate_w,
               "x",
               plate_d,
               " grid=",
               cols,
               "x",
               rows,
               " pitch=",
               gf_pitch,
               " socket=",
               gf_socket_top,
               "/",
               gf_socket_mid,
               "/",
               gf_socket_bot,
               " depth=",
               gf_socket_depth,
               " floor=",
               floor_t,
               " rim=L",
               side_rim,
               "/R",
               side_rim,
               "/F",
               front_rim,
               "/B",
               back_rim,
               " hex=",
               hex_hole,
               "/",
               hex_wall,
               "/",
               hex_border);

// 板 1 枚。rows 行のソケットに縁 rim = [left, right, front, back] を付け、
// 左右の縁 (Y 範囲 side_y = [y0, y1]) と、back > 0 なら奥の縁をハニカムで抜く
module
letter_case_plate(rows, rim, side_y)
{
    len = rim[2] + rows * gf_pitch + rim[3];
    difference()
    {
        gf_baseplate(cols, rows, rim, floor_t);
        // 左右の縁: 行方向を Y に向けて置く
        side_len = side_y[1] - side_y[0] - 2 * hex_border;
        for (sx = [ -1, 1 ])
            translate([
                sx * (plate_w - side_rim) / 2,
                (side_y[0] + side_y[1]) / 2,
                -gf_over
            ]) linear_extrude(gf_socket_depth + 2 * gf_over) rotate(90)
                honeycomb([ side_len, hex_side_w ], hex_hole, hex_wall);
        // 奥の縁: 左右の枠 (hex_border) の内側で全幅
        if (rim[3] > 0)
            translate([ 0, len - rim[3] / 2, -gf_over ])
                linear_extrude(gf_socket_depth + 2 * gf_over)
                    honeycomb([ plate_w - 2 * hex_border, hex_back_w ],
                              hex_hole,
                              hex_wall);
    }
}
