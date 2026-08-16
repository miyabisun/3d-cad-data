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
// 約5.2mm浮く。ブロックの脇に立つ24×24の柱でケースを浮かせて受ける。
//
// M4継手は「レール + 土台の挟み込み」: ボルトはレールの向こう側から
// レール壁と土台を貫通し、土台のケース側の面 (y=10) のナット窪みでナットが
// 受けて「頭｜レール壁｜土台｜ナット」を締め上げる。柱はこの窪みの正面に
// 立つので、窪みの六角をそのまま外へ24mm押し出して柱を貫通させ、六角
// トンネルにする (柱の側面には「＜」形の切り欠きとして現れる)。
//
// 印刷向き: ブロックを底面 (z=0) でビルドプレートへ置く。M4軸は水平になり、
// 六角穴はすべて flat-up (天井が短い水平ブリッジ) で外側ブラケットと揃う。
// 柱は地面から m4_z までを削り落とし、z=7 から立ち上がる (足痩せの切り欠き
// 方式は柱がプリントできず廃止。2026-08-16の実物フィードバック)。

block_len = 42; // X: 穴間28 + 14
// Y: M4×10 がケース側から通し7.2 + 窪み2.8 でナットへ全掛かりする厚さ。
// 旧14mmは対応する長さのM4ネジが無くナットに届かなかった (実物確認)
block_depth = 10;
block_height = 14; // Z
m4_dx = 14;        // ブロック中心から各M4穴まで (間隔28)
m4_z = 7; // ブロック中心の高さ。レール横穴の12.2mmに合わせて付く
// クリアランス基準は外側ブラケットの実績値をそのまま流用する
// (呼び寸法+0.4 / ナットは実測+実効0.6。2026-08-14のuser指示)
m4_pass_flat = 4.4; // M4小トラスネジ通し六角の二面幅
m4_nut_flat = 7.4; // M4ナット窪み六角の二面幅 (ナット実測6.8 + 実効0.6)
m4_nut_depth = 2.8; // M4ナット窪みの深さ
// flat-up配置では水平方向の穴半径は対角/2 (= 二面幅/(2*cos30))
m4_nut_diag = m4_nut_flat / cos(30);
// 柱の一辺 (24×24)。旧10×10ではケース四隅のネジ穴に落ち込んで支持に
// ならなかったため、穴を跨げる24へ広げた (2026-08-16の実物フィードバック)
standoff = 24;
standoff_height = 34; // 柱の全高 = ブロック14 + 上へ20突出
// 柱をレール接触面 (y=0) から離す量。実物合わせで「スライドレールから
// 突起を多少離す必要がある」と判明したため導入した暫定値で、現物合わせ
// 予定 (2026-08-15のuserフィードバック)
standoff_setback = 2;
// 垂直エッジのフィレット半径。角柱の角が刺さって痛いため落とす (user指示)。
// 上下の水平エッジはプリント難度が飛躍的に上がるため未加工 = 3D の
// minkowski ではなく 2D 輪郭を linear_extrude して垂直エッジだけ丸める
corner_r = 2;
arc_fn = 64; // 円弧の分割数 (このリポジトリの既存慣行)
// 柱の下端。地面から M4軸の高さまでは柱としてプリントできないため削り落とす
// (「地面から7mmまでの部分を柱から削り落とす」2026-08-16のuser指示)。
// 柱は土台 (z 0..14) と z 7..14 で重なって接合する
column_z0 = m4_z;
// ナット窪みの切削長: 土台の窪み2.8 + 柱の一辺24。窪みの六角をそのまま
// 外へ押し出して柱を貫通させ、ナットの逃げになる六角トンネルにする
m4_nut_cut = m4_nut_depth + standoff;

// 四隅を r で丸めた矩形の2D輪郭 (原点が左下・X方向 w・Y方向 d)
module
rounded_rect_2d(w, d, r)
{
    translate([ r, r ]) offset(r = r, $fn = arc_fn)
        square([ w - 2 * r, d - 2 * r ]);
}

// 土台の2D輪郭: ナット側 (y=0) の2隅だけ r で落とし、ケース側 (y=d) は
// 直角のまま残す (落とすのはナット側だけ、というuser指示)
module
block_profile_2d(w, d, r)
{
    union()
    {
        rounded_rect_2d(w, d, r);
        translate([ 0, r ]) square([ w, d - r ]);
    }
}

