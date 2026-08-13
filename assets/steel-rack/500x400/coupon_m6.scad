use <../../../modules/slide_rail_outer_bracket.scad>

// M6の2段六角穴の嵌合試験片。
// 過去実績 (M4で二面幅+0.2mm) に合わせ、通し6.2 / ナット窪み10.2で検証する。
// 実部品と同じ hex_x_flat_up を使い、同じ印刷向き (穴軸が水平・上辺ブリッジ)。
// 確認点: M6x12ボルトが通しへ滑って入るか、ナットが窪みへガッチリ収まるか。

width = 20;
height = 20;
thickness = 10;
pass_flat = 6.2; // 二面幅6.0 + 0.2
nut_flat = 10.2; // 二面幅10.0 + 0.2
stage_depth = 5;

difference()
{
    cube([ thickness, width, height ]);

    // 手前5mm: ボルト通し
    translate([ stage_depth / 2 - 0.05, width / 2, height / 2 ])
        hex_x_flat_up(pass_flat, stage_depth + 0.1);

    // 奥5mm: ナット窪み
    translate([ thickness - stage_depth / 2 + 0.05, width / 2, height / 2 ])
        hex_x_flat_up(nut_flat, stage_depth + 0.1);
}
