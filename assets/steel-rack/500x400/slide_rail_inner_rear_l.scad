use <../../../modules/slide_rail_inner_block.scad>

// スライドレール内側のケース支持部品 (奥用・ラック手前から見て左)。
// datum: X=0 は奥ペア (レール奥端から18/46mm) の中点 = 奥端から32mm。
// 向きの規約: 部品ローカル +X = ラック手前方向 (奥端から遠ざかる向き)。
// Y=0 がレール(内)の接触面。印刷向きは対称型と同じ (ブロック底面を下)。
//
// 奥ペアはレール奥端に寄っているため、柱をブロック中心に置くとケースの
// 外へ出てしまう。柱だけをラック手前側へ寄せてケース下へ入れる:
//   ケース端39 + 逃げ2 + 柱の半分12 = 41+12 = 53mm (奥端基準)
//   偏心 = 53 - 32 = 21mm
// この偏心が X 対称性を破るので、奥用だけ左右が別設計になる
// (右は slide_rail_inner_rear_r.scad = この形状の mirror([1,0,0]))。

rail_end_to_case = 39; // レール端からケース端まで (前後の隙間・一旦39mm)
// ケース端から柱のケース側の面までの逃げ。現物合わせ予定で、
// 組んでみてスカスカ・ガタつくようなら詰める (user)
standoff_inset = 2;
standoff_half = 12; // 24×24 柱の半分
pair_center = 32;   // 奥ペア (奥端から18/46mm) の中点

standoff_offset =
    rail_end_to_case + standoff_inset + standoff_half - pair_center;

slide_rail_inner_block(standoff_offset = standoff_offset,
                       name = "inner_rear_l");
