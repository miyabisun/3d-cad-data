use <bolts.scad>
use <steel_rack.scad>

// スライドレール外側とL字アングルを接合するL字ブラケット。
// 設計の経緯と確定値は ledger/designs/steel-rack-500x400.md が正本。
//
// 座標系 (部品自身の datum):
//   X = 0 がこの部品側のL字アングル外側面。部品はアングル板厚の内側から始まる
//   Y = 0 がスライドレール外側面。+Y がラック外側
//   Z = 0 が部品底面 (レール下端と一致)
// front は screw_x = [37, 101.5]、rear は [79.5, 176] を自分の datum
// から渡す。 M6 が高さ 22.5±12 の対称配置のため部品は Z 反転対称になり、
// 左右のレールにも上下反転するだけで同じ2部品を使い回せる。

bracket_height = 45;
flange_t = 10; // 短辺 (X方向厚) の厚さ
// 長辺 (Y方向厚) の厚さ。旧断面は flange_t=10 を共用していたが、レール面を
// rail_offset 分外へ出すと M6 ナット挿入口が長辺と重なるため 2mm 削った
// (10→8、user決定)。ナット六角の内縁 (y=8.000) と長辺外面がツライチになる
arm_t = 8;
// レール接触面のラック外側オフセット。組付け実測でレール間隔が 385mm しか
// なくケース 412mm が入らないため、(412 - 385) / 2 + 0.5 = 14mm ずつ
// 各レールを外側へ移す (user指示)。M6 実穴は既に開いており位置を変えられない
rail_offset = 14;
inner_r = 4;
m6_z = [ 10.5, 34.5 ];
// クリアランス基準: 呼び寸法 + 0.4mm (実プリントの嵌合結果から拡大)
m6_pass_flat = 6.4; // M6ボルト通し六角の二面幅 (手前5mm)
m6_nut_flat = 10.4; // M6ナット窪み六角の二面幅 (奥5mm、ナット実測9.8 + 実効0.6)
m6_stage_depth = 5;
screw_z = 22.5;
m4_pass_flat = 4.4; // M4小トラスネジ通し六角の二面幅
m4_nut_flat = 7.4; // M4ナット窪み六角の二面幅 (ナット実測6.8 + 実効0.6)
m4_nut_depth = 2.8; // M4ナット窪みの深さ (user指定)
edge_margin = 8; // 穴の外縁から部品端までの余白 (自由な辺のみ)
angle_t = 2.2; // L字アングルの板厚

// 六角プリズム: 軸X・上下の辺が水平 (flat-up)。
// 天井を短い水平ブリッジにして垂れの改善を狙う
// (point-up だと天井面が水平から30°になり垂れた — 嵌合試験で確認済み)
module
hex_x_flat_up(flat_d, l)
{
    rotate([ 0, 90, 0 ]) rotate([ 0, 0, 90 ]) hex_hole(flat_d = flat_d, h = l);
}

// 六角プリズム: 軸Y・上下の辺が水平 (flat-up)。M6と同じくブリッジ天井
module
hex_y_flat_up(flat_d, l)
{
    rotate([ 90, 0, 0 ]) hex_hole(flat_d = flat_d, h = l);
}

