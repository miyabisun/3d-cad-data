use <../../../modules/bolts.scad>
use <../../../modules/steel_rack.scad>
use <../../../modules/slide_rail_outer_bracket.scad>

// 90cm柱（外寸29.2角・板厚2）用。原点は柱の内側2面の交点。
// 底板を下に印刷し、使用時は反転して平らなZ=0面でアクリルを受ける。
// M4ナットは印刷時の上側（内側）から挿入。使用時には天板の裏側となる。
// M4中心17×17は樹脂部品のX=0/Y=0基準。板の角もこの基準へ合わせる。
// M6は柱の外から。ナットは内側へ斜めから差し込み、座面へ寄せて穴中心へ合わせる。
// アクリル受けはM6ナットを先に入れ、その後M4でアクリルを締結する。
// 寸法・挿入経路はSTL検証対象。荷重試験と実物の嵌合は未実施。
// 最上部用はM6中心高さの配列を渡す。Zは座面から柱に沿って下向きの距離。
module corner_acrylic_support(m6_levels = undef, m8_foot = false) {
  arm = 27;
  wall = 10;
  base = m8_foot ? 14 : 10; // ゴム足用は底面側へ4mm増厚。印刷底面はZ=0。
  outer_r = 2; // 柱に沿う縦稜。平らな接触面と底面は残す。
  inner_r = 5; // 壁同士と底板/壁の凹隅を補強。
  tip_r = 10; // ラック中央側の自由角。中心はM4穴と同じ17×17。

  m6_pass_flat = 6.4;
  m6_nut_flat = 10.4;
  m6_nut_depth = m8_foot ? 5.6 : 5.4; // 脚用はさらに0.2柱側へ寄せ、M8の遊びも逃がす。
  m6_center = 29.2 - 2 - 8 - 7 / 2; // 自由端→穴縁8、穴幅7: 内側基準15.7。
  m6_z = base + m6_nut_flat / 2; // 底板を削らない最小中心。通常15.2、ゴム足用19.2。
  levels = is_undef(m6_levels) ? [m6_z] : m6_levels;
  height = max(levels) + m6_pass_flat / 2 + 7.5; // 自由端側の余肉を維持。
  m6_seat = wall - m6_nut_depth;
  m4_center = 17;
  m4_nut_flat = 7.4;
  m4_nut_depth = 3.4;

  assert(min(levels) >= m6_z);
  assert(len(levels) == 1 || (len(levels) == 2 && levels[1] > levels[0] + m6_nut_flat));
  assert(base > m4_nut_depth && m6_seat > 0);
  // AF10×厚5のM6ナットが窪み内で角側へ寄っても、座った状態で交差しない。
  assert(m6_center - m6_nut_flat / sqrt(3) > m6_seat + 5);

  module m6_cut(z) {
    translate([m6_seat / 2, m6_center, z])
      hex_x_flat_up(m6_pass_flat, m6_seat + 0.2);
    // 直交するM6穴の中心で止め、向こう側の壁を削らない。
    translate([(m6_seat + m6_center) / 2, m6_center, z])
      hex_x_flat_up(m6_nut_flat, m6_center - m6_seat);
  }

  difference() {
    linear_extrude(height)
      translate([outer_r, outer_r])
        offset(r = outer_r, $fn = 64)
          square([arm - 2 * outer_r, arm - 2 * outer_r]);

    // 開いた内側空間を丸めて引く。三面が合う底の隅も球面でつなぐ。
    translate([wall + inner_r, wall + inner_r, base + inner_r])
      minkowski() {
        cube([arm, arm, height]);
        sphere(r = inner_r, $fn = 64);
      }

    translate([arm - tip_r, arm - tip_r, height / 2])
      fillet_profile(tip_r, height + 0.2);

    for (z = levels) {
      m6_cut(z);
      mirror([1, -1, 0]) m6_cut(z);
    }

    if (m8_foot) {
      m8_nut_depth = 4.8; // 従来の6.8から2mm浅くし、厚6.5のナットは1.7mm突出。
      // M8軸はR5のある高さまで通るため、全高にわたって逃がす。
      translate([m4_center, m4_center, -0.1]) m8_bolt_hole(height + 0.2);
      // 内側挿入。座面厚9.2。ナットの切削はM6中心高さで止める。
      // 対辺の法線をL字の二等分線45度へ向ける（六角の初期法線30度＋15度）。
      translate([m4_center, m4_center, base - m8_nut_depth])
        rotate([0, 0, 15])
          m8_nut_trap(m6_z - base + m8_nut_depth);
    } else {
      translate([m4_center, m4_center, -0.1]) m4_bolt_hole(base + 0.2);
      // R5と重なる箇所も上まで開放し、ナットを真っ直ぐ挿入できるようにする。
      translate([m4_center, m4_center, base - m4_nut_depth])
        nut_trap(m4_nut_flat, height - base + m4_nut_depth + 0.1, center = false);
    }
  }
}

corner_acrylic_support();
