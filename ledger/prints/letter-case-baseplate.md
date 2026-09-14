---
type: Print
title: レターケース ベースプレート（前片・奥片）
description: レターケースの引き出しへ敷くGridfinityベースプレート2枚のBambuStudioプロジェクト。試作の合わせ込み中
status: draft
tags: [gridfinity, letter-case, baseplate]
artifact: print/letter-case/baseplate.3mf
content_sha256: b70a8bad3f634b925f4ac0ab972e854ec2ba2cb2b9bbb1975a8a41c6b4d2a8fe
---

# レターケース ベースプレート（前片・奥片）

設計は[レターケースのGridfinityベースプレート](../designs/letter-case-gridfinity.md)
が正本。このprojectは2プレート構成で、プレート1が`baseplate_rear.stl`、
プレート2が`baseplate_front.stl`（各1個）。

## 経緯

- 2026-08-26 12:21 保存。中身は試作1回目の合わせ込み（手前−1.5、左右+1.5、
  奥角R6。板幅241）を反映したSTLで、これが試作2回目のプリントになった。
  結果（中央はカタつき、前後の端で左右が当たる）を受けて、設計は左右を各0.2
  削った240.6へ進んでいる。この`.3mf`はその変更より前のSTLを持つので、
  次に刷るときは`dist/letter-case/iris-oyama-a4-lcj/`の最新STLへ差し替えて保存し直す
- 2026-08-27 保存し直し（sha256更新）。設計側は板240.6×315.5・ソケット+0.1
  （commit `7c2e81a`）まで進んでいる。`.3mf`の中身がどの版のSTLかは`.3mf`
  自体からは読めないので、userの保存時点の`dist/`（同commit以降）と推定
