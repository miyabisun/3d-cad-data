use <corner_acrylic_support.scad>

// 最上部用。アクリル座面を柱の最上端と揃え、使用時は印刷姿勢から反転。
// 両面の同じ7×30長穴にM6を上下2本ずつ（計4本）。単位mm。
post_end_to_slot = 8.5; // 長穴上端→柱上端の実測概算。現物に合わせて調整。
slot_length = 30;
m6_diameter = 6; // 長穴端に接する実軸径。樹脂の通し穴AF6.4とは区別する。

// 座面に近い穴は底板10＋ナット窪み半幅5.2＝15.2。
// 追加穴は長穴下端へ寄せて35.5、中心間20.3、全高46.2。
lower_m6_z = post_end_to_slot + slot_length - m6_diameter / 2;
assert(post_end_to_slot >= 0 && post_end_to_slot + m6_diameter / 2 <= 15.2);
corner_acrylic_support(extra_m6_z = lower_m6_z);
