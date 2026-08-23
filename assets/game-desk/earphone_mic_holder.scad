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
//   Y = 0 がクランプ板への当たり面。-Y へ本体 (取付座とポケット) が伸びる。
//     +Y 側はクランプ板 4.2 を逃がす帯と、その左右でデスク面 (y=4.2) へ
//     当たる段になる
//   Z = 0 が部品底面。+Z が上で、上端は 40 の一平面。この上端はクランプ板の
//     上端より top_drop (4.5) だけ低い — クランプ上腕の厚みぶん部品が
//     デスク天板からはみ出して邪魔になるため、部品ごと下げてある
// クランプ板は部品座標で Z 4.5..44.5 に掛かるので、その中央にある M8 メスの
// 中心は (X, Z) = (0, 24.5) になる。部品の datum (底面 Z=0 = プリント面) は
// 動かさないので、「天端を 4.5 下げる」は M8 中心が 20 → 24.5 へ上がる形で
// 現れる (M8 中心 20 の旧配置は superseded)。
//
// 前後の定義: 前 = デスク接触面 (y=4.2) の側、後 = その反対側。ケースを
// 差し込む向き依存の feature (USB-C 長穴・凸チャンネル) は、この前壁の内面
// (front_inner_y) を基準に置く。
//
// 印刷向き: 底面 (z=0) をビルドプレートへ置き、ポケットの開口を上へ向ける。
// 壁・ポケット・切り欠きはすべて垂直面で、水平な天井を持つのは M8 の
// 六角穴だけ (flat-up = 天井が短い水平ブリッジ) になる。外側の垂直エッジは
// R2 で落とし、底面の水平エッジは未加工のまま残す。

// --- 実測値 (すべて現物合わせ前提の暫定値) ---
clamp_plate_w = 24;  // クランプ立ち上がり板の横幅 (X)
clamp_plate_t = 4.2; // 同・板厚 (Y)。M8メスの掛かり代でもある
clamp_plate_h = 40;  // 同・高さ (Z)
m8_pass_flat = 8.4;  // M8皿ネジ軸部の通し六角 二面幅 (呼び7.8Φ)
m8_head_flat = 16.0; // 皿逃げの六角錐台 外面側の二面幅 (実測15.6Φ)
m8_head_depth = 4.5; // 皿部分の高さ
m8_screw_len = 8.6;  // 皿込みの全長
// 部品の上端をクランプ板の上端より下げる量。クランプの上腕がデスク天板の上に
// 乗る厚みぶん、部品が天板からはみ出して邪魔になるため下げる (user 指摘)
top_drop = 4.5;
// クリアランス: ケースは「少しスカスカなくらい」が良いとの user 判断で 0.4
clearance = 0.4;
// アイテム1: Bluetooth イヤホンのケース (横幅・奥行き・ケースを沈める深さ)
ear_case = [ 61.0, 29.5, 34.0 ];
// アイテム2: Bluetooth ピンマイクのケース
mic_case = [ 80.8, 37.7, 32.0 ];
// ピンマイクケースの背面へ噛ませる L字 USB-C 変換器の張り出し (幅・厚さ)
mic_adapter = [ 12.3, 8.3 ];
usb_slot_w = 14; // イヤホンケース底面の USB-C 長穴の幅 (横中央)
// 前壁 = デスク接触面側の壁。ケースの前面がデスク側を向く差し込み向き
usb_slot_front = 7.5; // 前壁内面から長穴の手前側まで
usb_slot_back = 16.0; // 前壁内面から長穴の奥側まで (前面9・奥面15の再計算値)
usb_slot_r = 2; // 長穴の角丸 (ケーブルの角が丸いので角丸で足りる)

