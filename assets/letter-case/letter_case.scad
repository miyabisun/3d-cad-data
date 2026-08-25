use <../../modules/gridfinity.scad>
include <../../modules/gridfinity.scad>

// スタック式レターケースの引き出しへ敷く Gridfinity ベースプレートの共通値。
// 設計の経緯と確定値は ledger/designs/letter-case-gridfinity.md が正本。
// このファイルは前片・奥片の両 asset から include され、単体では何も描かない。
//
// 引き出しの床は、左右と奥の 14mm 幅が 3.5mm 低い (中央が高い)。板は高い
// 中央床 (212x304) の上に乗り、縁はくぼみの上を浮いて跨ぐ (くぼみの斜面には
// 触れない)。そのため板の外形は引き出し内寸いっぱいで、引き出し内で滑らない。
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
floor_t = 1;       // ソケット底の床厚
cols = 5;          // 横のマス数 (240/42 = 5.71)
rows = 7;          // 奥行きのマス数 (318/42 = 7.57)
front_rows = 4;    // 前片の行数。残りが奥片。分割は 42mm 境界で行う
rear_rows = rows - front_rows;

// --- 派生値 ---
plate_w = drawer_w - 2 * fit_clearance; // 238
plate_d = drawer_d - 2 * fit_clearance; // 316
grid_w = cols * gf_pitch;               // 210
grid_d = rows * gf_pitch;               // 294
side_rim = (plate_w - grid_w) / 2;      // 14 (= くぼみの幅)
// 奥行きは高い床 (drawer_d − recess_w = 304) の中央へ grid を置く
raised_d = drawer_d - recess_w;               // 304
raised_slack = (raised_d - grid_d) / 2;       // 5
front_rim = raised_slack - fit_clearance;     // 4
back_rim = recess_w + raised_slack - fit_clearance; // 18
front_len = front_rim + front_rows * gf_pitch;   // 172
rear_len = rear_rows * gf_pitch + back_rim;      // 144

contract = str("CONTRACT plate=", plate_w, "x", plate_d, " grid=", cols, "x", rows,
               " pitch=", gf_pitch, " socket=", gf_socket_top, "/", gf_socket_mid, "/",
               gf_socket_bot, " depth=", gf_socket_depth, " floor=", floor_t, " rim=L",
               side_rim, "/R", side_rim, "/F", front_rim, "/B", back_rim);
