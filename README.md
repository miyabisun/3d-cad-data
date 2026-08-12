# 3D CAD Data

OpenSCADの設計データをGitで管理するrepositoryです。編集する正本は
`src/projects/`と`src/modules/`に置きます。scad-live用に別の場所へコピーする
必要はありません。

## scad-liveで使う

初回だけ、home-server repositoryの`systemd/README.md`にあるscad-liveの
インストール手順を実行します。

このrepositoryへ戻り、次を実行します。

```sh
./bin/use-scad-live
```

これでscad-liveはこのrepositoryを直接監視します。`src/projects/`の`.scad`を編集し、
<http://127.0.0.1:8080>を開いてください。生成したSTLは`dist/`へ入り、Gitには
追加されません。

別のrepositoryへ切り替えたい場合は、切り替え先でも`./bin/use-scad-live`を実行します。

## ディレクトリ

- `src/projects/`: projectごとの`.scad`
- `src/modules/`: 共有OpenSCAD module
- `dist/`: 生成したSTL（Git管理外）

## 手動実行

scad-liveを使わず単発で全projectを変換する場合:

```sh
./bin/render
```

既存のNode.js製watcher/viewerを使う場合は`npm install`後に実行します。

```sh
./bin/watch
./bin/serve
```

OpenSCAD fileは2space indentationで、commit時に`openscad-format`を適用します。
