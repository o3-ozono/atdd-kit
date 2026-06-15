# Acceptance Tests: autopilot / express 経路判定ルーティングステップ（#302）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     検証対象は behavior-shaping code（skills/session-start/SKILL.md）の構造であり、
     bats による構造アサーション（tests/test_session_start_task_recommendation.bats）で検証する。 -->

## AT-001: AC1 — Recommended Tasks に推奨経路列が表示される

- [x] [regression] AT-001: session-start の Recommended Tasks 出力テンプレートに「推奨経路」列が存在する
  - Given: `skills/session-start/SKILL.md` の `### Recommended Tasks` 出力テンプレート
  - When: テンプレートの表ヘッダを読む
  - Then: `Priority | Issue | Reason` に加えて「推奨経路」列が存在し、各推奨 Issue 行に経路を記入する形になっている
  - verify: `bats tests/test_session_start_task_recommendation.bats` の AC1 アサーション（`推奨経路` 列の存在）が green

## AT-002: AC2 — ハイブリッド判定と express/autopilot 信号の定義

- [x] [regression] AT-002: Task Recommendation Rules の Step 3 でハイブリッド判定（決定的ガードレール + LLM 判断）と両信号が定義される
  - Given: `skills/session-start/SKILL.md` の `### Task Recommendation Rules` セクション
  - When: 経路判定ステップ（Step 3）を読む
  - Then: 判定主体がハイブリッド（labels／キーワードの決定的ガードレール + Issue title/body への LLM 判断の併用）であり、express 適格信号（docs/README/typo/コメント/gitignore/version-bump のみで挙動変更なし）と autopilot 信号（コード／挙動変更・新機能・CI/hooks・依存追加・セキュリティ）が express SKILL.md の OK/NG 基準と整合して定義されている
  - verify: AC2 アサーション（Step 3 に express 適格信号・autopilot 信号・labels/keyword/LLM 併用が記述されている）が green

## AT-003: AC3 — 曖昧時は安全側（autopilot）にフォールバック

- [x] [regression] AT-003: 判定が曖昧な Issue は autopilot（フルフロー）にフォールバックすると規定される
  - Given: `### Task Recommendation Rules` の Step 3
  - When: 判定が express/autopilot のどちらとも確定できない曖昧な Issue を想定する
  - Then: 安全側 `autopilot`（フルフロー）に倒すフォールバック方針が明記され、express の "when in doubt, full flow" と一致する
  - verify: AC3 アサーション（曖昧時 → autopilot のフォールバック文言）が green

## AT-004: AC4 — 推奨のみ・auto-route しない（不変条件）

- [x] [regression] AT-004: 推奨経路はあくまで推奨であり auto-route されず、ユーザーが最終選択する
  - Given: `### Task Recommendation Rules` の Step 3
  - When: 経路推奨の拘束力を確認する
  - Then: 自動実行（auto-route）しない不変条件が明記され、ユーザーが最終的に経路を選択する旨が記述されている
  - verify: AC4 アサーション（「推奨のみ」「auto-route しない／自動実行しない」不変条件）が green

## AT-005: AC5 — express の既存トリガが温存される

- [x] [regression] AT-005: express の明示起動 + APPROVAL-GATE + scope-overflow + CI ゲートが変更されずに存続する
  - Given: `skills/express/SKILL.md`
  - When: 本 Issue の変更後に express のトリガ・ゲート群を確認する
  - Then: APPROVAL-GATE、scope-overflow abort、OK/NG 基準が存続し、推奨レイヤの追加によって退行・置換されていない
  - verify: AC5 アサーション（express SKILL.md に `APPROVAL-GATE` と scope-overflow 相当が残存）が green

## AT-006: AC6 — Skill Changes Require Test Evidence + autopilot SKILL.md 不変

- [x] [regression] AT-006: 推奨経路の構造アサーションが追加され既存スイートが green を維持し、autopilot SKILL.md は変更されない
  - Given: `tests/test_session_start_task_recommendation.bats` と本 PR の diff
  - When: bats スイートを実行し、変更ファイル一覧を確認する
  - Then: 推奨経路の構造アサーション（AC1-AC5）が追加され、session-start 関連 bats 群が全 green を維持し、`skills/autopilot/SKILL.md` は変更されていない（descope 遵守）
  - verify: session-start 関連 bats が全 green かつ `git diff --name-only origin/main` に `skills/autopilot/SKILL.md` が含まれない

## AT-007: AC7 — version bump + CHANGELOG 整合（リグレッション不変条件）

- [x] [regression] AT-007: plugin.json の version が CHANGELOG 最上位リリース見出しと一致する
  - Given: `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: `scripts/check-plugin-version.sh` 相当の整合チェックを実行する
  - Then: plugin.json の version が CHANGELOG の最上位（最新）リリース見出しと一致する（点固定値ではなく不変条件を検証 — #289: literal version pin は次回 bump で regression を恒久 red 化する）
  - verify: plugin.json version == CHANGELOG 最新見出し version、かつ `scripts/check-plugin-version.sh` が PASS（特定バージョン文字列を exact-pin しない）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
