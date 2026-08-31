# gridfinity-bin

Gridfinity の bin (箱)。レターケースのベースプレート (`assets/letter-case`) に
並べて使う。設計思想は `ledger/designs/gridfinity-bin-4u.md` が正本。
共通値は `modules/gridfinity_bin_4u.scad`、形状は `modules/gridfinity_bin.scad`。

## bin_{c}x{r}x4u.scad (10 種)

cols 1..2 × rows 1..5 の高さ 4U。cols が横 (X)、rows がラベルの壁から奥 (Y)。
各 asset は `gridfinity_bin(cols, rows, units)` の 1 呼び出し。どれも底面を
ビルドプレートへ置き、サポート不要 (面取り・くさびは 45°)。

- 外形 41.5 角 (1×2 は 41.5×83.5)、角 R3.75。壁の上端 z=28、リップ 4.4 で全高 32.4
- 底は Gridfinity 公称の 3 段 (35.6 → 37.2 → 41.5、高さ 4.75) で穴なし (無垢)
- 壁 1.2、床 1.2 (床の天面 z=5.95)
- 薄いリップ: 壁がそのまま立ち、内側の上端 0.8 を 45° に落とすだけ。内側に棚は無い
- ラベル天板: 手前 (y=0) の壁の上端と面一で内側へ 13mm 張り出す厚さ 1 の板。
  12mm 幅のラベルシール用。下は 45° の無垢のくさびが壁まで下りる (ブリッジ無し。
  中身はスライサのインフィル任せ)。天板の先端と 45° 面の境目は R1