// standoff_offset: 柱の中心をブロック中心からずらす量 (X)。
// 対称型は 0 で X 鏡像不変になり、奥用はケース端との2mm逃げから +21。
// 導出 (ケース端の datum を持つのは entry 側) は各 entry のコメントを参照
module
slide_rail_inner_block(standoff_offset = 0, name = "inner")
{
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
    echo(str("CONTRACT ", name, ": standoff_setback = ", standoff_setback));
    echo(str("CONTRACT ", name, ": corner_r = ", corner_r));
    echo(str("CONTRACT ", name, ": column_z0 = ", column_z0));

    // 柱は土台より大きく、X も Y もはみ出す。接合が成立するのは
    // 重なり幅で、フィレットで削れる分 (両端 corner_r) を超えて正であること
    x_overlap = min(block_len / 2, standoff_offset + standoff / 2) -
                max(-block_len / 2, standoff_offset - standoff / 2);
    y_overlap = min(block_depth, standoff_setback + standoff) -
                max(0, standoff_setback);

    // 穴と窪みがブロックに収まる契約 (1e-9 は浮動小数の丸め猶予)
    assert(m4_dx + m4_nut_diag / 2 <= block_len / 2 + 1e-9,
           "M4 nut pocket runs past the block end");
    assert(m4_z - m4_nut_flat / 2 >= -1e-9 &&
               m4_z + m4_nut_flat / 2 <= block_height + 1e-9,
           "M4 nut pocket runs past the block top/bottom");
    assert(m4_nut_depth < block_depth,
           "M4 nut pocket is deeper than the block");
    // 柱と土台の接合契約: 重なりがフィレット2つ分より広く残ること
    assert(x_overlap >= 2 * corner_r, "standoff and block barely overlap in X");
    assert(y_overlap >= 2 * corner_r, "standoff and block barely overlap in Y");
    // 柱がレール接触面 (y=0) より手前へ出ない契約
    assert(standoff_setback >= 0, "standoff crosses the rail face");
    // フィレットが各接触寸法を食い尽くさない契約
    assert(2 * corner_r <= min(standoff, block_depth, block_len),
           "corner_r is too large for the block/standoff profiles");
    // 柱と土台の Z 方向の接合契約: 削り落とした柱の下端が土台の上端より
    // 十分下にあり、重なりがフィレット2つ分より広く残ること
    assert(block_height - column_z0 >= 2 * corner_r,
           "standoff and block barely overlap in Z");
    // ナット窪みの押し出しが柱を貫通する契約 (途中で止まるとナットの
    // 逃げが塞がれる)
    assert(block_depth - m4_nut_depth + m4_nut_cut >=
               standoff_setback + standoff,
           "nut cut does not tunnel through the standoff");

    difference()
    {
        union()
        {
            // ネジ穴ブロック: レール(内)の側面へ当てて共締めする本体。
            // 垂直エッジのうちナット側の2本だけ R (2D輪郭を押し出す)
            translate([ -block_len / 2, 0, 0 ])
                linear_extrude(height = block_height)
                    block_profile_2d(block_len, block_depth, corner_r);

            // スタンドオフ: ケースを浮かせて受ける柱。レール接触面から
            // standoff_setback だけ離して立て、ブロックより20mm高く、
            // ブロックの背面より16mmケース側へ張り出す。下端は column_z0
            // (地面から7mmを削り落とす)。垂直エッジは四隅とも R
            translate(
                [ standoff_offset - standoff / 2, standoff_setback, column_z0 ])
                linear_extrude(height = standoff_height - column_z0)
                    rounded_rect_2d(standoff, standoff, corner_r);
        }

        // M4小トラスネジの穴 (軸Y・flat-up): 通し二面幅4.4が全厚を貫通し、
        // ケース側の面 (y=10) に深さ2.8mmのナット窪みが開く。ボルトは
        // レールの向こう側から刺さってレール壁と土台を貫通し、窪みの
        // ナットとで「頭｜レール壁｜土台｜ナット」を挟んで締め上げる。
        // 窪みをレール接触面 (y=0) 側に開けると土台の肉だけを締める
        // 自己締結になりレールを挟めない (2026-08-16の実物指摘で superseded)。
        // 窪みの六角は y=7.2 から m4_nut_cut だけ外へ押し出して柱を貫通し、
        // 柱の側面に「＜」形の切り欠きを開ける六角トンネルになる
        for (x = [ -m4_dx, m4_dx ]) {
            translate([ x, block_depth / 2, m4_z ])
                hex_y_flat_up(m4_pass_flat, block_depth + 0.2);
            translate([ x, block_depth - m4_nut_depth + m4_nut_cut / 2, m4_z ])
                hex_y_flat_up(m4_nut_flat, m4_nut_cut);
        }
    }
}
