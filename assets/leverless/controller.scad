// 部品は印刷姿勢。assemblyだけ組立座標: X=左右、Y=手前→奥、Z=高さ。
part = "assembly"; // [assembly,frame,top_left,top_right,bottom,corner_post,corner_post_right,center_post,corner_nut_plug,center_nut_plug,wall,button_layout]
half_w = 200;
case_d = 200;
post_w = 20;
post_h = 50;
wall_t = 5;
top_t = 6;
bottom_t = 5;
edge_r = 3;
inner_chamfer = 5.5; // ナット入口の全幅7.3を収める45度平面。外周Rとは独立。

bolt_d = 4.4;
head_d = 8.4; // M4皿頭の逃げ。90度テーパの高さは2mm。
nut_flat = 7.3;
nut_t = 3.5;
nut_roof = 5;
side_bolt_z = post_h / 2;
head_recess = 0.2;
bridge_step = 0.4;
plug_clearance = 0.4; // 幅・高さの合計の逃げ。各面は0.2mm。
plug_protrusion = 1; // 入口から外へ出し、溶かして固定する分。
plug_nut_flat = 7; // 窪み7.3mmと区別する、栓が当たる実ナットの二面幅。
wall_gap = 0.25; // 壁の長手方向の端面に片側ずつ。
wall_length = case_d - 2 * post_w;
center_w = 2 * half_w - 2 * wall_length; // 壁を6枚共通化する中央部品の幅。左右の受け各20を含む。

// 中心距離は縁の半径の和。穴径と縁径を混同しない。
button_d = 24.4;
large_button_d = 30.4;
rim_d = 27;
large_rim_d = 33;
pitch = rim_d;
mixed_pitch = (rim_d + large_rim_d) / 2;
// Vewlix寸法図の上段: 横33 / 奥14。指定ピッチへ正規化する。
// 30mmの中心を強P/Kの高さ中央へ置くため、上下列の横ずれは設けない。
right_angle = atan2(14, 33);
right_step = [pitch * cos(right_angle), pitch * sin(right_angle)];
weak_p = [65, 145 - right_step[1]];
medium_p = [65 + right_step[0], 145];
strong_p = medium_p + [pitch, 0];
weak_k = weak_p - [0, pitch];
medium_k = medium_p - [0, pitch];
strong_k = strong_p - [0, pitch];
pinky = strong_k + [sqrt(mixed_pitch * mixed_pitch - pitch * pitch / 4), pitch / 2];
// 強Kから27、30mmから30となる2円の交点のうち、右下側を選ぶ。
pinky_axis = (pinky - strong_k) / mixed_pitch;
lower_along = pitch * pitch / (2 * mixed_pitch);
lower_across = sqrt(pitch * pitch - lower_along * lower_along);
lower_pinky = strong_k + lower_along * pinky_axis + lower_across * [pinky_axis[1], -pinky_axis[0]];
thumb_step = [pitch / sqrt(2), pitch / sqrt(2)];
function hole(p, d = button_d) = [p[0], p[1], d];
right_gameplay_raw = [hole(weak_p), hole(medium_p), hole(strong_p), hole(pinky, large_button_d),
                 hole(weak_k), hole(medium_k), hole(strong_k), hole(lower_pinky),
                 hole(weak_k - thumb_step), hole(weak_k - 2 * thumb_step)];

// パリィを含む操作ボタン全体の縁から、左右の余白が等しくなる移動量を求める。
function button_rim(b) = b[2] == large_button_d ? large_rim_d : rim_d;
right_min = min([for (b = right_gameplay_raw) b[0] - button_rim(b) / 2]);
right_max = max([for (b = right_gameplay_raw) b[0] + button_rim(b) / 2]);
right_shift = (half_w - right_min - right_max) / 2;
right_reference = [for (b = right_gameplay_raw) b + [right_shift, 0, 0]];
// 全体は回さず、各Kを軸にPの中心を指定した円弧長(mm)だけ反時計回りへ。
punch_arc = [16, 6];
thumb_angle = 30;
thumb_shift = [-4, 3]; // 30度の基準配列から、ジャンプ・パリィを横へ微調整。
center_shift = 10;
function turn_hole(b, pivot, a) = let(x = b[0] - pivot[0], y = b[1] - pivot[1])
  [pivot[0] + x * cos(a) - y * sin(a), pivot[1] + x * sin(a) + y * cos(a), b[2]];
