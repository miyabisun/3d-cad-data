// Gridfinity ベースプレートの共有 module。
// 寸法は Gridfinity 仕様 (Zack Freedman) の baseplate 輪郭に従う:
//   ピッチ 42、ソケット上端開口 41.5 (角 R4)、上から 45° 面取り 2.15 →
//   垂直 1.8 (37.2 角・R1.85) → 45° 面取り 0.7 → 底 35.8 角 (R1.15)。
//   ソケット深さ = 2.15 + 1.8 + 0.7 = 4.65。
//
// 座標系: X が列方向 (中央が 0)、Y が行方向 (板の前端が 0)、Z=0 が板の底面。
// 板の外形は grid とは独立に rim で与えるので、grid より大きい板 (縁付き) を
// 作れる。ソケットは rim=[left, right, front, back] の内側へ 42 ピッチで並ぶ。

gf_pitch = 42;
gf_socket_top = 41.5; // 上端開口
gf_socket_mid = 37.2; // 垂直部
gf_socket_bot = 35.8; // 底
gf_socket_r_top = 4;
gf_socket_r_mid = 1.85;
gf_socket_r_bot = 1.15;
gf_chamfer_top = 2.15;
gf_wall_h = 1.8;
gf_chamfer_bot = 0.7;
gf_socket_depth = gf_chamfer_top + gf_wall_h + gf_chamfer_bot; // 4.65
gf_fn = 32;
gf_eps = 0.01;  // hull 用の薄板の厚さ
gf_over = 0.5;  // 切削の抜き代

// 角丸正方形 (一辺 w、角 R)
module gf_rounded_square(w, r) {
  offset(r = r, $fn = gf_fn) square(w - 2 * r, center = true);
}

// 厚さ gf_eps の角丸正方形の薄板を z に置く (hull の骨)
module gf_slab(w, r, z) {
  translate([ 0, 0, z ]) linear_extrude(gf_eps) gf_rounded_square(w, r);
}

// ソケット1個の切削体。z=0 がソケットの底 (床の天面)、+Z へ 4.65 で天面に出る
module gf_socket_cut() {
  z1 = gf_chamfer_bot;
  z2 = z1 + gf_wall_h;
  z3 = gf_socket_depth;
  hull() {
    gf_slab(gf_socket_bot, gf_socket_r_bot, 0);
    gf_slab(gf_socket_mid, gf_socket_r_mid, z1 - gf_eps);
  }
  hull() {
    gf_slab(gf_socket_mid, gf_socket_r_mid, z1 - gf_eps);
    gf_slab(gf_socket_mid, gf_socket_r_mid, z2 - gf_eps);
  }
  hull() {
    gf_slab(gf_socket_mid, gf_socket_r_mid, z2 - gf_eps);
    gf_slab(gf_socket_top, gf_socket_r_top, z3 - gf_eps);
  }
  // 天面より上へ抜く (天面と同一平面の退化した面を残さない)
  gf_slab(gf_socket_top, gf_socket_r_top, z3 - gf_eps);
  translate([ 0, 0, z3 - gf_eps ])
    linear_extrude(gf_over + gf_eps) gf_rounded_square(gf_socket_top, gf_socket_r_top);
}

// ベースプレート。cols x rows のソケットを床 floor_t の上に彫る。
// rim = [left, right, front, back] はソケット列の外側に残す縁の幅。
// 板の幅 = cols*42 + left + right、奥行き = rows*42 + front + back。
module gf_baseplate(cols, rows, rim = [ 0, 0, 0, 0 ], floor_t = 1) {
  grid_w = cols * gf_pitch;
  grid_d = rows * gf_pitch;
  plate_w = grid_w + rim[0] + rim[1];
  plate_d = grid_d + rim[2] + rim[3];
  x0 = -plate_w / 2 + rim[0]; // ソケット列の左端
  difference() {
    translate([ -plate_w / 2, 0, 0 ]) cube([ plate_w, plate_d, floor_t + gf_socket_depth ]);
    for (c = [0:cols - 1], r = [0:rows - 1])
      translate([ x0 + (c + 0.5) * gf_pitch, rim[2] + (r + 0.5) * gf_pitch, floor_t ])
        gf_socket_cut();
  }
}
