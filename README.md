# 3D CAD Data

収納用品、家具の取付部品、コントローラー筐体などのOpenSCAD設計データ集です。
モデルを選び、手元の製品に合わせて寸法を調整し、STLへ出力して3Dプリンターで印刷できます。
適合寸法・印刷方向・実物での確認範囲は、各モデルのREADMEを参照してください。

## モデルを選ぶ

| 用途                 | モデル                                                                                                                                                                      |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 引き出し収納         | [レターケース用ベースプレート](assets/letter-case/README.md)、[Gridfinity bin](assets/gridfinity-bin/README.md)                                                             |
| ラック・机まわり     | [500×400mmスチールラック](assets/steel-rack/500x400/README.md)、[マグカップホルダー](assets/clamp/mug-holder/README.md)、[NFCタグ台](assets/clamp/nfc-tag-holder/README.md) |
| モニターアーム       | [エルゴトロン取付用ホルダー](assets/ergotron/README.md)                                                                                                                     |
| ゲームコントローラー | [レバーレス筐体・ボタン収納](assets/leverless/README.md)                                                                                                                    |
| 室内の取付・補修     | [ライトスタンド](assets/work-room/README.md)、[ドア用治具](assets/work-room/door/README.md)、[排水ホース接続](assets/laundry/README.md)                                     |

## STLを作る

[OpenSCAD](https://openscad.org/downloads.html)をインストールし、このリポジトリを取得します。
以下のコマンド例は、Gitと`openscad`が使えるシェルで実行してください。

```sh
git clone https://github.com/miyabisun/3d-cad-data.git
cd 3d-cad-data
mkdir -p dist/steel-rack/500x400
openscad --export-format binstl -o dist/steel-rack/500x400/separator.stl assets/steel-rack/500x400/separator.scad
```

この例は、外径20mm・高さ3.5mm・穴径4.6mmのセパレーターを出力します。
他のモデルでは、入力のSCADと出力先を置き換えてください。
複数部品を持つモデルは、各READMEに従って`part`を指定します。
組立状態の表示を、そのまま印刷用STLとして使わないでください。

OpenSCADの画面で編集する場合も、`assets/`のSCADを開きます。
`modules/`を参照するモデルがあるため、取得したディレクトリ構成を保ってください。

## 印刷する

生成したSTLを、お使いのプリンターに対応するスライサーへ読み込みます。
モデルの寸法・印刷方向・材質を確認し、嵌合が未確認の部品は少数で試してください。
設計値の検査だけでは、実物の強度や収縮後の適合を保証できません。

作者の環境では、scad-liveが生成した3MFをOrcaServerのプレートへ保存し、
スライスと印刷まで行います（次節）。スライサーのプロジェクトファイルはこのリポジトリに置きません。
対応する設計は[台帳](ledger/index.md)から辿れます。

## 編集とプレビュー

材料を分ける場合は[多色プリントの共通規約](docs/multi-material.md)に沿って
`primary`・`secondary`を指定します。scad-live v0.2.8以降は、役割と部品の位置関係を
保持した3MFを生成します。OrcaServerへ渡す場合は、先にOrcaServer v0.1.50以降へ
更新してください。上記のOpenSCAD単体によるSTL出力も引き続き利用できます。

ブラウザでプレビューする場合は、別途[scad-live](https://github.com/miyabi-sunny-side/scad-live)を
導入し、このリポジトリのルートで`scad-live`を実行します。
`assets/`を編集し、<http://127.0.0.1:8080>で結果を確認できます。

- `assets/`: 用途別のSCADと使い方
- `modules/`: [共有モジュール](modules/README.md)
- `dist/`: 生成した3MFまたはSTL（Git管理外）
- `ledger/`: 設計の根拠・変更履歴

全モデルをまとめて変換する`./bin/render`は、先に`dist/`を消去します。
部品選択や出力形式は指定しないため、個別のREADMEに生成手順があるモデルはそちらを使ってください。

`./bin/check`で台帳の形式と、設計conceptの対象ディレクトリを検査できます。
`npm test`は`git status`の変更が依存するテストだけを、`npm run test:all`は全テストを並列に実行します。
これらのスクリプトにはBashが必要です。SCADのインデントは2スペースです。
Node.jsとnpmがあれば、開発用依存を`npm ci`で導入できます。導入後は、
commit時に変更したSCADへ`openscad-format`が適用されます。