right_base = [for (i = [0 : len(right_reference) - 1])
  (i < 2 ? turn_hole(right_reference[i], right_reference[i + 4], punch_arc[i] / pitch * 180 / PI) :
   i >= 8 ? turn_hole(right_reference[i], right_reference[4], thumb_angle) : right_reference[i])
  - [center_shift, 0, 0]];
// 横移動後、中心間27mmを保って基準ボタンの手前側から奥へ詰める。
function below_button(x, b) = hole([x, b[1] - sqrt(pitch * pitch - pow(x - b[0], 2))]);
right_jump = below_button(right_base[8][0] + thumb_shift[0], right_base[4]);
right_parry = below_button(right_base[9][0] + thumb_shift[1], right_jump);
right_gameplay = concat([for (i = [0 : 7]) right_base[i]], [right_jump, right_parry]);
left_gameplay = [for (i = [2, 1, 0, 8, 9])
  [half_w - right_gameplay[i][0], right_gameplay[i][1], button_d]];
// 補助ボタンは左右の奥・中央寄りに2個ずつ。f2ash-tap向けの中心間隔29mm。
aux_pitch = 29;
aux_rim_d = 29;
// 中央から外装縁まで10mm、中央柱から外装の奥端まで5mm空ける。
buttons_aux = [for (i = [0 : 1])
  hole([10 + aux_rim_d / 2 + i * aux_pitch, case_d - post_w - 5 - aux_rim_d / 2])];
buttons_right = concat(right_gameplay, buttons_aux);
buttons_left = concat(left_gameplay, [for (b = buttons_aux) [half_w - b[0], b[1], b[2]]]);

// 公開PicoFightingBoard v1.1aの座標。BOOTH Type-C改造版との同寸性は未確認。
// 出典・穴の微小な非対称性はREADME参照。部品面をケース内側へ向け、USBは+X。
// KiCadの部品面表示を長辺X軸で裏返すので、CADの+Yを天板の+Yへ対応させる。
pcb_origin = [73, 23];
pcb_mounts_left = [];
pcb_mounts_right = [for (p = [[107.3, 83.1], [195.7, 83.2], [107.4, 120.7], [195.7, 120.5]])
  pcb_origin + [p[0] - 103.378, p[1] - 79.248]];
pcb_bolt_d = 3.4;
pcb_head_d = 6.4;

pad_w = 167;
pad_d = 77;
pad_depth = 1;
pad_y = [16, 107];
arc_fn = 64;
eps = 1 / 64; // ブーリアンの重なり。2進数で正確に表せる値で微小な面を避ける。

module hex_hole(flat, h) {
  // 軸反転で同じ頂点になる対称座標。壁と柱の接合時の微小な面を避ける。
  half_tip = flat / (2 * sqrt(3));
  linear_extrude(height = h) polygon([
    [-2 * half_tip, 0], [-half_tip, -flat / 2], [half_tip, -flat / 2],
    [2 * half_tip, 0], [half_tip, flat / 2], [-half_tip, flat / 2]
  ]);
}

module countersunk_hole(h, up = true, d = bolt_d, head = head_d) {
  seat = (head - d) / 2;
  assert(seat > 0 && seat + head_recess < h);
  translate([0, 0, up ? 0 : h]) scale([1, 1, up ? 1 : -1]) {
    rotate_extrude($fn = arc_fn)
      polygon([[0, -eps], [d / 2, -eps], [d / 2, h - head_recess - seat],
               [head / 2, h - head_recess], [head / 2, h + eps], [0, h + eps]]);
  }
}

