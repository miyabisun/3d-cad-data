use <../../modules/bolts.scad>

// 簡易クランプ (コの字のステンレス板・「外六角20mm」) に1本だけ刺さっている
// M8 ボルトを、工具無しの手回し式へ換装するノブ。
// 設計の経緯と確定値は ledger/designs/clamp-hand-knob.md が正本。
//
// クランプは机を挟むコの字で、ボルトの先端には M4 のメスが切ってあり、
// ラッパ状の当て板が M4 ネジ1本で留まっている。当て板を外すとボルトが
// 抜けるので、ボルトのネジ側からこのノブを通し、先端の六角へ噛ませる。
//
// 座標系 (部品自身の datum):
//   X = レバーの長手方向。全長 knob_len (36) の中心が原点
//   Y = レバーの短手方向
//   Z = 0 が部品底面 (プリント面)。穴の軸は Z で、+Z がボルト先端の側
//
// 段構成 (下から):
//   Z 0..pass_h  レバー本体。M8 の軸 (7.8Φ) が通る Φ8.4 の丸穴
//   Z pass_h..   中央ハブだけのボス。ボルト先端の六角を受けるポケット
// 穴が下で細く上で太いので、ボルト先端の六角の肩 (軸から六角へ太る段) が
// この段差へ座り、ノブが六角の上で止まる。
//
// 印刷向き: 底面 (z=0) をビルドプレートへ置く。外周は楕円と円、穴は円と
// 六角で、すべて垂直面 + 水平な上下面しかない。穴は上へ向かって太るだけ
// なので水平ブリッジ (天井) が1枚も無く、サポートも要らない。

// --- クランプ本体の実測値 (user のノギス実測) ---
clamp_plate_t = 3.8;     // コの字ステンレス板の厚さ
clamp_plate_h = 28.4;    // 机を挟んだときのコの字の内高
clamp_plate_w = 24.0;    // 同・横幅
clamp_thread_d = 7.8;    // ボルト穴の実測径 (M8 相当)
tip_hex_measured = 12.8; // ボルト先端の六角 二面幅の実測

// --- ノブの設計値 ---
// 嵌合クリアランス。ボルト先端の六角は「入れやすさ考慮で 13.4」という
// user 指定で、通し穴も同じ 0.6 を足して 8.4 になる (このリポジトリの
// M8 通し穴 8.4 とも一致する)
clearance = 0.6;
knob_len = 36;     // ハンドルの全長 (X)。user 指定
lobe = [ 26, 16 ]; // 楕円ローブ1枚の [長径, 短径]。「2本の瞳みたいな楕円形」
hub_wall = 3;      // 六角ポケットの周りに残す肉厚
pass_h = 5;        // 下段 (M8 通し穴) の高さ。user 指定
hex_h = 5;         // 上段 (六角ポケット) の高さ。user 指定
arc_fn = 64;       // 円弧の分割数 (このリポジトリの既存慣行)
cut_over = 0.5; // 切削の抜き代 (面同士の接触で退化した稜を残さないため)

// --- 派生値 ---
m8_pass_d = clamp_thread_d + clearance;      // 8.4
tip_hex_flat = tip_hex_measured + clearance; // 13.4
// flat 指定の六角は対角 = 二面幅/cos30 (modules/bolts.scad と同じ流儀)
tip_hex_diag = tip_hex_flat / cos(30);
// ハブは六角ポケットを hub_wall で包む円。ここから直に決めるので、
// 六角を太らせれば必要なぶんだけハブも太る
hub_d = tip_hex_diag + 2 * hub_wall;
// ローブ中心の X オフセット。全長を knob_len ちょうどにする位置に置く
lobe_offset = knob_len / 2 - lobe[0] / 2;

// 楕円の2D輪郭 (長径 w・短径 d)
module
ellipse_2d(w, d)
{
    scale([ w / 2, d / 2 ]) circle(r = 1, $fn = arc_fn);
}

