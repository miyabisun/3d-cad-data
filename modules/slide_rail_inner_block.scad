use <slide_rail_outer_bracket.scad>

// スライドレール内側とオープンフレームケースを繋ぐ支持部品の共通形状。
// 設計の経緯と確定値は ledger/designs/steel-rack-500x400.md が正本。
//
// 座標系 (部品自身の datum):
//   X = レール方向。M4 2穴の中点 (ブロック中心) が 0
//   Y = 0 がスライドレール(内)の接触面。+Y がラック中央 (ケース) 向き
//   Z = 0 がブロック底面
// レール(内)は高さ24.4mmで、そのド真ん中 (12.2mm) に横穴が28mm間隔で並ぶ。
// ブロックは穴中心 (部品 z = 7) で取り付くため、下端はレール下端から
// 約5.2mm浮く。ブロックの上に立つ10×10の柱でケースを浮かせて受ける。
//
// 印刷向き: ブロックを底面 (z=0) でビルドプレートへ置く。M4軸は水平になり、
// 六角穴はすべて flat-up (天井が短い水平ブリッジ) で外側ブラケットと揃う。

block_len = 42;    // X: 穴間28 + 14
block_depth = 14;  // Y
block_height = 14; // Z
m4_dx = 14;        // ブロック中心から各M4穴まで (間隔28)
m4_z = 7; // ブロック中心の高さ。レール横穴の12.2mmに合わせて付く
// クリアランス基準は外側ブラケットの実績値をそのまま流用する
// (呼び寸法+0.4 / ナットは実測+実効0.6。2026-08-14のuser指示)
m4_pass_flat = 4.4; // M4小トラスネジ通し六角の二面幅
m4_nut_flat = 7.4; // M4ナット窪み六角の二面幅 (ナット実測6.8 + 実効0.6)
m4_nut_depth = 2.8;   // M4ナット窪みの深さ
standoff = 10;        // 柱の一辺 (10×10)
standoff_height = 34; // 柱の全高 = ブロック14 + 上へ20突出

// standoff_offset: 柱の中心をブロック中心からずらす量 (X)。
// 対称型は 0 で X 鏡像不変になり、奥用はケース端との2mm逃げから +14。
// 導出 (ケース端の datum を持つのは entry 側) は各 entry のコメントを参照
module
slide_rail_inner_block(standoff_offset = 0, name = "inner")
{
    // flat-up配置では水平方向の穴半径は対角/2 (= 二面幅/(2*cos30))
    m4_nut_diag = m4_nut_flat / cos(30);

    echo(str("CONTRACT ",
             name,
             ": block = ",
             [ block_len, block_depth, block_height ]));
    echo(str("CONTRACT ", name, ": m4_x = ", [ -m4_dx, m4_dx ]));
    echo(str("CONTRACT ", name, ": m4_z = ", m4_z));
    echo(str("CONTRACT ", name, ": m4_pass_flat = ", m4_pass_flat));
    echo(str("CONTRACT ", name, ": m4_nut_flat = ", m4_nut_flat));
    echo(str("CONTRACT ", name, ": m4_nut_depth = ", m4_nut_depth));
    echo(str("CONTRACT ", name, ": standoff_offset = ", standoff_offset));
    echo(str("CONTRACT ",
             name,
             ": standoff = ",
             [ standoff, standoff, standoff_height ]));

    // 穴と窪みがブロックに収まる契約 (1e-9 は浮動小数の丸め猶予)
    assert(m4_dx + m4_nut_diag / 2 <= block_len / 2 + 1e-9,
           "M4 nut pocket runs past the block end");
    assert(m4_z - m4_nut_flat / 2 >= -1e-9 &&
               m4_z + m4_nut_flat / 2 <= block_height + 1e-9,
           "M4 nut pocket runs past the block top/bottom");
    assert(m4_nut_depth < block_depth,
           "M4 nut pocket is deeper than the block");
    // 柱がブロックのX範囲に収まる契約 (奥用の偏心で端から出ない)
    assert(abs(standoff_offset) + standoff / 2 <= block_len / 2 + 1e-9,
           "standoff runs past the block end");
    assert(standoff <= block_depth, "standoff is deeper than the block");

    difference()
    {
        union()
        {
            // ネジ穴ブロック: レール(内)の側面へ当てて共締めする本体
            translate([ -block_len / 2, 0, 0 ])
                cube([ block_len, block_depth, block_height ]);

            // スタンドオフ: ケースを浮かせて受ける柱。レール接触面
            // (y=0) とツライチで、ブロックより20mm高い
            translate([ standoff_offset - standoff / 2, 0, 0 ])
                cube([ standoff, standoff, standoff_height ]);
        }

        // M4小トラスネジの穴 (軸Y・flat-up): 外側ブラケットと同じ向きで、
        // 通しはレール側 (y=0) から全厚を貫通し、終わり際 (y=14の面) に
        // 深さ2.8mmのナット窪み。ネジはレール内側から刺さり、ナットが
        // 窪みの底で受けてレール板とブロックを共締めする
        for (x = [ -m4_dx, m4_dx ]) {
            translate([ x, block_depth / 2, m4_z ])
                hex_y_flat_up(m4_pass_flat, block_depth + 0.2);
            translate([ x, block_depth - m4_nut_depth / 2 + 0.05, m4_z ])
                hex_y_flat_up(m4_nut_flat, m4_nut_depth + 0.1);
        }
    }
}
