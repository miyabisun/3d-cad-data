use <../../../modules/slide_rail_outer_bracket.scad>

// M4小トラスネジ継手の嵌合試験片 (実部品の長辺断面と同じ構成)。
// 通し: 二面幅4.4の六角を全厚10mmに貫通 (flat-up・上辺ブリッジ)。
// ナット窪み: L字内側面にあたる面から深さ2.8mm・二面幅7.4の六角。
// 確認点: M4トラスネジがスルッと通るか、M4ナットが窪みに収まって
// 回り止めが効くか、深さ2.8mmでの飛び出し具合。

width = 24;
// ナット窪み (縦7.4) の上下に2mm以上の肉を残す高さ。8mmだと肉0.3mmで
// 挿入時に割れ、嵌合試験としてクリアランスと切り分けられない
height = 12;
thickness = 10;
pass_flat = 4.4; // M4呼び4.0 + 0.4
nut_flat = 7.4;  // ナット実測6.8 + 実効0.6
nut_depth = 2.8;

assert((height - nut_flat) / 2 >= 2,
       "nut pocket needs >=2mm walls above/below");

difference()
{
    cube([ width, thickness, height ]);

    // 通し (全厚)
    translate([ width / 2, thickness / 2, height / 2 ])
        hex_y_flat_up(pass_flat, thickness + 0.2);

    // ナット窪み (内側面から2.8mm)
    translate([ width / 2, thickness - nut_depth / 2 + 0.05, height / 2 ])
        hex_y_flat_up(nut_flat, nut_depth + 0.1);
}
