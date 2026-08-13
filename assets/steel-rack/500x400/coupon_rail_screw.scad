use <../../../modules/slide_rail_outer_bracket.scad>

// 木ネジ受け部 (四角柱 + φ14半円柱ガード) の嵌合試験片。
// 実部品の長辺断面と同じ構成: 板厚10mm + ガード内4mm = 深さ14mmの
// 二面幅3mm六角穴 (point-up)、ガード先端側に3mmの肉を残す。
// 確認点: レール付属木ネジ (外径3.9・全長15.4・皿) がセルフタップで
// 効くか、先端がガードを突き破らないか。

width = 22;
height = 8;
thickness = 10;
screw_flat = 3;
screw_hex_depth = 14;
guard_d = 14;

difference()
{
    union()
    {
        cube([ width, thickness, height ]);

        // φ14半円柱ガード (軸Z)
        translate([ width / 2, thickness, 0 ]) linear_extrude(height = height)
            intersection()
        {
            circle(d = guard_d, $fn = 64);
            translate([ -guard_d / 2, 0 ]) square([ guard_d, guard_d / 2 ]);
        }
    }

    // 木ネジの六角穴: レール側からガード内4mmまで
    translate([ width / 2, screw_hex_depth / 2 - 0.05, height / 2 ])
        hex_y_point_up(screw_flat, screw_hex_depth + 0.1);
}
