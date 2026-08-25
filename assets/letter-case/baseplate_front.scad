include <letter_case.scad>

// 前片: 引き出しの前側。前縁 4 + 4 行。奥側の端は継ぎ目 (縁なし)。
// 左右の縁は全長 (前端から継ぎ目まで) を肉抜きの範囲にする
echo(str(contract, " split=front rows=", front_rows, " len=", front_len));
letter_case_plate(front_rows,
                  [ side_rim, side_rim, front_rim, 0 ],
                  [ 0, front_len ]);
