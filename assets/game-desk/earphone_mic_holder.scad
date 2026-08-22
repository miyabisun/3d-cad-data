use <../../modules/slide_rail_outer_bracket.scad>

// ゲーム用デスクのイヤホン・マイク置き (クランプ留めの単一プリント部品)。
// 設計の経緯と確定値は ledger/designs/game-desk-earphone-mic-holder.md が正本。
// デスククランプは他にも作る予定があるため、部品名は留め方 (クランプ) では
// なく「何を置くか」を主語にする (user 指示)。
//
// 中央がクランプ取付座、左が Bluetooth イヤホンケースのポケット、右が
// Bluetooth ピンマイクケースのポケット。デスククランプの立ち上がり板
// (40×24×4.2・中央にM8メス) へ、部品の外側から皿ネジ1本で締める。
//
// 座標系 (部品自身の datum):
//   X = 0 がクランプ取付座の左右中心。-X がイヤホン側、+X がピンマイク側
//   Y = 0 がクランプ板への当たり面。+Y が手前 (デスクの外側) 向き
//   Z = 0 が部品底面 (デスク接触面)。+Z が上
// M8 の中心は取付座の中央 = (X, Z) = (0, 20) で、クランプ板 40×24 の
// 中央のメスネジと一致する。
//
// 印刷向き: 底面 (z=0) をビルドプレートへ置き、ポケットの開口を上へ向ける。
// 壁・ポケット・切り欠きはすべて垂直面で、水平な天井を持つのは M8 の
// 六角穴だけ (flat-up = 天井が短い水平ブリッジ) になる。外側の垂直エッジは
// R2 で落とし、デスク接触面 (底面) の水平エッジは未加工のまま残す。

// --- 実測値 (すべて現物合わせ前提の暫定値) ---
clamp_plate_w = 24;  // クランプ立ち上がり板の横幅 (X)
clamp_plate_t = 4.2; // 同・板厚 (Y)。M8メスの掛かり代でもある
clamp_plate_h = 40;  // 同・高さ (Z)
m8_pass_flat = 8.4;  // M8皿ネジ軸部の通し六角 二面幅 (呼び7.8Φ)
m8_head_flat = 16.0; // 皿部分の六角カウンターボア 二面幅 (実測15.6Φ)
m8_head_depth = 4.5; // 皿部分の高さ
m8_screw_len = 8.6;  // 皿込みの全長
// クリアランス: ケースは「少しスカスカなくらい」が良いとの user 判断で 0.4
clearance = 0.4;
// アイテム1: Bluetooth イヤホンのケース (横幅・奥行き・ケースを沈める深さ)
ear_case = [ 61.0, 29.5, 34.0 ];
// アイテム2: Bluetooth ピンマイクのケース
mic_case = [ 80.8, 37.7, 32.0 ];
// ピンマイクケースの背面へ噛ませる L字 USB-C 変換器の張り出し (幅・厚さ)
mic_adapter = [ 12.3, 8.3 ];
usb_slot_w = 14; // イヤホンケース底面の USB-C 長穴の幅 (横中央)
usb_slot_front = 7.5; // 前壁内面から長穴の手前側まで
usb_slot_back = 16.0; // 前壁内面から長穴の奥側まで (前面9・奥面15の再計算値)
usb_slot_r = 2; // 長穴の角丸 (ケーブルの角が丸いので角丸で足りる)

wall = 3;    // ポケットの側壁厚
floor_t = 3; // ポケットの床厚
pocket_r = 4; // ポケット内側コーナーのR (ケースの角が丸いため)
corner_r = 2; // 外側垂直エッジのR (角が刺さると痛いという user 指示)
arc_fn = 64; // 円弧の分割数 (このリポジトリの既存慣行)
// 取付座の板厚。皿カウンターボア4.5 + 残り肉1.5 で決めた。皿ネジは
// 皿込み8.6 (軸部4.1) しか無いので、座を厚くするほど軸がクランプ板へ届か
// なくなる (板厚8なら掛かりは 8.6-8 = 0.6mm しか残らない)。残り肉1.5mm を
// 皿の座面兼ブリッジとして確保したうえで、クランプ板4.2の M8 メスへ
// 8.6 - 6.0 = 2.6mm 掛ける配分にした。掛かりを増やすには座を薄くするか、
// より長い M8 皿ネジへ替える (実物合わせで再評価する)
mount_t = 6.0;

// --- 派生値 ---
m8_shank_len = m8_screw_len - m8_head_depth; // 軸部 4.1
screw_engagement = m8_shank_len - (mount_t - m8_head_depth);
// flat-up 配置では水平方向の穴半径は対角/2 (= 二面幅/(2*cos30))
m8_head_diag = m8_head_flat / cos(30);
seat_w = clamp_plate_w;
seat_h = clamp_plate_h;
m8_z = seat_h / 2;

