# 3D CAD Data

OpenSCADの設計データをGitで管理するrepositoryです。編集する正本は
`assets/`と`modules/`に置きます。このrepositoryはscad-liveのベースキャンプ
規約（`assets/`・`modules/`・`dist/`）に従っています。

## scad-liveで使う

このrepositoryのrootで実行するだけです。

```sh
cd /path/to/3d-cad-data
scad-live
```

`assets/`の`.scad`を編集し、<http://127.0.0.1:8080>を開いてください。生成した
STLは`dist/`へ入り、Gitには追加されません。systemdでの常駐はhome-server
repositoryの`systemd/README.md`を参照してください。

## ディレクトリ

- `assets/`: projectごとの`.scad`
- `modules/`: 共有OpenSCAD module
- `dist/`: 生成したSTL（Git管理外）
- `print/`: BambuStudioのプロジェクト（`.3mf`、Git管理）
- `ledger/`: `.3mf`の台帳（OKF bundle。詳細は[ledger/index.md](ledger/index.md)）

## 印刷（Windows + BambuStudio）

自宅サーバーのSMB共有経由で使います（共有定義はhome-server repositoryの
`systemd/README.md`を参照）。

- `\\<サーバー>\3dp-stl` → `dist/`（読み取り専用）。STLをここから開く
- `\\<サーバー>\3dp-3mf` → `print/`（書き込み可）。プロジェクトをここへ保存する

`.3mf`はzipバイナリでGitのdiffが読めないため、意味・状態・経緯は`ledger/`が
持ちます。`.3mf`を保存・上書きしたら、会話ベースで台帳を更新してcommitします。
整合（`.3mf`と台帳の1:1対応・sha256一致）は`bin/check`が検査し、`npm test`に
含まれます。

## 手動実行

scad-liveを使わず単発で全projectを変換する場合:

```sh
./bin/render
```

台帳の整合検査を単体で走らせる場合:

```sh
./bin/check
```

OpenSCAD fileは2space indentationで、commit時に`openscad-format`を適用します。