wall = 3; // ポケットの側壁厚
// ポケットの床厚。上端を Z40 の一平面へ揃えるのが必須要件なので、収納深さ
// (34 / 32) を変えずに床の厚みで高さの差を吸収する。この一平面はデスク天板と
// 面一にする面で、クランプ板の上端より top_drop (4.5) 低い (クランプ板の上端と
// 同一平面へ揃えていた旧仕様は superseded)。増えるのはインフィルだけなので
// 重量・材料の問題にはならない (user 判断)
ear_floor_t = 6;
mic_floor_t = 8;
pocket_r = 4; // ポケット内側コーナーのR (ケースの角が丸いため)
corner_r = 2; // 外側垂直エッジのR (角が刺さると痛いという user 指示)
// 取付座の外面と両ポケットの側壁が作る凹角を埋める 45度 三角形の脚長。
// 中央の座だけで左右のポケットを繋ぐと、この凹角が細い板頼りで弱い (user 指摘)
gusset = 2;
arc_fn = 64; // 円弧の分割数 (このリポジトリの既存慣行)
// 取付座の板厚。皿の逃げ 4.5 + 残り肉1.5 で決めた。皿ネジは
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
// 皿の逃げの絞り勾配 (二面幅/深さ)。外面16.0 から深さ4.5 で通し8.4 になる
m8_head_slope = (m8_head_flat - m8_pass_flat) / m8_head_depth;
m8_head_over = 0.1; // 錐台を外面より外へ出す切削の抜き代
seat_w = clamp_plate_w;
seat_h = clamp_plate_h;
// M8 の中心 Z。クランプ板は部品座標で top_drop..top_drop+40 に掛かるので、
// その中央は seat_h + top_drop - clamp_plate_h / 2 = 24.5 になる。
// 部品の datum (底面 Z=0) は動かさない — seat_h / 2 の旧配置は superseded
m8_z = seat_h + top_drop - clamp_plate_h / 2;
// クランプ板を逃がす帯の幅。板 24 に対してクリアランスは総量 0.4 (片側0.2)
// で取る。左右それぞれへ 0.4 振ると帯が 24.8 になり、板が帯の中で泳ぐ
clamp_slot_w = clamp_plate_w + clearance;

ear_inner = [ ear_case[0] + clearance, ear_case[1] + clearance ]; // 61.4×29.9
ear_depth = ear_case[2];
mic_inner = [ mic_case[0] + clearance, mic_case[1] + clearance ]; // 81.2×38.1
mic_depth = mic_case[2];
// 凸断面の切り欠き: L字変換器を装着したまま上から落とし込むための通路
mic_channel = [ mic_adapter[0] + clearance, mic_adapter[1] + clearance ];

ear_out_w = ear_inner[0] + 2 * wall;
ear_out_d = ear_inner[1] + 2 * wall;
ear_out_h = ear_depth + ear_floor_t;
ear_x0 = -seat_w / 2 - ear_out_w; // 左ポケットの左端

// 背面 (デスクの反対側) は「外壁 wall + チャンネル奥行き」を確保する。
// チャンネルは背面壁の中に彫るのではなく、背面壁を厚くしてその中を通す
// (外壁3mmは残る)
mic_out_w = mic_inner[0] + 2 * wall;
mic_out_d = mic_inner[1] + mic_channel[1] + 2 * wall;
mic_out_h = mic_depth + mic_floor_t;
mic_x0 = seat_w / 2; // 右ポケットの左端 (取付座の右端と共有)
outer_w = ear_out_w + seat_w + mic_out_w; // 部品全体の横幅 178.6
// 部品全体の奥行き 52.8。両ポケットのブロックはデスク接触面から始まるので、
// デスク側の段 4.2 はブロックの中に含まれる。当たり面から +Y へ 4.2 の帯を
// 別に足していた旧構成の 52.8 + 4.2 = 57 は superseded
outer_d = max(ear_out_d, mic_out_d);