// 隅柱はL字の内隅から、中央柱は+Yの内面から上下ナットを横差しする。
module vertical_nut_cut(x, top = true, corner = false) {
  z = top ? post_h - nut_roof - nut_t : nut_roof;
  bridge_d = bolt_d + 2 * eps; // 斜めの四角と丸穴が接する微小面を避ける、橋渡し部だけの逃げ。
  translate([x, post_w / 2, 0]) rotate([0, 0, corner ? -45 : 0]) {
    translate([0, 0, z]) linear_extrude(height = nut_t) hull() {
      rotate(30) circle(d = nut_flat / cos(30), $fn = 6);
      translate([0, 2 * post_w]) rotate(30) circle(d = nut_flat / cos(30), $fn = 6);
    }
    // 横長帯 → 正方形 → 丸穴。入口に合わせて二段のブリッジも回す。
    translate([-nut_flat / 2, -bridge_d / 2, z + nut_t - eps])
      cube([nut_flat, bridge_d, bridge_step + eps]);
    translate([-bridge_d / 2, -bridge_d / 2, z + nut_t - eps])
      cube([bridge_d, bridge_d, 2 * bridge_step + eps]);
  }
}

// X=幅、Y=差込方向、Z=高さ。上下・左右共通で平置き印刷する。
module nut_plug(corner = false) {
  face = corner ? (post_w + inner_chamfer) / sqrt(2) : post_w / 2;
  nut_tip = plug_nut_flat / sqrt(3);
  cube([nut_flat - plug_clearance, face - nut_tip + plug_protrusion, nut_t - plug_clearance]);
}

// 正面用: 軸+Y、六角収納口は柱の内面Y=20。
module front_nut_cut(x) {
  translate([x, wall_t - eps, side_bolt_z]) rotate([-90, 0, 0])
    hex_hole(bolt_d, post_w - wall_t + 2 * eps);
  translate([x, post_w - nut_t, side_bolt_z]) rotate([-90, 0, 0])
    hex_hole(nut_flat, nut_t + eps);
}

// 内部へ露出する凸角だけを丸め、ナット入口の45度平面と壁の接合面は保つ。
function quarter_arc(c, start = 0) = [for (a = [start : 360 / arc_fn : start + 90])
  c + edge_r * [cos(a), sin(a)]];

module post(center = false) {
  w = center ? center_w : 2 * post_w;
  assert(nut_roof + nut_t + 2 * bridge_step < post_h / 2);
  difference() {
    if (center) linear_extrude(height = post_h) polygon(concat(
      [[0, 0], [w, 0]],
      quarter_arc([w - edge_r, post_w - edge_r]),
      quarter_arc([edge_r, post_w - edge_r], 90)));
    else linear_extrude(height = post_h) polygon(concat(
      [for (a = [180 : 360 / arc_fn : 270]) [edge_r + edge_r * cos(a), edge_r + edge_r * sin(a)]],
      [[w, 0]], quarter_arc([w - edge_r, post_w - edge_r]),
      [[post_w + inner_chamfer, post_w], [post_w, post_w + inner_chamfer]],
      quarter_arc([post_w - edge_r, w - edge_r]), [[0, w]]));
    // 壁を全高で重ねる直角の欠き込み。天井や45度の肩は作らない。
    for (x = center ? [-eps, w - post_w] : [post_w])
      translate([x, -eps, -eps]) cube([post_w + eps, wall_t + eps, post_h + 2 * eps]);
    if (!center)
      translate([-eps, post_w, -eps]) cube([wall_t + eps, post_w + eps, post_h + 2 * eps]);
    for (x = center ? [(w - post_w) / 2, (w + post_w) / 2] : [post_w / 2]) {
      // 上下のM4穴を一つの貫通穴にし、印刷途中に穴を塞ぐ天井を作らない。
      translate([x, post_w / 2, -eps]) cylinder(d = bolt_d, h = post_h + 2 * eps, $fn = arc_fn);
      vertical_nut_cut(x, true, corner = !center);
      vertical_nut_cut(x, false, corner = !center);
    }
    for (x = center ? [post_w / 2, w - post_w / 2] : [1.5 * post_w]) front_nut_cut(x);
    if (!center) {
      // 上辺を水平に保ったまま正面穴を直交する腕へ移す。
      mirror([1, -1, 0]) front_nut_cut(1.5 * post_w);
    }
  }
}

// 外側面をベッドに置く。X=壁長、Y=組立時の高さ、Z=壁厚。
module wall() {
  difference() {
    translate([wall_gap, 0, 0]) cube([wall_length - 2 * wall_gap, post_h, wall_t]);
    for (x = [post_w / 2, wall_length - post_w / 2])
      translate([x, side_bolt_z, 0]) countersunk_hole(wall_t, up = false);
  }
}

