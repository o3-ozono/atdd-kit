# Workflow Overrides

## plan のユーザー承認は不要

discover でユーザーが設計（AC セット）を承認済みのため、plan の承認は Reviewer の技術チェック（R1-R6）で十分。

- Reviewer PASS → `ready-to-go` 直行
- `ready-for-user-approval` ステップを経由しない
- ユーザーは差し戻し権を保持（`ready-to-go` → `needs-plan-revision` に戻せる）
- plan スキルの Step 7 で承認依頼セクションは出さない

## 全チャネル内容同期

Issue コメント・承認依頼・レビュー結果など、人間が判断に使う情報を投稿するときは、ターミナルと GitHub の両方に同じ内容を表示する。

- GitHub に `gh issue comment` で投稿した内容は、ターミナルにも同じマークダウンを出力する
- どこで見ても同じ反応・思考ができる状態にする
