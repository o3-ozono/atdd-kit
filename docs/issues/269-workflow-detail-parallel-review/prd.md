# PRD: workflow-detail.md のレビュー記述を #234 の動的・並列 Workflow パネルへ整合

## Problem

`docs/workflow/workflow-detail.md` に、#234 で置換済みの旧レビュー機構（固定 5 specialist reviewer を**直列** spawn → final aggregator が 47 基準を集約）を前提とした記述が残存しており、現行実装と矛盾する。

1. **Execution Mode 節（line 46）**: 「**Review step** (`reviewing-deliverables`, Step 5) spawns specialist reviewer subagents (PRD, User Story, Plan, Code, Acceptance Test) **serially**, then a final aggregator returns a single PASS/FAIL.」— #234 でレビューは Scout → 動的パネル生成 → **並列**レビュー（Workflow tool の `parallel()` / `pipeline()`）→ adversarial 検証 → Aggregate に移行済み
2. **Reviewer Aggregation Flow 節（lines 97–120）**: 固定 5 reviewer（prd/us/plan/code/at、括弧内は基準数）→ `final-reviewer: aggregate 47 criteria` という mermaid 図が、同じ旧機構をそのまま描いている

`workflow-detail.md` は session-start がロードする参照ドキュメントであり、セッションが旧記述に従うと「固定 6 reviewer を直列 spawn する」誤った実行像で Step 5 を理解する。#267 で実証済みのとおり、レガシー記述の残存はセッション挙動の揺れとして毎回再生産される。

## Why now

#267（成果物提示の Draft PR 統一）の design phase レビューで発見され、#267 のスコープ外（PRD Non-Goals）として切り出された繰り越し分。autopilot 運用下で Step 5（`reviewing-deliverables`）の呼び出し頻度が増えており、現行実装と矛盾する参照ドキュメントを放置するとレビュー実行像の誤誘導が累積する。

## Outcome

- `docs/workflow/workflow-detail.md` のレビュー機構記述が `skills/reviewing-deliverables/SKILL.md`（#234 実装）と矛盾しない
- Execution Mode 節・Reviewer Aggregation Flow 節のいずれを読んでも「動的パネル・並列実行・adversarial 検証・Aggregate 集約」という現行アーキテクチャが正しく伝わる
- 同ドキュメント内に旧機構（固定 roster / serial / 47 基準）を前提とする記述が残っていない

## What

- Execution Mode 節 line 46 を、#234 実装（Scout → 動的レンズパネル生成 → 並列レビュー → adversarial 検証 → Aggregate が単一 PASS/FAIL + 観点別ノートを返す）と整合する記述へ置換
- Reviewer Aggregation Flow 節（mermaid 図 + 導入文）を現行の Workflow フェーズ構成（Scout / Generate / Review / Verify / Aggregate）を描く図へ置換
- Execution Mode 節を通読し、その他のレガシー記述の残存を確認・修正（Issue 対応案のとおり）
- ドキュメントのみの変更だが、CHANGELOG.md 更新 + `.claude-plugin/plugin.json` の patch version bump（DEVELOPMENT.md Versioning 準拠）

## Non-Goals

- `agents/README.md` Usage 節および `agents/*.md` の「固定 5 specialist reviewer」前提記述の整理 — #234 Out of Scope（固定 reviewer agents の扱い: 削除 or 流用）が未消化のまま残っており、ファイル群の存廃判断を伴うため別 Issue で扱う
- `skills/reviewing-deliverables/SKILL.md` 本体の変更 — 現行実装が正であり、本 Issue はドキュメント側を実装へ整合させるのみ
- Quality Score / Guardrails 節など Execution Mode 節・Reviewer Aggregation Flow 節以外の workflow-detail.md 記述の見直し — Issue スコープ外

## Open Questions

1. **Reviewer Aggregation Flow 節をスコープに含めるか** — Issue 本文が明示するのは Execution Mode 節 line 46 だが、Reviewer Aggregation Flow 節は同一の旧機構を mermaid 図で描いており、line 46 のみ直すとドキュメント内矛盾が残る。本 PRD は「含める」を提案（推奨）。
2. **agents/ 配下のレガシー記述の扱い** — 本 PRD は Non-Goals（別 Issue 化）を提案。承認時に別 Issue を起票するかの判断を求める。
