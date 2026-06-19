# PRD: flaky-test-fix 専用の軽量ルート

## Problem

現状、flaky テスト（確率的に失敗）専用の対応ルートがない。#308 の bugfix ルート `fixing-bugs` は「決定的な失敗再現テスト（赤→緑）」を前提とするため、再現が確率的な flaky には不適合。flaky は CI を確率的に赤にし続け開発フローを阻害し、フル機能ルート（PRD/US/plan/AT）の重さか手動 skip のその場しのぎに陥る。

## Why now

#308 で bugfix ルートの骨格（thin orchestration・既存スキル再利用・cause-agreement ゲート）が確立し、flaky 特化の差分だけ載せれば作れる土台が揃った。#308 設計承認時に flaky-test-fix ルートは half-scope として本 Issue に defer 済み。full-autopilot 運用で CI green 維持の重要性が増した。

## Outcome

flaky 報告から「**失敗率測定 → 非決定性分類の合意 → 修正 → N/N green 確認**」までの軽量ルートが存在する。bugfix と同じ thin orchestration（既存スキル再利用のみ・新規メソドロジーなし）で flaky 特有の差分のみ専用化される。明示コマンド `/atdd-kit:flaky-fix <issue>` で起動でき、route-eligibility に flaky 信号が載る。

## What

1. **新スキル `skills/fixing-flaky-tests/`**（thin orchestration、既存スキル再利用のみ）:
   - **赤オラクル** = 対象テストを N 回実行し失敗率 k/N を測定（確率的に赤を観測）
   - **中間ゲート（User）= cause-agreement 特化** = 失敗率 + **非決定性カテゴリ**（timing 依存 / test 間 order 依存 / 共有リソース競合 / 外部依存）の合意
   - **条件付き quarantine** = CI ブロッキング時のみ skip/quarantine で green 回復 → 修正 → 隔離解除
   - **緑オラクル** = 修正後 N/N green（失敗率 0）
   - merge = User gate（自動マージしない）
2. `/atdd-kit:flaky-fix <issue>` コマンド新設
3. `docs/methodology/route-eligibility.md` に flaky Route Signals 追記（flaky キーワード / ラベル・No Auto-Routing 不変条件維持）
4. `docs/methodology/autopilot-iron-law.md` の AL-3 coverage 項を flaky 特化（緑オラクル = N/N green）

## Non-Goals

- flaky の自動検出（CI が flaky を検出して起票）は別 Issue
- 既存テストの flaky 一斉棚卸し
- bugfix ルートの再設計（#308 は無改変・再利用のみ）

## Open Questions

1. 赤の固定 → ✅ (a) N 回ループ失敗率測定
2. 中間ゲート → ✅ 非決定性4分類で cause-agreement 特化
3. quarantine → ✅ CI ブロッキング時のみの条件付き第一ステップ
4. **N の既定値・flaky 確定しきい値**（k>0 で確定 or しきい値）、**新スキル独立 vs fixing-bugs モード追加**（推奨: 独立スキル `fixing-flaky-tests`）→ design phase で確定
