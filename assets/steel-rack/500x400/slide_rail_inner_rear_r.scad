use <../../../modules/slide_rail_inner_block.scad>

// スライドレール内側のケース支持部品 (奥用・ラック手前から見て右)。
// slide_rail_inner_rear_l.scad の mirror([1,0,0]) (X鏡像) そのもの。
// 対称型 (slide_rail_inner_support.scad) は柱がブロック中心にあり鏡像不変
// なので左右で共用できるが、奥用は柱の偏心が X 対称性を破るため、
// L/R が真の鏡像対になり2設計に分かれる。
//
// datum と向きの規約は鏡像前 (rear_l) と同じ: X=0 は奥ペアの中点、
// 部品ローカル +X = ラック手前方向。鏡像後の実位置では柱は -X 側に寄る。

// 偏心は rear_l と同じ値 (導出: ケース端39 + 逃げ2 + 柱の半分5 - 奥ペア中点32)
standoff_offset = 14;

mirror([ 1, 0, 0 ]) slide_rail_inner_block(standoff_offset = standoff_offset,
                                           name = "inner_rear_r");

// module は鏡像前の値を echo するため、鏡像後の実位置を自分で宣言する
echo(str("CONTRACT inner_rear_r: standoff_offset_mirrored = ",
         -standoff_offset));
