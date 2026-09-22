// アクリル板の端から既存M4穴の中心までの距離を調べるゲージ。
// PLA、平らな底面を下に印刷（90×36×6mm、サポート不要）。
// 板の下へ差し込み、立ち上がりの内面Y=0を板端に密着させる。
// 辺に沿って滑らせ、各候補穴を既存穴に重ねてM4ボルトを軽く通す。
// 刻印は板の外側に出る。隣接する辺でも繰り返し、四隅それぞれX/Yを記録する。
// 締め付け・穴あけには使わない。0.5mmは候補の間隔で、測定精度ではない。
// 複数候補が通る場合は中心の重なりとガタを比較し、必要ならoffsetsを細かくする。
// 印刷穴の収縮と既存穴/ボルトの隙間があるため、通っただけで寸法を断定しない。
offsets = [14, 14.5, 15, 15.5, 16, 16.5, 17, 17.5, 18];
hole_diameter = 4.2; // M4用。きつい場合は印刷条件に合わせて調整。

assert(len(offsets) > 0);
assert(hole_diameter > 0 && hole_diameter <= 6);
assert(min(offsets) >= 5 && max(offsets) <= 20);

length = len(offsets) * 10;

difference() {
  union() {
    translate([0, -12, 0]) cube([length, 36, 2]);
    translate([0, -3, 0]) cube([length, 3, 6]);
  }
  for (i = [0 : len(offsets) - 1]) {
    translate([5 + i * 10, offsets[i], -0.1])
      cylinder(d = hole_diameter, h = 2.2, $fn = 64);
    translate([5 + i * 10, -8, 1.4])
      linear_extrude(0.7)
        text(str(offsets[i]), size = 3.2, font = "Liberation Sans:style=Bold",
             halign = "center", valign = "center");
  }
}
