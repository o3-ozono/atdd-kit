# investigation: セッション統計（skill/agent/command 発行回数）の収集価値を検討する

| Field | Value |
|-------|-------|
| Issue | #31 |
| PR | #47 |
| Date | 2026-04-13 |
| Status | Completed |

## Background

atdd-kit のワークフロー改善とボトルネック特定に向けて、1 セッションあたりの skill / agent / command 発行統計を収集する仕組みに価値があるかを評価する必要があった。特に「定義済みだが使われていない役割（例: PO エージェント #45）」の稼働実績を統計で検出できるかが関心事だった。一方で、収集コスト・プライバシー・保守負荷とのバランスを見極める必要があり、安易な実装着手はリスクを伴う。本 Issue は「やる / やらない / 段階的導入」の判断根拠を提示するための investigation タスクとして起票された。

## Discussion Summary

### 調査アプローチ選定

| Approach | Summary | Verdict |
|----------|---------|---------|
| A: デスクリサーチ中心 | 既存 Claude Code 機能のマッピングと定性評価のみ | ❌ 却下 — 実測なしでは収集オーバーヘッドの評価が推論ベースに留まる |
| B: 最小プロトタイプ検証 | 1〜2 hooks の使い捨て PoC で実測 + デスクリサーチ併用 | ✅ 採用 — 実測値で信頼度を担保。PoC は測定専用の使い捨てとしクリーンアップ |
| C: 他ツール比較分析 | 類似 coding agent の observability を調査 | ❌ 却下 — 汎用結論に留まり atdd-kit 固有の判断に直結しにくい |

### 最終判断（収集方式）

| Approach | Summary | Verdict |
|----------|---------|---------|
| やらない | 統計収集を導入しない | ❌ 却下 — Phase 1 の低コストに対する機会損失の正当化が弱い |
| やる（フル実装） | OTel / 全ツール Hooks リアルタイム / prompt 収集をすべて導入 | ❌ 却下 — zero-dependencies 違反、オーバーヘッド過大、プライバシー HIGH |
| 段階的導入 | Phase 1 のみ即実施、Phase 2 以降は Go/No-Go 評価後 | ✅ 採用 — 低コスト Phase 1 で価値を先に検証してから投資拡大 |

### 却下した収集手段

| 選択肢 | 却下理由 |
|--------|---------|
| OTel フル導入 | zero-dependencies 制約違反。外部 Collector（Prometheus/ClickHouse 等）構築が個人開発規模では過剰 |
| Hooks 全ツールリアルタイム収集 | プロセス起動コストが支配的（macOS: ~7.5ms/event）、1000 events で ~15 秒累計 |
| UserPromptSubmit での prompt 収集 | プライバシー HIGH。ユーザー要件・設計案・個人情報を含む可能性 |
| フル実装一括 | Phase 2/3 の価値が現時点では未検証 |

## User Story

本タスクは investigation のため User Story は不要（Research Flow は DoD + Scope のみ起案）。

## Acceptance Criteria

Research タスクのため AC ではなく DoD（Definition of Done）で完了条件を規定:

- [x] 収集候補メトリクスのリストを整理（skill 発火回数、agent 生成数、command 使用頻度、セッション時間、tool 呼び出し分布など）
- [x] 収集方法の選択肢（hooks / session transcripts / 外部スクリプト / 既存ログ解析）ごとに Pros/Cons と実現可能性を整理
- [x] 最小 PoC で 1〜2 メトリクスを実測（hook 経由で skill/tool イベントを JSONL 記録）し、オーバーヘッド（実行時間影響・ログサイズ）を定量記録
- [x] プライバシー（収集データに含まれる可能性のある機密情報）と保守負荷の評価を記載
- [x] 「やる / やらない / 段階的導入」の最終判断と根拠を Issue コメントに記載
- [x] 「定義済みだが未稼働の役割（例: PO エージェント #45）」を統計で検出可能かの検討結果を記載
- [x] PoC 用の一時ファイル・ブランチは本 Issue PR に含めず、測定結果のみ投稿（クリーンアップ）

## Implementation Plan

### テーマ分割（Researcher × 4）

| Theme | Researcher | 担当領域 |
|-------|-----------|---------|
| A | A1 | メトリクス分類 + 収集手段（hooks / transcripts / logs / 外部スクリプト）優先度評価 |
| A | A2 | プライバシー・保守負荷・未稼働役割検出可能性の設計論考察 |
| B | B1 | 1〜2 hooks の使い捨て PoC 構築 + オーバーヘッド実測 |
| B | B2 | A1 / A2 / B1 の成果を統合し最終判断を執筆 |

### 各成果物の配置

- `docs/decisions/research-a1-metrics-and-mechanisms.md`
- `docs/decisions/research-a2-privacy-maintenance-detection.md`
- `docs/decisions/research-b1-poc-measurement.md`
- `docs/decisions/research-b2-final-judgment.md`

### 採用した段階的導入ロードマップ

**Phase 1（即実施推奨）:** Stop フック + `scripts/analyze-session.py` による最小収集
- 対象メトリクス: skill 発火回数、agent 生成数、command 使用頻度、セッション時間、tool 分布
- 収集フィールドは最小セット（`schema_version`, `session_id`, `hook_event_name`, `timestamp`, `tool_name`, `agent_type`）
- 保存先: `$XDG_CACHE_HOME/atdd-kit/stats/` の JSONL
- プライバシー制御: `tool_input` / `prompt` / `transcript_path` 本文は収集しない
- 工数見積: 1〜2 日

**Phase 2（Phase 1 Go 後）:** 月次レポート + ログローテーション + opt-out（`workflow-config.yml` の `telemetry: false`）

**Phase 3（Phase 2 Go 後、条件付き）:** SubagentStart/Stop リアルタイム記録、GitHub API 相関分析

### 実測ベースライン（B1）

| 指標 | 実測値 | 備考 |
|------|-------|------|
| 1 event 実行時間 | ~16 ms（macOS, n=1000 平均 15.3 ms） | Linux 環境では 8-12ms/event と推定 |
| 1 event ログサイズ | ~94 bytes | ツール種別によらずほぼ一定 |
| 1000 events 累計 | ~15 秒 / ~92 KB | LLM 推論時間（~3 秒/ターン）に対し ~0.5% |

### Issue #45 との切り分け

Issue #45（PO エージェント稼働確認）は統計収集の必要条件ではない。Research A2 §3.4 の静的解析結論（PO は `commands/autopilot.md` からのみ参照、skills/ からの呼び出しなし）により即時解決可能。本投資判断から切り離して独立に処理する。

## Changes

mid-course 変更なし。調査アプローチは A → B への変更があった（当初推奨 A だったが、ユーザーが実測重視で B を選択）。これは正規の Approach Exploration 承認プロセス内での選択であり、方針転換ではない。

## Next Actions（本 Issue 完了後の推奨タスク）

- Phase 1 実装（別 Issue で起票）: `hooks/session-stats` + `scripts/analyze-session.py`
- Issue #45 の静的解析ベース解決（Research A2 §3.4 / B2 §5 の結論に基づく）