// デスク接触面。当たり面 (y=0) から +Y へクランプ板の厚みだけ回り込む
desk_y = clamp_plate_t;
// 前壁 (デスク側) の内面。両ポケットとも、外形をデスク接触面から始めて
// 「壁3 → ケース内寸 → (チャンネル) → 壁3」の順に並べるので、前壁は
// デスク側・反対側とも実厚 3mm になる。ポケットを当たり面 (y=0) 基準に
// 置いて +Y へ 4.2 の帯を足していた旧構成は、前壁が 3 + 4.2 = 7.2mm に
// なっていた (superseded)
front_inner_y = desk_y - wall;
// 各ポケット内寸の原点 (X, Y) = 前壁内面から奥へ内寸の分だけ下がった角
ear_cav = [ ear_x0 + wall, front_inner_y - ear_inner[1] ];
mic_cav = [ mic_x0 + wall, front_inner_y - mic_inner[1] ];
ear_cav_cx = ear_cav[0] + ear_inner[0] / 2;
mic_cav_cx = mic_cav[0] + mic_inner[0] / 2;
// 凸チャンネルの奥端 = 背面 (デスクの反対側) 外壁の内面
mic_back_inner_y = desk_y - mic_out_d + wall;
usb_slot_y = front_inner_y - usb_slot_back; // 長穴の奥端 (前壁内面から16.0)

// 四隅を r で丸めた矩形の2D輪郭 (原点が左下・X方向 w・Y方向 d)
module
rounded_rect_2d(w, d, r)
{
    translate([ r, r ]) offset(r = r, $fn = arc_fn)
        square([ w - 2 * r, d - 2 * r ]);
}

// 六角錐台 (軸Y・flat-up): 原点が二面幅 flat_a の面で、+Y へ l 進む間に
// 二面幅が flat_b まで直線的に絞られる。皿ネジの逃げに使う。
// 2D の六角は hex_hole と同じ流儀 (対角 = 二面幅/cos30、$fn=6 で flat-up)
module
hex_y_taper_flat_up(flat_a, flat_b, l)
{
    rotate([ -90, 0, 0 ]) linear_extrude(height = l, scale = flat_b / flat_a)
        circle(d = flat_a / cos(30), $fn = 6);
}

// 右 (+X) の補強ガセットの2D輪郭。取付座の外面 (y=-mount_t) とポケットの
// 側壁 (x=seat_w/2) が作る凹角へ、脚 gusset の45度直角三角形を置く。
// 斜辺は x + y = seat_w/2 - mount_t - gusset (= 4) の45度線で、材料は
// x + y がそれより大きい側に残る
module
gusset_2d()
{
    polygon([[seat_w / 2, -mount_t],
             [seat_w / 2 - gusset, -mount_t],
             [seat_w / 2, -mount_t - gusset]]);
}

// 外形の2D輪郭。取付座・両ポケット・デスク側の段を2Dで足してから
// opening (縮めてから膨らませる) を掛け、凸の角だけを R2 に丸める。
// 凹の角 (座とポケットの取り合い) は opening では丸まらないので、接合部の
// 肉は full 断面のまま残る — 各ブロックを個別に丸めて突き合わせると
// 接触面が R の分だけ痩せて折れやすくなるため、この順序で作る。
// 両ポケットのブロックは当たり面ではなくデスク接触面 (y=desk_y) から始める。
// これで、クランプ板の無い左右がデスク面へ当たる段が外形そのものになり、
// 壁厚も他と同じ 3mm に揃う (全幅へ 4.2 の帯を足す旧構成は superseded)。
// クランプ板の逃げは opening の後に切る。板の角は直角なので、逃げの角も
// 直角のまま残す。
// 補強ガセットも opening の後に union する。opening の erosion は凸の角しか
// 動かさないとはいえ、45度の細い三角を先に足すと縮めた段階で消えてしまう
module
footprint_2d()
{
    difference()
    {
        union()
        {
            offset(r = corner_r, $fn = arc_fn)
                offset(r = -corner_r, $fn = arc_fn)
            {
                translate([ -seat_w / 2, -mount_t ])
                    square([ seat_w, mount_t ]);
                translate([ ear_x0, desk_y - ear_out_d ])
                    square([ ear_out_w, ear_out_d ]);
                translate([ mic_x0, desk_y - mic_out_d ])
                    square([ mic_out_w, mic_out_d ]);
                // デスク側の段の帯。ポケットのブロックだけでは中央 (取付座の
                // 幅) にデスク接触面が無く、そこが凸の角になって opening で
                // R2 に丸まる — クランプ板の逃げの内側の角は板の直角と
                // 合わせたいので、帯で全幅を繋いでから逃げを切る
                translate([ ear_x0, 0 ]) square([ outer_w, desk_y ]);
            }
            gusset_2d();
            mirror([ 1, 0 ]) gusset_2d();
        }
        // クランプ板の逃げ: 当たり面から +Y のデスク帯のうち、中央 24.4 だけ
        // を板の厚み分だけ抜き、そこへ板を挟み込む。+1 は切削の抜き代
        translate([ -clamp_slot_w / 2, 0 ])
            square([ clamp_slot_w, desk_y + 1 ]);
    }
}

