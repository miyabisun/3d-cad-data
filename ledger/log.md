# 3D CAD ledger Update Log

## 2026-08-12

- **Creation**: OKF v0.2 bundleとして台帳を新設した。`print/`のSMB書き込み共有
  （`3dp-3mf`）の導入と対で、`.3mf`の意味・状態・経緯をGitのcommit messageでは
  なくここで持つ方針にした。整合検査は`bin/check`（`npm test`に組み込み）。
- **Creation**: 設計思想を持つ`Design` concept（`designs/`）を導入した。
  `.scad`のコメント欄が設計意図で汚れるというuserの不満が起点。第一号として
  [スチールラック 500x400](designs/steel-rack-500x400.md)をuserの発言から
  記録した。`bin/check`にDesignの検査（scope・verbatim見出し）を追加。
- **Update**: [スチールラック 500x400](designs/steel-rack-500x400.md)へ
  スライドレール組付けの実測寸法と算段を追記した（userのノギス実測由来。
  オープンフレームが地べたで稼働中のため早急に組み立てたいという文脈）。
- **Update**: 同conceptへQ&Aの結果を反映した。木ネジ受けの六角穴は
  二面幅3mm（対角3mm→対角3.5mm→二面幅3mmとuserが順に訂正）、
  L字アングル板厚2.2mm、オープンフレームはツライチではなく乗せ方式で
  19mm浮かせて支える。
- **Update**: 部品分割の決定（一体型は印刷不可→2分割×前後2種=4部品）と、
  スライドレール外側のネジ穴位置の実測（手前34/98mm、奥76.5/172.5mm）を
  記録した。当面の開発対象はスライドレール外側〜L字アングルの接合部。
- **Update**: スライドレール外側ブラケットを実装した
  （`modules/slide_rail_outer_bracket.scad` +
  `assets/steel-rack/500x400/slide_rail_outer_{front,rear}.scad`、
  検証は`tests/slide-rail-outer.sh`）。旧算段「240mm間隔・±120mm」を
  superseded と明示し、実装派生値（短辺40mm・M6中心27mm・穴深さ14mm・
  Z対称による左右共用）を記録した。
