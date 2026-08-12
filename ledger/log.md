# 3D CAD ledger Update Log

## 2026-08-12

- **Creation**: OKF v0.2 bundleとして台帳を新設した。`print/`のSMB書き込み共有
  （`3dp-3mf`）の導入と対で、`.3mf`の意味・状態・経緯をGitのcommit messageでは
  なくここで持つ方針にした。整合検査は`bin/check`（`npm test`に組み込み）。
- **Creation**: 設計思想を持つ`Design` concept（`designs/`）を導入した。
  `.scad`のコメント欄が設計意図で汚れるというuserの不満が起点。第一号として
  [スチールラック 500x400](designs/steel-rack-500x400.md)をuserの発言から
  記録した。`bin/check`にDesignの検査（scope・verbatim見出し）を追加。
