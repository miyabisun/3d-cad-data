include <letter_case.scad>

// 奥片: 引き出しの奥側。3 行 + 奥縁 18。前側の端は継ぎ目 (縁なし)
echo(str(contract, " split=rear rows=", rear_rows, " len=", rear_len));
gf_baseplate(cols, rear_rows, [ side_rim, side_rim, 0, back_rim ], floor_t);
