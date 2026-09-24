use <corner_acrylic_support.scad>

// 最上部用。アクリル座面を柱の最上端と揃え、使用時は印刷姿勢から反転。
// 隣り合う7×30長穴の間の金属をM6で挟む。各面2本、直交する両面で計4本。
post_end_to_slot = 8.5; // 長穴上端→柱上端の実測概算。現物に合わせて調整。
slot_length = 30;
slot_gap = 20; // 上の長穴の下端→次の長穴の上端。依頼者の実測値。
m6_diameter = 6; // 長穴端に接する実軸径。樹脂の通し穴AF6.4とは区別する。

// 最初の長穴の下端へ35.5、次の長穴の上端へ61.5。中心間26、全高72.2。
// 上下の移動を長穴の縁で止める。旧Z15.2の穴は残さない。
upper_m6_z = post_end_to_slot + slot_length - m6_diameter / 2;
lower_m6_z = post_end_to_slot + slot_length + slot_gap + m6_diameter / 2;
assert(post_end_to_slot >= 0 && slot_length >= m6_diameter && slot_gap >= 0);
corner_acrylic_support(m6_levels = [upper_m6_z, lower_m6_z]);
