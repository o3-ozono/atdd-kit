# PRD: atdd-kit 開発フロー完了時の自動振り返り（メトリクス + フィードバック抽出）

## Problem

6-step / autopilot を 1 Issue 完了するたびの振り返りが人手のみで、定量データ（トークン・対話量）や前回比が残らない。「重かったか / どこで詰まったか」を機械的に把握・蓄積できていない。

## Why now

autopilot / full-autopilot 運用で定量把握とコスト管理の必要性が増加。振り返りで挙がった改善点を skill-fix へつなぐフィードバックループの源にしたい。

## Outcome

Issue 完了時に振り返りレポート（メトリクス + フィードバック候補）が自動生成され、前回比較が横断ログに残る。

## What

- **トリガー（論点6）**: merge gate 後（`merging-and-deploying` 末尾）に**既定 ON・軽量**で実行、**express はスキップ**。
- **メトリクス**:
  - 対話量（ターン数・フェーズ別内訳）
  - コスト（トークン input/output/合計、**harness 提供値を一次ソース**＝Workflow `subagent_tokens` / headless `total_cost_usd` / `autopilot-log.jsonl`、論点1）
  - 前回比（**直近マージ PR**、論点2 ／ **diff 行数**正規化、論点3 ／ docs 主体 vs code 主体は注記）
  - 摩擦点（autopilot の **gate rejection / `rejectionFindings` / `implSeedFindings`** 起点、論点4 ／ 手動 flow は best-effort）
  - 改善（**skill-fix 候補をサマリ列挙**＝自動起票しない、論点5）
- **アウトプット**: `docs/issues/<NNN>-*/retrospective.md`（Issue ローカル）＋ 横断集計 JSONL（前回比較用）＋ ターミナル/Issue/PR 同期。

## Non-Goals

- トークンの完全精密計測（harness 近似許容・#312 feasibility と同根）
- skill-fix 自動起票（候補提示まで・No Auto-Routing 哲学）
- 手動 flow の指摘自動抽出（best-effort）

## Open Questions

論点 1〜6 すべて壁打ちで確定（1=harness値 / 2=直近マージPR / 3=diff行数 / 4=autopilot構造化データ起点 / 5=サマリ列挙 / 6=既定ON軽量・expressスキップ）。実装方式（集計スクリプトの配置・retrospective テンプレート）は design phase で確定。
