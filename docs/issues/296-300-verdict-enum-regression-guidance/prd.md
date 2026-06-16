# PRD: VERDICT_SCHEMA enum 制約化 ＋ regression ピン禁止ガイダンス補完・changelog ヘルパー集約

対象 Issue: **#296**（autopilot review verdict の enum 制約化）/ **#300**（#289 follow-up: running-atdd-cycle ガイダンス追補 ＋ latest_release 抽出ヘルパー集約）

> 2 件はともに小規模・スコープ明確な改善。触れるファイル領域が独立しているため、1 ブランチ・1 PRD・1 Draft PR にまとめて autopilot で収束させる（PR は両 Issue を close）。

## 背景・課題

### #296 — review verdict の自由文字列が偽 stuck halt を生む

`skills/autopilot/SKILL.md` の `VERDICT_SCHEMA.overall_correctness` が `{ type: 'string' }`（自由文字列）。satisfaction oracle は厳密一致 `overall_correctness === 'correct'` で収束判定する。

review agent（モデル）が `overall_correctness` フィールドに `"correct"` ではなく**長文の散文 + XML 風タグ**（`findings` の中身まで流し込まれる）を返すことがあり、厳密一致が成立せず blocking ゼロでも `overall_correctness === 'correct'` だけ永遠に false → 同一状態が続き**偽 stuck halt**になる。別プロジェクト Issue #66 の design phase 実走で発生（2026-06-15）。

**根本原因**: 構造化出力ツール側に enum 制約がなく、prose 混入を防げない。別 PJ では保存済み Workflow スクリプトに enum 制約を適用したところ、再実行で review が正しく `'correct'` を返し一発収束した（**再現と修正の確認済み**）。

### #300 — #289 取りこぼし 2 点（PR #295 が未カバー）

#289（regression AT のバージョン完全一致ピン置換, PR #295 merged）に対し、並行実装 PR #291 が含んでいた 2 点が #295 に取り込まれなかった。

1. **ガイダンス片側のみ**: #289 の PRD/plan は再発防止ガイダンスを `writing-plan-and-tests` と `running-atdd-cycle` の**両スキル**へ追記する指定だったが、#295 は `writing-plan-and-tests/SKILL.md` のみに追加（line 40）。`running-atdd-cycle/SKILL.md` には未追加。
2. **抽出ロジックのインライン重複**: `AT-271.bats`（AT-005）と `AT-284.bats`（AT-010）の双方に「CHANGELOG 最新リリース見出し抽出」を `top=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | tr -d '#[] ')` のインライン重複で実装。AT が増えると同ロジックが散在する。

## ゴール / 非ゴール

**ゴール**
- #296: `overall_correctness` を enum 制約（`['correct','incorrect']`）にし、構造化出力ツール段で prose 混入を排除する。偽 stuck halt を構造的に防ぐ。
- #300-1: `running-atdd-cycle/SKILL.md` の `[regression]` 確立箇所に時点依存ピン禁止ガイダンスを追加。文言は `writing-plan-and-tests/SKILL.md` の既存記述と整合させる。
- #300-2: `tests/acceptance/helpers/changelog.bash` に `changelog_latest_release <changelog_path>` を定義し、AT-271/AT-284 のインライン重複を呼び出しへ置換する。

**非ゴール**
- review agent のプロンプト改修（schema 制約のみで対処、別 Issue）。
- 既存 regression AT のアサーション内容変更（#289/#295 で確立済みの不変条件は維持）。
- AT-271/AT-284 以外の AT への helper 展開（今回は重複している 2 箇所のみ）。

## 受け入れ基準（AC）

### #296
- **AC-296-1**: `skills/autopilot/SKILL.md` の `VERDICT_SCHEMA.overall_correctness` が `enum: ['correct', 'incorrect']` を持つ（grep 可能）。
- **AC-296-2**: enum 制約に整合する形で oracle の厳密一致（`overall_correctness === 'correct'`）が破綻なく動作する（既存の判定ロジックを壊さない）。SKILL.md の構造 pin（行バジェット・schema 構造）を維持する。

### #300-1
- **AC-300-1**: `skills/running-atdd-cycle/SKILL.md` に時点依存ピン禁止ガイダンスが存在する（`[regression]` AT はバージョン等の時点依存値を完全一致でピンしない＝履歴事実＝`## [X.Y.Z]` 見出し存在 ＋ 整合事実＝plugin.json version が CHANGELOG 最新リリース見出しと一致、の 2 アサーションで表現する旨が grep 可能）。
- **AC-300-2**: 文言が `writing-plan-and-tests/SKILL.md` の既存ガイダンスと整合している。

### #300-2
- **AC-300-3**: `tests/acceptance/helpers/changelog.bash` が存在し、`changelog_latest_release <changelog_path>`（`## [Unreleased]` をスキップし先頭の `## [X.Y.Z]` から `X.Y.Z` を取り出す）を定義する。
- **AC-300-4**: AT-271.bats（AT-005）と AT-284.bats（AT-010）に latest_release 抽出のインライン重複が残っていない（helper 呼び出しへ置換済み）。

### 共通（回帰・リリース規約）
- **AC-COM-1**: `bats tests/acceptance/` が fail 0 件で green を維持する（疑似 version bump でも red 化しない）。
- **AC-COM-2**: `.claude-plugin/plugin.json` の version bump ＋ `CHANGELOG.md` に本変更のエントリ（Keep a Changelog 形式）を追加する（DEVELOPMENT.md リリース規約）。

## Outcome（合否基準）

- `bats tests/ tests/acceptance/` 全 green。
- 上記 AC が全て grep / 実行で確認可能。
- review verdict の enum 制約が effc で、偽 stuck halt が構造的に発生しなくなる。