// 本体。上端が一平面 Z40 になったので、外形は全高 40 の一様な押し出し1本で
// 足りる (右35 → 左37 → 座40 と段になっていた旧構成は superseded)
module
holder_body()
{
    difference()
    {
        linear_extrude(height = seat_h) footprint_2d();

        // 左ポケット: イヤホンケースの内寸 61.4×29.9・深さ34 (上開き)
        translate([ ear_cav[0], ear_cav[1], ear_floor_t ])
            linear_extrude(height = ear_depth + 1)
                rounded_rect_2d(ear_inner[0], ear_inner[1], pocket_r);

        // 左ポケット床の USB-C 長穴: 横中央 14mm 幅、前壁 (デスク側) の内面
        // から 7.5〜16.0mm。ケーブルは下から刺さる
        translate([ ear_cav_cx - usb_slot_w / 2, usb_slot_y, -0.5 ])
            linear_extrude(height = ear_floor_t + 1) rounded_rect_2d(
                usb_slot_w, usb_slot_back - usb_slot_front, usb_slot_r);

        // 右ポケット: ピンマイクケースの内寸 81.2×38.1・深さ32 (上開き)
        translate([ mic_cav[0], mic_cav[1], mic_floor_t ])
            linear_extrude(height = mic_depth + 1)
                rounded_rect_2d(mic_inner[0], mic_inner[1], pocket_r);

        // 凸のチャンネル: 背面 (デスクの反対側) の中央に 12.7×8.7。背面壁の
        // 全高と床を貫通させ、L字変換器を付けたまま上からストンと落として、
        // ケーブルを下へ抜く。床のそれ以外はケースの受けとして残る。+0.5 は
        // ポケット内寸との重ね代 (切削同士を面で接触させると退化した稜が
        // 残るため)
        translate([ mic_cav_cx - mic_channel[0] / 2, mic_back_inner_y, -0.5 ])
            cube([ mic_channel[0], mic_channel[1] + 0.5, seat_h + 1 ]);

        // M8皿ネジ (軸Y・flat-up): 通し六角が取付座を貫通し、外面 (y=-mount_t)
        // 側に皿の逃げが開く。ネジは部品の外側からクランプ板の M8 メスへ
        // 入り、部品をクランプ板の面へ引き付ける
        translate([ 0, -mount_t / 2, m8_z ])
            hex_y_flat_up(m8_pass_flat, mount_t + 0.2);
        // 皿の逃げは直壁のボアではなく、外面の二面幅16.0 から
        // 深さ4.5 で通し 8.4 へ絞る六角錐台にする。断面がなだらかな三角形に
        // なり、皿がそのまま座る (user 指示)。錐台は同じ勾配のまま外面より
        // m8_head_over だけ外へ出すので、外面の切り口はちょうど 16.0 になる
        translate([ 0, -mount_t - m8_head_over, m8_z ])
            hex_y_taper_flat_up(m8_head_flat + m8_head_over * m8_head_slope,
                                m8_pass_flat,
                                m8_head_depth + m8_head_over);
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
    // 皿の逃げは直壁ではなく [外面の二面幅, 底の二面幅, 深さ] の六角錐台
    echo(str("CONTRACT earphone_mic_holder: m8_head_taper = ",
             [ m8_head_flat, m8_pass_flat, m8_head_depth ]));
    // 部品の上端をクランプ板の上端より下げる量。部品 datum は動かさないので
    // 観測できる形は M8 中心の Z (20 → 24.5) として現れる
    echo(str("CONTRACT earphone_mic_holder: top_drop = ", top_drop));
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
    echo(str("CONTRACT earphone_mic_holder: front_inner_y = ", front_inner_y));
    echo(str("CONTRACT earphone_mic_holder: wall = ", wall));
    echo(str("CONTRACT earphone_mic_holder: floor_t = ",
             [ ear_floor_t, mic_floor_t ]));
    echo(str("CONTRACT earphone_mic_holder: pocket_r = ", pocket_r));
    echo(str("CONTRACT earphone_mic_holder: corner_r = ", corner_r));
    echo(str("CONTRACT earphone_mic_holder: gusset = ", gusset));
    echo(str("CONTRACT earphone_mic_holder: desk_step = ",
             [ clamp_slot_w, clamp_plate_t ]));
    echo(str("CONTRACT earphone_mic_holder: outer = ",
             [ outer_w, outer_d, seat_h ]));

    // 皿ネジの配分 (1e-9 は浮動小数の丸め猶予)。座が厚すぎると軸部が
    // クランプ板の M8 メスへ届かず、薄すぎると皿の座面が抜ける
    assert(mount_t >= m8_head_depth + 1, "mount seat is too thin for the head");
    assert(screw_engagement >= 2 - 1e-9,
           "screw barely reaches the clamp M8 thread");
    assert(screw_engagement <= clamp_plate_t + 1e-9,
           "screw bottoms out through the clamp plate");
    // 皿逃げの六角錐台は取付座 (= クランプ板と同じ 40×24) に収まること
    assert(m8_head_diag <= seat_w + 1e-9,
           "countersink runs past the seat width");
    // 高さ方向は中心が top_drop だけ上がっているので、上下端で個別に見る
    assert(m8_z + m8_head_diag / 2 <= seat_h + 1e-9,
           "countersink runs past the seat top");
    assert(m8_z - m8_head_diag / 2 >= -1e-9,
           "countersink runs past the seat bottom");
    // 皿の逃げがガセットに食われないこと (ドライバーの入る幅も同じ条件)
    assert(m8_head_diag / 2 <= seat_w / 2 - gusset + 1e-9,
           "countersink reaches into the gusset");
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
    // 上端が一平面であること (必須要件)。深さは変えずに床で吸収するので、
    // 床を動かしたらここで止まる。この一平面はクランプ板の上端より
    // top_drop 低い (デスク天板と面一にするため)
    assert(ear_out_h == seat_h && mic_out_h == seat_h,
           "pocket tops must be flush with the seat top");
    // クランプ板の逃げがポケットの内寸まで届かないこと (床と壁を抜かない)
    assert(clamp_slot_w / 2 <= mic_x0 + wall,
           "clamp relief reaches into the pockets");
    // 前壁の内面が当たり面より +Y 側に残ること。壁がクランプ板の厚み以上に
    // 厚いと、ポケットの内寸が当たり面を越えてクランプ板の逃げと繋がる
    assert(front_inner_y > 0, "the front wall is thicker than the desk step");

    holder_body();
}

earphone_mic_holder();
