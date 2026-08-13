use <bolts.scad>
use <steel_rack.scad>

// スライドレール外側とL字アングルを接合するL字ブラケット。
// 設計の経緯と確定値は ledger/designs/steel-rack-500x400.md が正本。
//
// 座標系 (部品自身の datum):
//   X = 0 がこの部品側のL字アングル外側面。部品はアングル板厚の内側から始まる
//   Y = 0 がスライドレール外側面。+Y がラック外側
//   Z = 0 が部品底面 (レール下端と一致)
// front は screw_x = [34, 98]、rear は [76.5, 172.5] を自分の datum から渡す。
// M6 が高さ 22.5±12 の対称配置のため部品は Z 反転対称になり、
// 左右のレールにも上下反転するだけで同じ2部品を使い回せる。

bracket_height = 45;
flange_t = 10;
inner_r = 4;
m6_z = [ 10.5, 34.5 ];
m6_pass_flat = 6; // ボルト通し六角の二面幅 (手前5mm)
m6_nut_flat = 10; // ナット窪み六角の二面幅 (奥5mm、M6ナット実測)
m6_stage_depth = 5;
screw_z = 22.5;
screw_flat = 3; // 木ネジ用六角の二面幅 (外径3.9mmの77%)
screw_hex_depth = 14; // フランジ10mm + ガード内4mm (先端側に肉を3mm残す)
guard_d = 14;    // ネジ先端を包む半円柱
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

// 六角プリズム: 軸Y・断面の頂点が上下 (point-up)
module
hex_y_point_up(flat_d, l)
{
    rotate([ 90, 0, 0 ]) rotate([ 0, 0, 90 ]) hex_hole(flat_d = flat_d, h = l);
}

module
slide_rail_outer_bracket(screw_x, name = "bracket")
{
    // flat-up配置ではY方向の穴半径は対角/2 (= 二面幅/(2*cos30))。
    // 8mm余白の契約はこの実半径に対して守る
    m6_nut_diag = m6_nut_flat / cos(30);
    // 短辺のY寸法: 長辺厚 + 内側R + 余白 + M6六角(対角) + 余白
    m6_y = flange_t + inner_r + edge_margin + m6_nut_diag / 2;
    short_len = m6_y + m6_nut_diag / 2 + edge_margin;
    // 長辺のX終端: 最奥の木ネジ穴の縁 (二面幅3の半分) + 余白
    arm_end = max(screw_x) + screw_flat / 2 + edge_margin;

    echo(str("CONTRACT ", name, ": height = ", bracket_height));
    echo(str("CONTRACT ", name, ": flange_t = ", flange_t));
    echo(str("CONTRACT ", name, ": inner_r = ", inner_r));
    echo(str("CONTRACT ", name, ": m6_z = ", m6_z));
    echo(str("CONTRACT ", name, ": m6_pass_flat = ", m6_pass_flat));
    echo(str("CONTRACT ", name, ": m6_nut_flat = ", m6_nut_flat));
    echo(str("CONTRACT ", name, ": screw_z = ", screw_z));
    echo(str("CONTRACT ", name, ": screw_flat = ", screw_flat));
    echo(str("CONTRACT ", name, ": guard_d = ", guard_d));
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

    // 余白の契約 (自由な辺のみ。高さ45とM6のZはuser固定値なので対象外)
    assert(m6_y - m6_nut_diag / 2 - (flange_t + inner_r) >= edge_margin,
           "M6 hole too close to the inner corner");
    assert(short_len - (m6_y + m6_nut_diag / 2) >= edge_margin,
           "M6 hole too close to the short-flange edge");
    assert(arm_end - (max(screw_x) + screw_flat / 2) >= edge_margin,
           "screw hole too close to the arm end");
    assert(min(screw_x) - screw_flat / 2 >= angle_t + flange_t,
           "screw hole overlaps the short flange");

    difference()
    {
        union()
        {
            // 短辺: アングル内側に当たる縦板 (M6で締結)
            translate([ angle_t, 0, 0 ])
                cube([ flange_t, short_len, bracket_height ]);

            // 長辺: レール外側面に当たる横板 (木ネジで締結)
            translate([ angle_t, 0, 0 ])
                cube([ arm_end - angle_t, flange_t, bracket_height ]);

            // 内側コーナーのR4フィレット (応力集中の回避)
            translate([
                angle_t + flange_t + inner_r,
                flange_t + inner_r,
                bracket_height / 2
            ]) rotate([ 0, 0, 180 ]) fillet_profile(inner_r, bracket_height);

            // 木ネジ先端を包む半円柱ガード (軸Z・全高)
            for (x = screw_x) {
                translate([ x, flange_t, 0 ])
                    linear_extrude(height = bracket_height) intersection()
                {
                    circle(d = guard_d, $fn = 64);
                    translate([ -guard_d / 2, 0 ])
                        square([ guard_d, guard_d / 2 ]);
                }
            }
        }

        // M6の2段六角穴 (軸X・flat-up): 手前5mmが通し、奥5mmがナット窪み
        for (z = m6_z) {
            translate([ angle_t + m6_stage_depth / 2 - 0.05, m6_y, z ])
                hex_x_flat_up(m6_pass_flat, m6_stage_depth + 0.1);
            translate(
                [ angle_t + flange_t - m6_stage_depth / 2 + 0.05, m6_y, z ])
                hex_x_flat_up(m6_nut_flat, m6_stage_depth + 0.1);
        }

        // 木ネジの六角穴 (軸Y・point-up): レール側からガード内4mmまで
        for (x = screw_x) {
            translate([ x, screw_hex_depth / 2 - 0.05, screw_z ])
                hex_y_point_up(screw_flat, screw_hex_depth + 0.1);
        }
    }
}