module
slide_rail_outer_bracket(screw_x, name = "bracket")
{
    // flat-up配置では水平方向の穴半径は対角/2 (= 二面幅/(2*cos30))。
    // 8mm余白の契約はこの実半径に対して守る
    m6_nut_diag = m6_nut_flat / cos(30);
    m4_nut_diag = m4_nut_flat / cos(30);
    // M6中心: 実物のアングルには旧断面 (長辺厚10) の導出値
    // (厚10 + 内側R + 余白 + M6六角対角/2 = 28.0044) で既に穴が開いている。
    // 旧導出式から rail_offset を引くことで M6 実穴と部品外端の絶対位置を
    // 保ったまま、レール接触面 (y=0) だけをラック外側へ 14mm 出す
    m6_y = flange_t + inner_r + edge_margin + m6_nut_diag / 2 - rail_offset;
    short_len = m6_y + m6_nut_diag / 2 + edge_margin;
    // 長辺のX終端: 最奥のM4穴の最大断面 (ナット窪みの対角の半分) + 余白
    arm_end = max(screw_x) + m4_nut_diag / 2 + edge_margin;

    echo(str("CONTRACT ", name, ": height = ", bracket_height));
    echo(str("CONTRACT ", name, ": flange_t = ", flange_t));
    echo(str("CONTRACT ", name, ": arm_t = ", arm_t));
    echo(str("CONTRACT ", name, ": rail_offset = ", rail_offset));
    echo(str("CONTRACT ", name, ": inner_r = ", inner_r));
    echo(str("CONTRACT ", name, ": m6_z = ", m6_z));
    echo(str("CONTRACT ", name, ": m6_pass_flat = ", m6_pass_flat));
    echo(str("CONTRACT ", name, ": m6_nut_flat = ", m6_nut_flat));
    echo(str("CONTRACT ", name, ": screw_z = ", screw_z));
    echo(str("CONTRACT ", name, ": m4_pass_flat = ", m4_pass_flat));
    echo(str("CONTRACT ", name, ": m4_nut_flat = ", m4_nut_flat));
    echo(str("CONTRACT ", name, ": m4_nut_depth = ", m4_nut_depth));
    echo(str("CONTRACT ", name, ": edge_margin = ", edge_margin));
    echo(str("CONTRACT ", name, ": angle_t = ", angle_t));
    echo(str("CONTRACT ", name, ": screw_x = ", screw_x));
    echo(str("CONTRACT ",
             name,
             ": m6_y = ",
             m6_y,
             ", short_len = ",
             short_len,
             ", arm_end = ",
             arm_end));

    // 余白の契約 (自由な辺のみ。高さ45とM6のZはuser固定値なので対象外)。
    // M6ナット六角の内縁 (m6_y - 対角/2 = 8.000) は長辺外面 (y = arm_t) と
    // ツライチで、ナット挿入口が長辺に塞がれない (1e-9 は浮動小数の丸め猶予)
    assert(m6_y - m6_nut_diag / 2 >= arm_t - 1e-9,
           "M6 nut slot is blocked by the arm");
    assert(short_len - (m6_y + m6_nut_diag / 2) >= edge_margin,
           "M6 hole too close to the short-flange edge");
    assert(arm_end - (max(screw_x) + m4_nut_diag / 2) >= edge_margin,
           "M4 hole too close to the arm end");
    assert(min(screw_x) - m4_nut_diag / 2 >= angle_t + flange_t,
           "M4 hole overlaps the short flange");

    difference()
    {
        union()
        {
            // 短辺: アングル内側に当たる縦板 (M6で締結)
            translate([ angle_t, 0, 0 ])
                cube([ flange_t, short_len, bracket_height ]);

            // 長辺: レール外側面に当たる横板 (M4小トラスネジ+ナットで締結)
            translate([ angle_t, 0, 0 ])
                cube([ arm_end - angle_t, arm_t, bracket_height ]);

            // 内側コーナーのR4フィレット (応力集中の回避)
            translate([
                angle_t + flange_t + inner_r,
                arm_t + inner_r,
                bracket_height / 2
            ]) rotate([ 0, 0, 180 ]) fillet_profile(inner_r, bracket_height);
        }

        // M6の2段六角穴 (軸X・flat-up): 手前5mmが通し、奥5mmがナット窪み。
        // ナット窪みは +X へ延長した挿入回廊 (x=7.2..17): 短辺の背面から
        // fillet の掛かる区間を局所カットし、fillet 外端 (x=16.2) を 0.8mm
        // 超えて開放することで M6 ナットを +X 側から真っ直ぐ挿入できる
        // (fillet と挿入経路の干渉分を削るのは user 許容)。
        // 六角の下頂点 (y=8.000) は長辺外面とツライチで、正確な接触は
        // 退化した稜 (非多様体STL) を作るため、hull で 0.2mm 下へ掃引して
        // 長辺外面に浅い逃げ溝を彫る (ナットの嵌合には影響しない)
        slot_start = angle_t + flange_t - m6_stage_depth;
        slot_end = angle_t + flange_t + inner_r + 0.8;
        slot_relief = 0.2;
        for (z = m6_z) {
            translate([ angle_t + m6_stage_depth / 2 - 0.05, m6_y, z ])
                hex_x_flat_up(m6_pass_flat, m6_stage_depth + 0.1);
            translate([ (slot_start + slot_end) / 2, m6_y, z ]) hull()
            {
                hex_x_flat_up(m6_nut_flat, slot_end - slot_start);
                translate([ 0, -slot_relief, 0 ])
                    hex_x_flat_up(m6_nut_flat, slot_end - slot_start);
            }
        }

        // M4小トラスネジの穴 (軸Y・flat-up):
        // 通しは全厚を貫通し、L字の内側面 (y=8) から深さ2.8mmのナット窪み。
        // ネジはレール内側から刺さり
        // (トラス頭はスライダーと干渉しない実測済み)、
        // ナットが窪みの底で受けてレール板とブラケットを共締めする
        for (x = screw_x) {
            translate([ x, arm_t / 2, screw_z ])
                hex_y_flat_up(m4_pass_flat, arm_t + 0.2);
            translate([ x, arm_t - m4_nut_depth / 2 + 0.05, screw_z ])
                hex_y_flat_up(m4_nut_flat, m4_nut_depth + 0.1);
        }
    }
}
