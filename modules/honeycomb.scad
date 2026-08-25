// 2D ハニカム (六角穴の千鳥格子)。板の肉抜きへ difference で使う。
// 矩形 [w, d] (中心が原点) の中に、二面幅 hole の六角穴を壁 wall で並べる。
// 行は X に沿って走り、Y に積む。矩形からはみ出す穴は置かない (欠けた穴で
// 薄い壁を残さない) ので、外周には最低でも矩形の縁までの余白が残る。
// 格子は矩形の中心について対称になるよう置く。

// 六角の外接半径 (二面幅 → 頂点までの距離)
function honeycomb_r(hole) = hole / (2 * cos(30));
// 隣り合う穴の中心間隔 (行方向) と行の間隔
function honeycomb_dx(hole, wall) = hole + wall;
function honeycomb_dy(hole, wall) = honeycomb_dx(hole, wall) * sin(60);
// 矩形 d に収まる行数
function honeycomb_rows(d, hole, wall) = floor((d - 2 * honeycomb_r(hole)) /
                                               honeycomb_dy(hole, wall)) +
                                         1;

module
honeycomb(size, hole, wall)
{
    w = size[0];
    d = size[1];
    r = honeycomb_r(hole);
    dx = honeycomb_dx(hole, wall);
    dy = honeycomb_dy(hole, wall);
    rows = honeycomb_rows(d, hole, wall);
    imax = ceil(w / dx / 2) + 1;
    for (j = [0:rows - 1]) {
        y = (j - (rows - 1) / 2) * dy;
        for (i = [-imax:imax]) {
            x = (i + (j % 2) / 2) * dx; // 奇数行は半ピッチずらす
            // 六角は頂点が ±Y (平面が ±X を向く) なので X の半幅は hole/2、Y は
            // r
            if (abs(x) + hole / 2 <= w / 2 && abs(y) + r <= d / 2)
                translate([ x, y ]) rotate(30) circle(r = r, $fn = 6);
        }
    }
}
