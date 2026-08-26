include <../../modules/gridfinity.scad>
include <../../modules/xbrace.scad>

// スタック式レターケースの引き出しへ敷く Gridfinity ベースプレートの共通値。
// 設計の経緯と確定値は ledger/designs/letter-case-gridfinity.md が正本。
// このファイルは前片・奥片の両 asset から include され、単体では何も描かない。
//
// 引き出しの床は、左右と奥の 14mm 幅が 3.5mm 低い (中央が高い)。板は高い
// 中央床 (212x304) の上に乗り、縁はくぼみの上を浮いて跨ぐ (くぼみの斜面には
// 触れない)。そのため板の外形は引き出し内寸いっぱいで、引き出し内で滑らない。
// 床は持たない (ソケットは底まで抜け、bin は引き出しの床に直接乗る)。
// くぼみを跨ぐ左右と奥の縁は、bin の境目 (42mm ピッチ) に沿った四角い窓を
// 貫通で開け、窓の対角に X の筋交いを渡して肉抜きする。枠・リブ・筋交いは
// すべて同じ線幅。前縁 (2.5mm) はそのまま。
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
// --- 実プリントの合わせ込み (2026-08-26 の試作から。実測値は書き換えない) ---
side_extend = 1.5; // 横がスカスカ (4mm 弱) だったので左右を 1.5 ずつ伸ばす
front_trim = 1.5; // 前後が 1.5 ほどオーバーしたので手前の縁を削る
back_corner_r = 6; // 引き出しの奥の内角が丸いので、奥片の奥側 2 隅を R6 にする
floor_t = 0; // ソケット底の床厚。0 = 床なし (bin が引き出しの床に乗る)
cols = 5;       // 横のマス数 (240/42 = 5.71)
rows = 7;       // 奥行きのマス数 (318/42 = 7.57)
front_rows = 4; // 前片の行数。残りが奥片。分割は 42mm 境界で行う
rear_rows = rows - front_rows;
// 縁の X 筋交い窓。枠 (外周・ソケット際・各片の端)、窓の間のリブ、筋交いの線幅
win_line = 2;

// --- 派生値 ---
plate_w = drawer_w - 2 * fit_clearance + 2 * side_extend; // 241
plate_d = drawer_d - 2 * fit_clearance - front_trim;      // 314.5
grid_w = cols * gf_pitch;                                 // 210
grid_d = rows * gf_pitch;                                 // 294
side_rim = (plate_w - grid_w) / 2; // 15.5 (くぼみの幅 14 + 1.5)
// 奥行きは高い床 (drawer_d − recess_w = 304) の中央へ grid を置く
raised_d = drawer_d - recess_w;                        // 304
raised_slack = (raised_d - grid_d) / 2;                // 5
front_rim = raised_slack - fit_clearance - front_trim; // 2.5
back_rim = recess_w + raised_slack - fit_clearance;    // 18
front_len = front_rim + front_rows * gf_pitch;         // 170.5
rear_len = rear_rows * gf_pitch + back_rim;            // 144
side_win_w = side_rim - 2 * win_line; // 11.5: 左右の窓の幅 (X 方向)
back_win_d = back_rim - 2 * win_line; // 14: 奥の窓の奥行き (Y 方向)

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
               " xwin=",
               win_line,
               " corner=",
               back_corner_r);

// 板 1 枚。rows 行のソケットに縁 rim = [left, right, front, back] を付け、
// 左右の縁に行ごとの窓、back > 0 なら奥の縁に列ごとの窓を開ける。
// 左右の窓は行の境目 (42mm ピッチ) に線幅のリブを置くため、各行の範囲を
// 前後 line/2 ずつ縮めた長さになる。ただし各片の端 (継ぎ目・前縁側) は
// 端から line を残すので、端の窓だけ line/2 短い
module
letter_case_plate(rows, rim)
{
    len = rim[2] + rows * gf_pitch + rim[3];
    cut_h = gf_socket_depth + 2 * gf_over;
    difference()
    {
        gf_baseplate(cols, rows, rim, floor_t);
        // 奥縁を持つ片 (奥片) は、奥側 2 隅を R に丸める:
        // 隅の正方形から円を引いた残りを削る
        if (rim[3] > 0)
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
        for (r = [0:rows - 1]) {
            y0 = max(rim[2] + r * gf_pitch + win_line / 2, win_line);
            y1 =
                min(rim[2] + (r + 1) * gf_pitch - win_line / 2, len - win_line);
            for (sx = [ -1, 1 ])
                translate(
                    [ sx * (plate_w - side_rim) / 2, (y0 + y1) / 2, -gf_over ])
                    linear_extrude(cut_h)
                        xbrace_window([ side_win_w, y1 - y0 ], win_line);
        }
        if (rim[3] > 0)
            for (c = [0:cols - 1])
                translate([
                    (c - (cols - 1) / 2) * gf_pitch,
                    len - rim[3] / 2,
                    -gf_over
                ]) linear_extrude(cut_h)
                    xbrace_window([ gf_pitch - win_line, back_win_d ],
                                  win_line);
    }
}
