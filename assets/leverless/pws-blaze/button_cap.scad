// φ24.4穴用の目隠し。本体＋樹脂ナットを表示姿勢のまま印刷する。
// Z=0はベッド/使用時の表面。板はZ=1.2から+Z、ナットは板の裏側。
// Based on the OSB Plug by TheTrain.
// Copyright © 2025 TheTrain: https://x.com/thetrain24
// Licensed under CC BY 4.0: https://creativecommons.org/licenses/by/4.0/
// Source: https://github.com/OpenStickCommunity/Hardware/tree/main/3D%20Prints/OSB%20Plug
// Changes from the original design: φ26薄型フランジ、底/谷壁3mmの中空本体、
// 専用φ20ねじへ変更。6つの指掛かりを外径26・高さ8へ寸法変更して再現。
part = "print"; // [print, body, nut]
thread_clearance = 0.25; // 雄ねじだけに設ける半径方向の隙間。実プリントで調整。

flange_d = 26;
flange_h = 1.2;
flange_chamfer = 0.8;
pilot_d = 24;
pilot_h = 2.8;
thread_d = 20; // 雌ねじの最大径。M20規格ではない専用ねじ。
thread_h = 8;
thread_pitch = 2.4;
thread_depth = 0.8;
thread_crest = 0.4;
nut_h = 8;
shell = 3;
lead = 0.8;
$fn = 96;

assert(thread_clearance > 0 && thread_clearance < thread_depth / 2,
       "thread_clearance must leave a usable thread flank");
assert(part == "print" || part == "body" || part == "nut", "unknown part");

// 軸断面で山頂幅0.4・両斜面45度の台形を、XYの極座標へ写す。
function thread_radius(angle) =
    let (dz = abs((angle + 180) % 360 - 180) * thread_pitch / 360)
        thread_d / 2 - thread_depth +
        max(0, thread_depth - max(0, dz - thread_crest / 2));

module thread_form(h, clearance = 0) {
  // linear_extrudeのtwistは左手則。負角で1条の右ねじになる。
  linear_extrude(height = h, twist = -360 * h / thread_pitch,
                 slices = ceil(h / thread_pitch * 48), convexity = 10)
    polygon([for (i = [0:$fn - 1])
      let (a = i * 360 / $fn, r = thread_radius(a) - clearance)
        [r * cos(a), r * sin(a)]]);
}

module cap_body() {
  difference() {
    union() {
      rotate_extrude()
        polygon([[0, 0], [flange_d / 2 - flange_chamfer, 0],
                 [flange_d / 2, flange_chamfer], [flange_d / 2, flange_h],
                 [pilot_d / 2, flange_h], [pilot_d / 2, flange_h + pilot_h],
                 [0, flange_h + pilot_h]]);
      translate([0, 0, flange_h + pilot_h]) intersection() {
        thread_form(thread_h, thread_clearance);
        // 先端を細め、ナットを斜めに噛ませにくくする。
        r = thread_d / 2 - thread_clearance;
        // 山と円錐の分割線をずらし、交差点に退化した三角形を残さない。
        rotate([0, 0, 1]) rotate_extrude()
          polygon([[0, 0], [r + 0.02, 0], [r + 0.02, thread_h - lead - 0.02],
                   [r - lead, thread_h], [0, thread_h]]);
      }
    }
    // ねじ谷から3mmを残す。先端へ開放し、空洞を閉じる天井は作らない。
    translate([0, 0, shell])
      cylinder(r = thread_d / 2 - thread_depth - thread_clearance - shell,
               h = flange_h + pilot_h + thread_h - shell + 0.1);
  }
}

module cap_nut() {
  difference() {
    rotate_extrude()
      polygon([[0, 0], [flange_d / 2, 0], [flange_d / 2, nut_h - 0.4],
               [flange_d / 2 - 0.4, nut_h], [0, nut_h]]);
    // 端面を抜く0.1mmにも同じ位相を与える。
    translate([0, 0, -0.1]) rotate([0, 0, -360 * 0.1 / thread_pitch])
      thread_form(nut_h + 0.2);
    for (z = [0, nut_h]) translate([0, 0, z])
      rotate([z == 0 ? 0 : 180, 0, 1])
        cylinder(r1 = thread_d / 2, r2 = thread_d / 2 - lead, h = lead);
    // OSB式の6つの指掛かり。板側4mmの連続リングを下にして印刷する。
    for (a = [30:60:330]) rotate([0, 0, a])
      translate([0, -2.4, nut_h - 4])
        cube([flange_d / 2 + 1, 4.8, 4.1]);
  }
}

if (part == "body") cap_body();
else if (part == "nut") cap_nut();
else {
  cap_body();
  translate([30, 0, 0]) cap_nut();
}
