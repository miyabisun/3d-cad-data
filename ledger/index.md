---
okf_version: "0.2"
---

# 3D CAD ledger

このrepositoryの「コードから読めない意味」の台帳。conceptは**Design**だけを作る。

- **Design**（`designs/<slug>.md`）: 構造物の設計思想の台帳。なぜこの構成を
  選び・何を実現し・次にどこへ伸ばすかを、userの発言由来で持つ。形状は
  `.scad`で実装し、部品の機能はassetsのREADMEで説明する。`.scad`のコメントは
  幾何の注記に留める（設計意図をコメント欄に書かない）
- **Print**（`prints/<slug>.md`、廃止）: かつて`print/`に置いたBambuStudioの
  プロジェクト（`.3mf`）の台帳。2026-09-26に印刷経路をscad-live → OrcaServerへ
  移し、`print/`と`.3mf`を削除した。既存のconceptは`retired`の履歴として残し、
  新しくは作らない。`bin/check`も検査しない

## まず読む

- [更新履歴](log.md) - 何をなぜ変えたかの日付順の記録

## 運用

- conceptは削除しない。使わなくなったら`status: retired`にして履歴を残す
  （retiredは対象の削除後も残ってよい）
- 状態遷移（draft→active→retired）のgateはuserの発言のみ

## conceptのfrontmatter

共通field（retiredを含め必須。`tags`のみfield自体がoptional）:

| field | 内容 |
|---|---|
| `type` | `Design`（廃止した`Print`はretiredの履歴だけ） |
| `title` | 人間向けの名前 |
| `description` | 1行説明 |
| `status` | `draft` / `active` / `retired`（意味は下記） |
| `tags` | 任意の分類 |

Print固有（廃止。既存のretiredだけが持つ）: `artifact`（対象`.3mf`の
repo rootからの相対path）、`content_sha256`（台帳更新時点の`.3mf`のsha256）。

Design固有:

| field | 内容 |
|---|---|
| `scope` | 対象のassets配下のdirectory（例: `assets/steel-rack/500x400`）。1 design area = 1 scopeで重複させない |

statusの意味: Designは`draft`=思想・対象が調整中 / `active`=現在有効な設計判断 /
`retired`=履歴のみ。**将来構想を含んでいてもactiveのままでよい**（activeは
「完成」ではなく「現在有効な思想」）。

Designの本文はuserの当該発言を`## user 原文 (verbatim)`見出しの下に改変せず
引用で保持し（`bin/check`が見出しの存在を検査する）、整理・解説は別の節に
書く。参照URLは「userが参照した調達先・候補リンク」として保持し、リンク先の
可変な商品情報を確定事実にしない。

## Print（廃止）

- [レターケース ベースプレート（前片・奥片）](prints/letter-case-baseplate.md) - retired。レターケースの引き出しへ敷くGridfinityベースプレート2枚のBambuStudioプロジェクト

## Design

- [クランプ天板のNFCタグ台](designs/nfc-tag-holder.md) - クランプ天板へM8ボルトで留め、沈めた頭ごと天面へΦ25のNFCタグを貼るΦ28×7mmの円柱
- [マグカップホルダー](designs/mug-holder.md) - 内径84.6mm・内高さ32.6mm、ハニカム排水底とクランプ板の回転止め

- [天馬ルームケースプチのGridfinityベースプレート](designs/temna-roomcase-puchi-gridfinity.md) - 浅型引き出しの実測に合わせ、左端数列と奥側R4を持つ前後2枚

- [左右の指配置を分けたレバーレス筐体](designs/leverless-controller.md) - 200mmの天底板を中央前後の柱でつなぎ、横差しナットで固定する
- [LXに固定するUSB充電器ホルダー](designs/lx-usb-charger-holder.md) - LX台座の空きM6穴2個へ固定し、底から電源ケーブルを挿せる上開きのホルダー
- [レターケースのGridfinityベースプレート](designs/letter-case-gridfinity.md) - アイリスオーヤマ A4-LCJへ敷く、左半セル列付き5.5×7セルの前後2分割ベースプレート
- [スチールラック 500x400](designs/steel-rack-500x400.md) - 汎用L字アングルとアクリル天板で安価に組む自作ラック。接合部を3Dプリントで埋め、スライドレール式のPC2台をラックへ収容するまで到達した
- [ゲームデスクのイヤホン・マイク置き](designs/game-desk-earphone-mic-holder.md) - デスククランプの立ち上がり板へ皿ネジ1本で留め、イヤホンケースとピンマイクケースを左右に受ける単一プリント部品
- [天馬用Gridfinityケーブルホルダー](designs/gridfinity-cable-holder.md) - 奥行3/4マス・横5.5マス・9U、10mmピッチの溝へU字仕切り板を差し替える
- [Gridfinity 4U/9U bin（薄いリップ・ラベル棚）](designs/gridfinity-bin-4u.md) - レターケースのベースプレートへ並べる4U/9Uの通常bin66種とgoodsのカードケース。両軸端数は除外。底は穴なし、リップは薄い。12mmラベルシール用の13mm棚は全サイズで奥側
- [簡易クランプの手回しノブ](designs/clamp-hand-knob.md) - 簡易クランプのM8ボルトを工具無しで締められるよう、先端の六角へ噛ませて回す楕円レバーのノブ
