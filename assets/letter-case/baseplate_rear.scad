include <letter_case.scad>

// 奥片: 引き出しの奥側。3 行 + 奥縁 18。前側の端は継ぎ目 (縁なし)。
// 左右の縁は継ぎ目から奥縁の手前 (ソケット最終行の端) までを肉抜きの範囲にし、
// 奥縁のハニカムとの間に無垢の帯を残す
echo(str(contract, " split=rear rows=", rear_rows, " len=", rear_len));
letter_case_plate(rear_rows,
                  [ side_rim, side_rim, 0, back_rim ],
                  [ 0, rear_rows* gf_pitch ]);
