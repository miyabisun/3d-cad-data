// 2D の X 筋交い窓。板の肉抜きへ difference で使う。
// 矩形 [w, d] (中心が原点) の窓から、対角 2 本の筋交い (幅 line) を残した
// 4 つの三角形の開口を返す。筋交いは窓の角から角へ渡し、窓の外へは出ない。

module
xbrace_window(size, line)
{
    w = size[0];
    d = size[1];
    diag = sqrt(w * w + d * d);
    difference()
    {
        square([ w, d ], center = true);
        for (sgn = [ -1, 1 ])
            rotate(sgn * atan2(d, w))
                square([ diag + line, line ], center = true);
    }
}
