use <../../../modules/slide_rail_outer_bracket.scad>

// スライドレール外側ブラケット (手前)。
// datum: X=0 は手前側L字アングルの外側面。レール全長400mmは
// ラック奥行きとぴたり一致するため、木ネジ位置はこの基準の実測値そのまま。
// 印刷向き: L断面をビルドプレートへ寝かせる (層と平行に荷重を受ける)。
// 左右のレールには上下反転で同じ部品を使う (Z対称)。

// 初版 [34, 98] は実プリントで座標ズレが判明し、1個目+3mm・2個目+3.5mm
// 奥へ補正した (経緯は ledger/designs/steel-rack-500x400.md)
screw_x = [ 37, 101.5 ];

slide_rail_outer_bracket(screw_x = screw_x, name = "front");
