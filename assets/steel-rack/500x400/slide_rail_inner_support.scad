use <../../../modules/slide_rail_inner_block.scad>

// スライドレール内側のケース支持部品 (対称型)。
// datum: X=0 は使う穴ペア (28mm間隔) の中点。Y=0 がレール(内)の接触面。
// 印刷向き: ブロック底面をビルドプレートへ置く (M4軸は水平・六角は flat-up)。
//
// スタンドオフがブロック中心にあり X 鏡像不変のため、この1設計で
// 手前L/R・中央L/R の4個を印刷して使い回せる (ミラー印刷不要)。
// 奥用だけは偏心が対称性を破るため別設計 (slide_rail_inner_rear_{l,r}.scad)。
//
// 手前位置での裏取り: 手前ペア (レール手前端から32/60mm) の中点は46mmで、
// ケース端39mm + 柱の逃げ2mm + 柱の半分5mm = 46mm と一致する。
// つまり偏心0のまま、柱のケース側の面がレール端から41mmに来る

standoff_offset = 0;

slide_rail_inner_block(standoff_offset = standoff_offset,
                       name = "inner_support");
