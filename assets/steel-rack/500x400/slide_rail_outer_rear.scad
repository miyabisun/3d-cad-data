use <../../../modules/slide_rail_outer_bracket.scad>

// スライドレール外側ブラケット (奥)。
// datum: X=0 は奥側L字アングルの外側面 (自分側の基準)。
// ラック手前基準の世界座標では 400 - x で正規化される。
// 印刷向き: L断面をビルドプレートへ寝かせる (層と平行に荷重を受ける)。
// 左右のレールには上下反転で同じ部品を使う (Z対称)。

screw_x = [ 76.5, 172.5 ];
rack_depth = 400;

echo(str("CONTRACT rear: screw_x_front_datum = ",
         [ rack_depth - screw_x[1], rack_depth - screw_x[0] ]));

slide_rail_outer_bracket(screw_x = screw_x, name = "rear");