ear_inner = [ ear_case[0] + clearance, ear_case[1] + clearance ]; // 61.4×29.9
ear_depth = ear_case[2];
mic_inner = [ mic_case[0] + clearance, mic_case[1] + clearance ]; // 81.2×38.1
mic_depth = mic_case[2];
// 凸断面の切り欠き: L字変換器を装着したまま上から落とし込むための通路
mic_channel = [ mic_adapter[0] + clearance, mic_adapter[1] + clearance ];

ear_out_w = ear_inner[0] + 2 * wall;
ear_out_d = ear_inner[1] + 2 * wall;
ear_out_h = ear_depth + floor_t;
ear_x0 = -seat_w / 2 - ear_out_w; // 左ポケットの左端

// 背面側は「外壁 wall + チャンネル奥行き」を確保する。チャンネルは背面壁の
// 中に彫るのではなく、背面壁を厚くしてその中を通す (外壁3mmは残る)
mic_out_w = mic_inner[0] + 2 * wall;
mic_out_d = mic_inner[1] + mic_channel[1] + 2 * wall;
mic_out_h = mic_depth + floor_t;
mic_x0 = seat_w / 2; // 右ポケットの左端 (取付座の右端と共有)

ear_cav = [ ear_x0 + wall, wall ]; // 左ポケット内寸の原点 (X, Y)
mic_cav = [ mic_x0 + wall, wall + mic_channel[1] ]; // 右ポケット内寸の原点
ear_cav_cx = ear_cav[0] + ear_inner[0] / 2;
mic_cav_cx = mic_cav[0] + mic_inner[0] / 2;
ear_front_y = ear_cav[1] + ear_inner[1]; // 左ポケット前壁の内面
usb_slot_y = ear_front_y - usb_slot_back; // 長穴の奥端 (前壁内面から16.0)

// 四隅を r で丸めた矩形の2D輪郭 (原点が左下・X方向 w・Y方向 d)
module
rounded_rect_2d(w, d, r)
{
    translate([ r, r ]) offset(r = r, $fn = arc_fn)
        square([ w - 2 * r, d - 2 * r ]);
}

// 外形の2D輪郭。取付座と、指定されたポケットの外形を2Dで足してから
// opening (縮めてから膨らませる) を掛け、凸の角だけを R2 に丸める。
// 凹の角 (座とポケットの取り合い) は opening では丸まらないので、接合部の
// 肉は full 断面のまま残る — 各ブロックを個別に丸めて突き合わせると
// 接触面が R の分だけ痩せて折れやすくなるため、この順序で作る
module
footprint_2d(with_ear, with_mic)
{
    offset(r = corner_r, $fn = arc_fn) offset(r = -corner_r, $fn = arc_fn)
    {
        translate([ -seat_w / 2, 0 ]) square([ seat_w, mount_t ]);
        if (with_ear)
            translate([ ear_x0, 0 ]) square([ ear_out_w, ear_out_d ]);
        if (with_mic)
            translate([ mic_x0, 0 ]) square([ mic_out_w, mic_out_d ]);
    }
}