// 外周の露出面側だけR3。中央の接合断面は平らに切り分ける。
module plate_blank(t, right = false) {
  assert(t >= edge_r && edge_r > 0);
  intersection() {
    translate([edge_r - (right ? half_w : 0), edge_r, -edge_r]) minkowski() {
      cube([2 * half_w - 2 * edge_r, case_d - 2 * edge_r, t]);
      // 極をZ=±Rに置き、板上面と皿穴の終端を同じ高さにする。
      rotate_extrude($fn = arc_fn)
        polygon([for (a = [-90 : 5 : 90])
          [abs(a) == 90 ? 0 : edge_r * cos(a), edge_r * sin(a)]]);
    }
    cube([half_w, case_d, t]);
  }
}

module plate(bottom = false, right = false) {
  t = bottom ? bottom_t : top_t;
  buttons = right ? buttons_right : buttons_left;
  mounts = right ? pcb_mounts_right : pcb_mounts_left;
  difference() {
    plate_blank(t, right);
    for (x = [post_w / 2, half_w - post_w / 2])
      for (y = [post_w / 2, case_d - post_w / 2])
        translate([x, y, 0]) countersunk_hole(t);
    if (bottom) {
      for (y = pad_y)
        translate([(half_w - pad_w) / 2, y, t - pad_depth])
          cube([pad_w, pad_d, pad_depth + eps]);
    } else {
      for (b = buttons)
        translate([b[0], b[1], -eps]) cylinder(d = b[2], h = t + 2 * eps, $fn = arc_fn);
      for (p = mounts)
        translate([p[0], p[1], 0]) countersunk_hole(t, d = pcb_bolt_d, head = pcb_head_d);
    }
  }
}

module frame() {
  for (back = [false, true])
    translate([0, back ? case_d : 0, 0]) scale([1, back ? -1 : 1, 1]) {
      post();
      translate([2 * half_w, 0, 0]) mirror([1, 0, 0]) post();
      translate([half_w - center_w / 2, 0, 0]) post(center = true);
      for (right = [false, true])
        translate([right ? 2 * half_w - post_w : post_w, 0, 0]) scale([right ? -1 : 1, 1, 1])
          multmatrix([[1, 0, 0, 0], [0, 0, 1, 0], [0, 1, 0, 0], [0, 0, 0, 1]]) wall();
    }
  for (right = [false, true])
    translate([right ? 2 * half_w : 0, post_w, 0]) scale([right ? -1 : 1, 1, 1])
      multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1]]) wall();
}

module assembly() {
  color("silver") translate([0, 0, bottom_t]) frame();
  for (right = [false, true]) {
    color("dimgray") translate([right ? 2 * half_w : 0, 0, bottom_t])
      scale([right ? -1 : 1, 1, -1]) plate(bottom = true);
    color(right ? "steelblue" : "teal") translate([right ? half_w : 0, 0, bottom_t + post_h])
      plate(right = right);
  }
}

assert(half_w == 200 && case_d == 200, "ボタン/パッド座標は200mm天板用です");
assert(pad_depth < bottom_t && 2 * bridge_step < nut_roof);
assert(inner_chamfer * sqrt(2) > nut_flat, "ナット入口全体を45度の平面に収めてください");
if (part == "assembly") assembly();
else if (part == "frame") frame();
else if (part == "top_left") plate();
else if (part == "top_right") plate(right = true);
else if (part == "bottom") plate(bottom = true);
else if (part == "corner_post") post();
else if (part == "corner_post_right") translate([2 * post_w, 0, 0]) mirror([1, 0, 0]) post();
else if (part == "center_post") post(center = true);
else if (part == "corner_nut_plug") nut_plug(corner = true);
else if (part == "center_nut_plug") nut_plug();
else if (part == "wall") wall();
else if (part == "button_layout") {
  echo(buttons_left = buttons_left, buttons_right = buttons_right);
  echo(pcb_mounts_left = pcb_mounts_left);
  echo(pcb_mounts_right = pcb_mounts_right);
  projection() for (right = [false, true]) translate([right ? half_w : 0, 0, 0]) plate(right = right);
}
else assert(false, str("Unknown part: ", part));
