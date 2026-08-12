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

## 手動実行

scad-liveを使わず単発で全projectを変換する場合:

```sh
./bin/render
```

OpenSCAD fileは2space indentationで、commit時に`openscad-format`を適用します。
