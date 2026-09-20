# FlashTap収納用Gridfinity bin

[button_storage.scad](button_storage.scad)は、**3.5×5×1Uの上部**と
**3.5×5×3Uの下部**で26個を保存するケース。初期表示は組立状態。
以下のコマンドはリポジトリのルートで実行する。
外形146.5×209.5mmで、3.5×5セルに収まる。
`part="upper"` / `part="lower"`を各1個、Z=0を下にして印刷する。
上部の底は全セルを一体化した足とし、中央を底から3mm残してくり抜いた。
外周には幅3mmの枠と既存binの薄いリップを残す。
下部は仕切り・ラベル天板なしの通常bin。半セルの足は左端に来るため、
アイリス用ベースプレートの左半セル列に合わせて置く。
上部の連続底は下部bin用で、ベースプレートへ直接は嵌まらない。

| 項目 | 設計値 |
|---|---|
| 24mmボタン | 穴φ24.4×24個、縁φ29として配置 |
| 30mmボタン | 穴φ30.4×2個、縁φ34として配置 |
| 配列 | 小4列×6段の千鳥＋大2個 |
| 小同士の最短中心距離 | 29mm（段間25.115mm・交互に横14.5mmずらす） |
| 小と大の最短中心距離 | 31.5mm（横14.5mm・縦27.964mm） |
| 大同士の中心距離 | 58mm |
| 縁を含む占有寸法 | 130.5×185.038mm |
| 3mm厚の配置面 | 140.5×203.5mm、縁から枠まで左右5mm・前後約9.23mm |
| 穴間の最小肉厚 | 小同士4.6mm、小と大4.1mm |

縁同士は指定の中心距離で接する（公称隙間0mm）。穴径の印刷補正は
`hole_clearance`（既定0.4mm）で行う。ボタンの保持爪の掛かり方や抜き差しの
硬さの調整が必要な場合は、実物に合わせる。

### 高さの調査（2026-09-19）

公式商品の寸法図は、[24mm](https://cdn.shopify.com/s/files/1/0870/6441/2436/files/24FGB_956bc77c-1c6c-46c6-ab2d-18cd0ea483df.png?v=1729244181)・
[30mm](https://cdn.shopify.com/s/files/1/0870/6441/2436/files/30FGB_5892b44c-b963-4e57-ad15-7ed74d49b6f5.png?v=1729179443)とも
フランジ下面から底まで17mm、上側4.2mm。本体径は23.6/29.5mm。
設計上の縁径は29/34mmとし、図の縁径26/32mmより大きい範囲を確保している。

既存の薄いリップと底の輪郭では、下部3Uに上部を載せた底位置は約21.06mm。
組立表示は丸めて21.1mmとし、表示上は0.04mmの逃げを設ける。
1U+3Uの公称4Uは28mmだが、リップを含む組立全高は**約32.5mm**になる。
板上面は約24.1mm、下部の床上面は5.95mmなので、17mmのボタン下端まで
**約1.1mm**残る。ボタン上端は約28.3mmで、ケースのリップより低い。
[レターケースの実測](../../../ledger/designs/letter-case-gridfinity.md)にある
中央床からの有効高さ34.7mmに対し、ケース上端に約2.2mm、ボタン上端に
約6.4mmの余裕がある。配線なし・公式図の通常キャップ付きで成立する寸法計算。
端子カバーや配線付き、別形状のキャップはこの包絡形状の検証に含めない。
2026-09-20、ユーザーが予定していた26個すべてを収納できたことを確認。
たわみや引き出し開閉についての個別の実測は未記録。

```sh
mkdir -p dist/leverless/button-storage
openscad --export-format binstl -o dist/leverless/button-storage/button_storage_upper.stl -D 'part="upper"' assets/leverless/button-storage/button_storage.scad
openscad --export-format binstl -o dist/leverless/button-storage/button_storage_lower.stl -D 'part="lower"' assets/leverless/button-storage/button_storage.scad
python3 tests/button-storage.py
```

検証では出力STLの閉曲面・連結性、26穴の径と中心、縁同士の距離、底の連続性と
板厚3mm、下部の通常セル/半セル足、上下とボタン包絡形状の体積非干渉を確認する。