module
earphone_mic_holder()
{
    echo(str("CONTRACT earphone_mic_holder: clamp_plate = ",
             [ clamp_plate_w, clamp_plate_t, clamp_plate_h ]));
    echo(str("CONTRACT earphone_mic_holder: mount_seat = ",
             [ seat_w, mount_t, seat_h ]));
    echo(str("CONTRACT earphone_mic_holder: m8_pass_flat = ", m8_pass_flat));
    echo(str("CONTRACT earphone_mic_holder: m8_head_flat = ", m8_head_flat));
    echo(str("CONTRACT earphone_mic_holder: m8_head_depth = ", m8_head_depth));
    echo(str("CONTRACT earphone_mic_holder: m8_center = ", [ 0, m8_z ]));
    echo(str("CONTRACT earphone_mic_holder: screw_engagement = ",
             screw_engagement));
    echo(str("CONTRACT earphone_mic_holder: clearance = ", clearance));
    echo(str("CONTRACT earphone_mic_holder: ear_inner = ",
             [ ear_inner[0], ear_inner[1], ear_depth ]));
    echo(str("CONTRACT earphone_mic_holder: mic_inner = ",
             [ mic_inner[0], mic_inner[1], mic_depth ]));
    echo(str("CONTRACT earphone_mic_holder: mic_channel = ", mic_channel));
    echo(str("CONTRACT earphone_mic_holder: usb_slot = ",
             [ usb_slot_w, usb_slot_back - usb_slot_front ]));
    echo(str("CONTRACT earphone_mic_holder: usb_slot_from_front = ",
             [ usb_slot_front, usb_slot_back ]));
    echo(str("CONTRACT earphone_mic_holder: wall = ", wall));
    echo(str("CONTRACT earphone_mic_holder: floor_t = ", floor_t));
    echo(str("CONTRACT earphone_mic_holder: pocket_r = ", pocket_r));
    echo(str("CONTRACT earphone_mic_holder: corner_r = ", corner_r));
    echo(str("CONTRACT earphone_mic_holder: outer = ",
             [ ear_out_w + seat_w + mic_out_w, mic_out_d, seat_h ]));

    // 皿ネジの配分 (1e-9 は浮動小数の丸め猶予)。座が厚すぎると軸部が
    // クランプ板の M8 メスへ届かず、薄すぎると皿の座面が抜ける
    assert(mount_t >= m8_head_depth + 1, "mount seat is too thin for the head");
    assert(screw_engagement >= 2 - 1e-9,
           "screw barely reaches the clamp M8 thread");
    assert(screw_engagement <= clamp_plate_t + 1e-9,
           "screw bottoms out through the clamp plate");
    // 皿カウンターボアは取付座 (= クランプ板と同じ 40×24) に収まること
    assert(m8_head_diag <= seat_w + 1e-9,
           "countersink runs past the seat width");
    assert(m8_head_diag <= seat_h + 1e-9,
           "countersink runs past the seat height");
    // opening が取付座の帯を切らない条件 (座はポケット同士を繋ぐ梁でもある)
    assert(mount_t >= 2 * corner_r, "mount_t is too thin for corner_r");
    // ポケットの内側R4が内寸を食い尽くさないこと
    assert(2 * pocket_r <=
               min(ear_inner[0], ear_inner[1], mic_inner[0], mic_inner[1]),
           "pocket_r is too large for the pockets");
    // 凸のチャンネルが内寸の角R4に食い込まないこと (背面中央に収まること)
    assert(mic_channel[0] + 2 * pocket_r <= mic_inner[0],
           "mic channel is too wide for the pocket back wall");
    // USB-C 長穴が左ポケットの床の中に収まること (前壁内面が基準)
    assert(usb_slot_front > 0 && usb_slot_back <= ear_inner[1],
           "USB slot runs past the pocket floor");
    assert(usb_slot_w + 2 * pocket_r <= ear_inner[0],
           "USB slot is too wide for the pocket floor");

    difference()
    {
        // 3つの外形を底面から各々の高さまで押し出して重ねる。低い方の輪郭は
        // 高い方の輪郭に包含される (opening は単調) ので、結果は
        // 「右35 → 左37 → 座40」と段になった1つの塊になる
        union()
        {
            linear_extrude(height = mic_out_h) footprint_2d(true, true);
            linear_extrude(height = ear_out_h) footprint_2d(true, false);
            linear_extrude(height = seat_h) footprint_2d(false, false);
        }

        // 左ポケット: イヤホンケースの内寸 61.4×29.9・深さ34 (上開き)
        translate([ ear_cav[0], ear_cav[1], floor_t ])
            linear_extrude(height = ear_depth + 1)
                rounded_rect_2d(ear_inner[0], ear_inner[1], pocket_r);

        // 左ポケット床の USB-C 長穴: 横中央 14mm 幅、前壁内面から
        // 7.5〜16.0mm。ケーブルは下から刺さる
        translate([ ear_cav_cx - usb_slot_w / 2, usb_slot_y, -0.5 ])
            linear_extrude(height = floor_t + 1) rounded_rect_2d(
                usb_slot_w, usb_slot_back - usb_slot_front, usb_slot_r);

        // 右ポケット: ピンマイクケースの内寸 81.2×38.1・深さ32 (上開き)
        translate([ mic_cav[0], mic_cav[1], floor_t ])
            linear_extrude(height = mic_depth + 1)
                rounded_rect_2d(mic_inner[0], mic_inner[1], pocket_r);

        // 凸のチャンネル: 背面中央に 12.7×8.7。背面壁の全高と床を貫通させ、
        // L字変換器を付けたまま上からストンと落として、ケーブルを下へ抜く。
        // 床のそれ以外はケースの受けとして残る。+0.5 はポケット内寸との
        // 重ね代 (切削同士を面で接触させると退化した稜が残るため)
        translate([ mic_cav_cx - mic_channel[0] / 2, wall, -0.5 ])
            cube([ mic_channel[0], mic_channel[1] + 0.5, mic_out_h + 1 ]);

        // M8皿ネジ (軸Y・flat-up): 通し六角が取付座を貫通し、外面 (y=mount_t)
        // 側に皿用の六角カウンターボアが深さ4.5で開く。ネジは部品の外側から
        // クランプ板の M8 メスへ入り、部品をクランプ板の面へ引き付ける
        translate([ 0, mount_t / 2, m8_z ])
            hex_y_flat_up(m8_pass_flat, mount_t + 0.2);
        translate([ 0, mount_t - m8_head_depth / 2 + 0.05, m8_z ])
            hex_y_flat_up(m8_head_flat, m8_head_depth + 0.1);
    }
}

earphone_mic_holder();
