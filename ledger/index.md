---
okf_version: "0.2"
---

# 3D print ledger

`print/`のBambuStudioプロジェクト（`.3mf`）の台帳。`.3mf`はzipバイナリで
Gitのdiffが読めないため、意味・状態・経緯はここが正本として持つ。
1つの`.3mf`につき1つのconcept（`prints/<slug>.md`）を対応させ、frontmatterの
`artifact`（repo rootからの相対path）と`content_sha256`で対象を固定する。

## まず読む

- [更新履歴](log.md) - 何をなぜ変えたかの日付順の記録

## 運用

- Windows（BambuStudio）は`\\<サーバー>\3dp-3mf`へ`.3mf`を保存する
- 保存直後は`bin/check`が「台帳未登録」で赤くなるのが意図した状態。会話で
  concept作成・`content_sha256`採取・`log.md`追記まで済ませるとgreenになる
- conceptは削除しない。使わなくなったら`status: retired`にして履歴を残す
  （retiredは`.3mf`削除後も残ってよい）
- 状態遷移（draft→active→retired）のgateはuserの発言のみ

## conceptのfrontmatter

| field | 内容 |
|---|---|
| `type` | `Print`固定 |
| `title` | 人間向けの名前 |
| `description` | 1行説明 |
| `status` | `draft`（調整中）/ `active`（現役）/ `retired`（引退） |
| `tags` | 任意の分類（field自体もoptional。他はretiredを含め必須） |
| `artifact` | 対象`.3mf`のrepo rootからの相対path（例: `print/hinge.3mf`） |
| `content_sha256` | 台帳更新時点の`.3mf`のsha256（`sha256sum`で採取） |

印刷条件（プリンタ・フィラメント・ノズル等）は`.3mf`自体が保持するため
frontmatterには持たない。経緯・調整メモ・印刷結果は本文に自由に書く。

## Print

（まだ無い）
