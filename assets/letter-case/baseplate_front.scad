include <letter_case.scad>

// 前片: 引き出しの前側。前縁 4 + 4 行。奥側の端は継ぎ目 (縁なし)
echo(str(contract, " split=front rows=", front_rows, " len=", front_len));
gf_baseplate(cols, front_rows, [ side_rim, side_rim, front_rim, 0 ], floor_t);
