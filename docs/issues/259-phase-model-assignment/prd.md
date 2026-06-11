# PRD: フェーズ別モデル割り当て — impl / review の Sonnet 化の採否と適用範囲

## Problem

全 agent がセッションモデル（Fable）を継承する現行方針（agents/README.md「Model and effort are intentionally unset」）はサブスク枠の消費が大きい。ベンチ（2 Issue × 3 モデル × 10 run = 60 実装 + ジャッジ 76 本、2026-06-10〜11）で impl / review は Sonnet で機能品質同等・コスト約 1/4（Sonnet 1.0 : Opus 2.2 : Fable 4.1）と実証済みだが、方針に未反映でベンチ結果が運用に活きていない。

## Why now

ベンチ完了直後で結果が新鮮。実運用第 1 号（#257/#258 レビュー、227 agents / 約 557 万 subagent tokens）も Sonnet で成功済み。autopilot 本格運用でレビュー Workflow の実行頻度が上がっており、放置するほど枠消費が累積する。

## Outcome

- reviewing-deliverables の Scout〜Verify が `model: 'sonnet'` で実行される（Aggregate のみセッションモデル）
- impl phase の推奨モデル（Sonnet 標準・設計絡みは昇格）が運用ガイダンスとして明文化されている
- agents/README.md のモデルポリシーが新方針 + escalation path 付きで更新されている

## What

採否は以下 3 点を個別判断（Gate ① で人間が指定）:

1. **reviewing-deliverables**: Workflow script の `agent()` に `model: 'sonnet'` を恒久反映（Aggregate のみセッションモデル維持）
2. **autopilot / running-atdd-cycle**: impl phase の推奨モデルガイダンスを明文化（Sonnet 標準、設計絡み Issue はセッションモデルへ昇格）
3. **agents/README.md**: 「intentionally unset」ポリシーを更新し、escalation path（halt / 収束失敗時にセッションモデルへ昇格）をセットで規定

## Non-Goals

- design phase（extracting-user-stories / writing-plan-and-tests）のモデル変更 — ベンチ未実証、設計判断の一貫性は Fable が最良（20/20）だったため
- メインループ（オーケストレータ）のモデル変更 — 対象は subagent のみ
- ベンチの再実行・自動化 — 本 Issue は採否決定と反映のみ

## Open Questions

- What 1〜3 の採用範囲（Gate ① で人間が指定）
- escalation のトリガー定義（何イテレーション FAIL で昇格するか等）→ plan で決定
- ベンチ成果物（/tmp/atdd-bench-issues/ — セッションローカル）の要点を docs に残すか
