# Common Principles — 要件抽出の共通原則

> **Loaded by:** `defining-requirements`, `batch-discovery` (via mapping references in each skill's SKILL.md)

4 技法（[pre-mortem](pre-mortem.md) / [job-story](job-story.md) / [one-question-at-a-time](one-question-at-a-time.md) / [out-of-scope-question](out-of-scope-question.md)）に横断する運用原則。個別の技法一次情報には含まれない、このカタログ独自の整理であるため全項目に `[独自整理]` を付す。

## 1. 対話のキャッチボールで埋める `[独自整理]`

テンプレの穴埋めではなく、1 回の返答から次の問いを組み立てる。相手の回答を受けて掘り下げる／別角度から確認する／次の節へ移るかを、その場で判断する。事前に全質問を並べて一括提示しない。

## 2. 上位工程の責務を侵さない `[独自整理]`

この技法群は要件抽出（Discovery）フェーズの対話補助に限定される。Acceptance Criteria の確定・設計ドキュメントの作成・テスト計画の策定は、この技法群の出口ではない。技法を使って得た回答は PRD / User Stories の該当節に落とし込み、後続工程（`writing-plan-and-tests` 等）の入力として引き渡す。

## 3. 対話ログを残す `[独自整理]`

各節を埋めた根拠を後追いできるよう、節の区切りで要点を確認する（例: 「この節は〜という理解で次に進みます」）。合意した内容を PRD/US の該当セクションに反映し、後から「なぜこの記述になったか」を辿れる状態を保つ。

## 関連ドキュメント

- [README.md](README.md) — カタログ全体の一覧
- [pre-mortem.md](pre-mortem.md)
- [job-story.md](job-story.md)
- [one-question-at-a-time.md](one-question-at-a-time.md)
- [out-of-scope-question.md](out-of-scope-question.md)