// レバーの平面輪郭: 楕円ローブ2枚 ∪ 中央ハブ円。ローブの中心はハブの中に
// あるので、3つの図形は必ず1つに融合する (ボスが浮いた島にならない)
module
knob_footprint_2d()
{
    union()
    {
        for (s = [ -1, 1 ])
            translate([ s * lobe_offset, 0 ]) ellipse_2d(lobe[0], lobe[1]);
        circle(d = hub_d, $fn = arc_fn);
    }
}

module
hand_knob_body()
{
    difference()
    {
        union()
        {
            linear_extrude(height = pass_h) knob_footprint_2d();
            // 上段のボスはハブ円だけを伸ばす。ローブは下段で終わり、
            // 指が掛かるレバーの厚みは pass_h のまま
            linear_extrude(height = pass_h + hex_h)
                circle(d = hub_d, $fn = arc_fn);
        }

        // M8 の軸が下から通る丸穴。上端は六角ポケットへ cut_over だけ
        // 食い込ませる (段の位置は六角ポケットの下端 = pass_h が決める)
        translate([ 0, 0, -cut_over ])
            bolt_hole(d = m8_pass_d, h = pass_h + 2 * cut_over, center = false);

        // ボルト先端の六角を受けるポケット (上開き)。nut_trap は二面幅で
        // 指定する汎用の六角ポケットで、ここに入るのはナットではなく
        // ボルト先端の六角である
        translate([ 0, 0, pass_h ])
            nut_trap(d = tip_hex_flat, h = hex_h + cut_over, center = false);
    }
}

module
hand_knob()
{
    // クランプ本体の実測値 (この部品の前提)
    echo(str("CONTRACT hand_knob: clamp_plate = ",
             [ clamp_plate_t, clamp_plate_h, clamp_plate_w ]));
    echo(str("CONTRACT hand_knob: clamp_thread_d = ", clamp_thread_d));
    echo(str("CONTRACT hand_knob: tip_hex_measured = ", tip_hex_measured));
    echo(str("CONTRACT hand_knob: clearance = ", clearance));
    // ノブの確定寸法
    echo(str("CONTRACT hand_knob: knob_len = ", knob_len));
    echo(str("CONTRACT hand_knob: lobe = ", lobe));
    echo(str("CONTRACT hand_knob: lobe_offset = ", lobe_offset));
    echo(str("CONTRACT hand_knob: m8_pass_d = ", m8_pass_d));
    echo(str("CONTRACT hand_knob: tip_hex_flat = ", tip_hex_flat));
    echo(str("CONTRACT hand_knob: tip_hex_diag = ", tip_hex_diag));
    echo(str("CONTRACT hand_knob: hub_wall = ", hub_wall));
    echo(str("CONTRACT hand_knob: hub_d = ", hub_d));
    echo(str("CONTRACT hand_knob: heights = ", [ pass_h, hex_h ]));

    // 六角ポケットの周りに hub_wall が残ること。hub_d の導出を書き換えても
    // (実測値で上書きしても) 肉厚がここで守られる
    assert(tip_hex_diag + 2 * hub_wall <= hub_d + 1e-9,
           "the hub is too thin around the hex pocket");
    // 段が残ること: 下段の穴が六角より小さくないと、ボルト先端の六角の肩が
    // 座る面が消えてノブが軸を突き抜ける
    assert(m8_pass_d < tip_hex_flat,
           "the pass hole must be smaller than the hex pocket");
    // 全長は user 指定の 36 ちょうど (ローブの位置で合わせる)
    assert(abs(2 * (lobe_offset + lobe[0] / 2) - knob_len) < 1e-9,
           "the lobes do not add up to knob_len");
    // ローブが2枚に分かれて見えること (長径が全長に達すると1枚の塊になる)
    assert(lobe_offset > 0, "the lobes merge into a single blob");
    // 各ローブがハブの中心を覆うこと。覆わないとハブとローブが離れ、
    // 上段のボスが本体から浮いた島になる
    assert(
        lobe_offset < lobe[0] / 2,
        "the lobes do not reach the hub center; the boss would be an island");
    // ハブがローブを飲み込まないこと (飲み込むと指を掛ける腕が消える)
    assert(hub_d < knob_len, "the hub swallows the lobes");

    hand_knob_body();
}

hand_knob();
