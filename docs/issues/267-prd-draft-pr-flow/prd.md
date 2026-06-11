# PRD: 成果物提示を Draft PR ベースに統一 — workflow-detail.md のレガシー記述矛盾と defining-requirements の承認後書き込み順序の修正

## Problem

Gate ①（要件確定）で PRD ドラフトが Issue コメント + ターミナル長文として提示され、レビューしづらい（ユーザー指摘 2 回目）。「成果物はブランチにコミット → 即 Draft PR」は `rules/atdd-kit.md` の既存 3 規定（Workflow 表の成果物パス / commit moment = Draft PR moment / 1 Issue = 1 worktree = 1 Draft PR）から導出可能なのに再発する。原因は 2 点:

1. **レガシー記述の矛盾**: `docs/workflow/workflow-detail.md` Execution Mode 節に「Deliverables flow through Issue / PR comments via `gh issue comment` / `gh pr comment` — never written to ad-hoc repository paths」という v1.0 移行前の記述が残存し、Workflow 表と矛盾。セッションがこちらに従うと Issue コメント提示になる
2. **承認後書き込みの順序欠陥**: `skills/defining-requirements/SKILL.md` Flow が「会話内提示 → 'ok' → 承認後に `prd.md` を書く」順序のため、ドラフト段階の成果物が PR に載る経路が存在しない

## Why now

autopilot 運用（#262/#261/#259 で 3 件同時実行中）により Gate ①/② の成果物提示頻度が急増しており、提示チャネルの揺れがそのままレビュー体験の劣化として毎回再生産される。同一指摘が 2 回発生した時点で、セッション判断ではなくルール・スキルへの固定が必要。

## Outcome

- PRD ドラフトが承認前に作業ブランチへコミット・push され、Draft PR の差分としてレビューできる
- `docs/workflow/workflow-detail.md` と `rules/atdd-kit.md` の成果物提示規定に矛盾がない
- autopilot Gate ②（設計承認）の成果物提示も PR 差分ベースであることが明文化されている
- ターミナルには PR リンク + 判断が必要な点のみが提示される（全文展開しない）

## What

- `docs/workflow/workflow-detail.md` のレガシー行を削除し、Workflow 表と整合する記述（成果物はブランチコミット + Draft PR、状態通知のみ Issue/PR コメント）へ置換
- `skills/defining-requirements/SKILL.md` Flow の順序を「draft 書き込み → commit/push → Draft PR 作成 → 承認ゲート（PR 上）」に変更
- `skills/autopilot/SKILL.md` Dialog economy 節に提示チャネル規定（Gate ①/② とも PR 差分ベース + ターミナルは要点のみ）を追記
- 影響する BATS pin の更新・追加（DEVELOPMENT.md「Skill Changes Require Test Evidence」準拠）

## Non-Goals

- `rules/atdd-kit.md` への新規定追加 — 既存 3 規定で導出可能なため不要（60 行予算も考慮）
- reviewing-deliverables / merging-and-deploying の提示チャネル変更 — レビュー結果・マージは既に PR ベース
- 全チャネル内容同期ルール（プロジェクト側 workflow-overrides.md）の変更 — 「同じ内容を両方に表示」は維持し、成果物本体の置き場所のみ規定

## Open Questions

- defining-requirements の Flow 順序変更は非 autopilot（通常フロー）にも適用するか、autopilot 時のみのオーバーライドにするか → plan で決定（推奨: 通常フローにも適用 — commit moment = Draft PR moment はモード非依存のため）
