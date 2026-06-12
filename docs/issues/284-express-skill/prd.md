# PRD: express skill の再導入 — 機能破壊リスクのないドキュメント級タスクの省略経路

## Problem

**現状:** v1.0 構造再設計（#179 / PR #237）で旧 express mode（#94 / PR #96）が旧 skill 群とともに廃止され、現行 v3.x には軽量経路が存在しない。README 追記・typo 修正・コメント補足・gitignore 追加のようなドキュメント級の変更でも、PRD → User Stories → plan + AT → 構造化レビュー（reviewing-deliverables）のフルチェーンが必須になっている。

**それによって何が困るか:** 機能的な破壊が考えられない trivial な変更に対して、フルフローのオーバーヘッド（複数設計文書の作成・レビュー往復・AT 整備）を毎回支払うことになる。直近では stockbot-jp の Issue（README に資格情報引き継ぎ手順を 1 節追記するだけの docs タスク）でこの過剰さが顕在化した。

## Why now

- 痛みが実例として顕在化済み（stockbot-jp の docs タスク）。軽量経路の不在は今後も docs 級 Issue のたびに発生し続ける機会コスト。
- 旧 #94 で確定した AC 資産と `express-mode` ラベルが現存しており、引き継ぎコストが低い今が再導入の好機。
- v1.0 の capability-name skill 体系（#179）が安定してきたため、旧実装の轍を踏まずに新体系へ整合する形で再設計できる。

## Outcome

完了時に達成されている状態:

- `/atdd-kit:express <issue>` コマンドで、Issue → 実装 → CI → merge の最短経路が実行できる。
- Issue #284 の AC1〜AC9 がすべて満たされている:
  - AC1: 発動はユーザの明示的承認が必須（implicit fallback 禁止）
  - AC2: 適用基準（OK 例 / NG 例 / 迷ったらフルフロー）が文書化されている
  - AC3: Issue 駆動ルール維持（Issue なしでは起動エラー）
  - AC4: CI ゲートは省略されない（CI FAIL なら merge 不可）
  - AC5: PR で express 利用が識別可能（`express-mode` ラベル + PR body 固定セクション）
  - AC6: express を選択した理由（適用基準のどれに該当するか）が PR に記録される
  - AC7: DEVELOPMENT.md ルール（version bump + CHANGELOG）は省略されない
  - AC8: skill-gate が express 経路を正規ルートとして認識しブロックしない
  - AC9: スコープ逸脱時（diff が適用基準を超えた場合）に express を中断しフルフローへ切り替え、利用者に報告する
- ドキュメント級タスクで設計文書（PRD/US/plan/design-doc）と構造化レビューを省略しつつ、Issue 駆動 + CI ゲートという最低限のガバナンスは維持される。

**測定可能な指標:** express 経路で作られた PR には `express-mode` ラベルと理由セクションが必ず付与され、事後監査・traceability が成立する（AC5/AC6）。skill-gate が express 経路をブロックしない（AC8）。

## What

- `skills/express/SKILL.md` の新設（v1.0 capability-name 体系に整合）
- `/atdd-kit:express <issue>` コマンドの追加
- 適用基準の文書化（AC2）— OK 例: docs/README 追記・typo・コメント・gitignore・バージョン bump のみ等 / NG 例: 新機能・振る舞い変更・依存追加・CI/hooks 変更・セキュリティ影響あり等 / 判定に迷う場合はフルフローへフォールバック
- 発動ゲート: ユーザの明示的承認必須（AC1）、対象 Issue 必須（AC3）
- ガバナンス維持: CI ゲート（AC4）、`express-mode` ラベル + PR body 固定セクション（AC5）、選択理由の記録（AC6）、version bump + CHANGELOG（AC7）
- skill-gate 統合: express 経路を正規ルートとして認識させる（AC8）
- スコープ逸脱フォールバック: 実装中に diff が適用基準を超えたら express を中断しフルフローへ切り替えて報告（AC9）
- 付帯整備: BATS テスト（`tests/test_express_skill.bats`）、`skills/README.md` / `commands/README.md` 更新、CHANGELOG エントリ + minor version bump（新 skill 追加 = minor、DEVELOPMENT.md 準拠）

## Non-Goals

- **merge の自動化はしない** — merge は常に人間ゲート。express は「レビュー省略経路」であって「人間排除経路」ではない。
- **CI の省略はしない** — AC4 の通り「レビュー省略」と「CI 省略」は別物。CI はガバナンスの最後の砦として維持する。
- **フルフロー skill 群（6-step）の変更はしない** — express は追加の省略経路であり、既存の defining-requirements 〜 merging-and-deploying を書き換えない。
- **コード変更への適用拡大はしない** — 適用基準の NG 例（新機能・振る舞い変更・依存追加・CI/hooks 変更等）は明示的にスコープ外。迷ったらフルフロー。
- **keyword 検出による implicit 自動発動はしない** — AC1 により Claude の独断開始は禁止。

## Open Questions

- **発動形態の詳細:** コマンド起動（`/atdd-kit:express <issue>`）のみとするか、keyword 検出 + 確認プロンプトによる「提案」（ユーザが Y/n で承認）まで許すか。AC1 が禁止するのは独断開始であり、確認付き提案の可否は plan で確定する。
- **skill-gate 統合のメカニズム:** skill-gate 側の SKILL.md を編集して express を認識させるか、express skill 側の宣言で済ませられるか（AC8 の実現方式）。plan で確定する。
- **旧 PR #96 実装の再利用度合い:** 旧 express の構造をどこまで流用するか。v1.0 体系との差分を踏まえ extracting-user-stories / writing-plan-and-tests で確定する。
