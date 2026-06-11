# Acceptance Tests: Skill E2E テストの claude 起動に --model sonnet を指定 — モデル未指定によるトークン過大消費の解消

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [regression] / [draft] / [regression] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-001: 全 E2E ファイルの claude 起動が明示的にモデルを指定する（US-1）

- [ ] [regression] AT-001: `tests/e2e/*.bats` 全 11 ファイルの `_run_claude` が `--model "${E2E_MODEL}"` を渡す
  - Given: `tests/e2e/*.bats` 全 11 ファイル（autopilot / bug / debugging / defining-requirements / extracting-user-stories / launching-preview / merging-and-deploying / reviewing-deliverables / running-atdd-cycle / writing-design-doc / writing-plan-and-tests）
  - When: 各ファイルの `_run_claude` の `claude -p` 起動行を検査する（`grep -c -- '--model "${E2E_MODEL}"' tests/e2e/*.bats`）
  - Then: 全 11 ファイルで `--model "${E2E_MODEL}"` が `claude -p` 起動に付与されており、モデル未指定の起動が 1 件も存在しない

## AT-002: 環境変数でモデルを上書きできる・未設定時は sonnet（US-2）

- [ ] [regression] AT-002: `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"` 定義により上書き可能・デフォルト sonnet
  - Given: 各 e2e ファイルの冒頭設定部
  - When: モデル変数の定義を検査する（`grep -F 'E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"' tests/e2e/*.bats`）
  - Then: 全 11 ファイルが `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"` を定義しており、`SKILL_E2E_MODEL` 未設定時は `sonnet`、設定時はその値が `--model` に渡る（bats ファイルの書き換えなしに任意モデルで実行できる）

## AT-003: モデル指定漏れを回帰 pin が検出する（US-3）

- [ ] [regression] AT-003: 構造検証テストが「全 e2e ファイルの `--model` 指定」を機械検証する
  - Given: `tests/test_skill_test_coverage.bats` に追加された回帰 pin（glob ベースで `tests/e2e/*.bats` 全ファイルを対象とし、新規ファイルも自動的に検査範囲に入る）
  - When: 任意の 1 ファイルから `--model "${E2E_MODEL}"` 行または `E2E_MODEL=` 定義を一時的に除去して `bats tests/test_skill_test_coverage.bats` を実行する
  - Then: 該当 pin が FAIL して対象ファイルを報告する。復元後は suite 全体が green に戻る（巻き戻り・新規ファイルのモデル未指定が機械的に検出される）

## AT-004: モデルポリシーが README に記載されている（US-4）

- [ ] [regression] AT-004: `tests/README.md` の Skill E2E Tests 節がデフォルトモデルと上書き方法を伝える
  - Given: `tests/README.md` の `## Skill E2E Tests (tests/e2e/)` 節
  - When: モデルポリシーの記述を検査する（`grep -n 'SKILL_E2E_MODEL' tests/README.md`）
  - Then: デフォルトモデルが **sonnet** であること、`SKILL_E2E_MODEL` 環境変数で上書きできることが同節から読み取れる

## AT-005: 全 timeout 分岐でモデル指定が一貫している（CS-1）

- [ ] [regression] AT-005: `timeout` / `gtimeout` / フォールバックの 3 分岐すべてに同一フラグが付与される
  - Given: 各 e2e ファイルの `_run_claude`（3 分岐構造）
  - When: 分岐ごとの `--model` 出現を検査する（`grep -c -- '--model "${E2E_MODEL}"' tests/e2e/*.bats` および各ファイルの `"$CLAUDE_BIN" -p` 起動行数との一致確認）
  - Then: 全 11 ファイルで出現数が 3（= `claude -p` 起動行数と一致）であり、GNU coreutils の有無などどの分岐を通っても同じモデルで実行される

## AT-006: 既存の環境変数規約に整合している（CS-2）

- [ ] [regression] AT-006: モデル設定が `TIMEOUT_SECS` と同じ命名規約・同じ上書き方式・同じ配置で定義される
  - Given: 各 e2e ファイルの冒頭設定部（`TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}"`）
  - When: `E2E_MODEL` 定義の形式と配置を検査する（`grep -A1 'TIMEOUT_SECS=' tests/e2e/*.bats`）
  - Then: 全 11 ファイルで `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"` が `SKILL_E2E_` プレフィックス + `:-` デフォルト方式（既存規約と同形）で、`TIMEOUT_SECS` 行の直後に定義されている

## AT-007: リリース規律 — CHANGELOG + patch bump

- [ ] [regression] AT-007: テストハーネス変更でも CHANGELOG 更新と patch version bump を伴う
  - Given: 本 Issue の変更を含む Draft PR の diff
  - When: `CHANGELOG.md` と `.claude-plugin/plugin.json` を検査する（`bats tests/test_changelog_format.bats` / `scripts/check-plugin-version.sh`）
  - Then: CHANGELOG.md に `[3.11.4]` の `### Fixed` エントリ（#278 参照付き）が存在し、plugin.json の `version` が `3.11.4`（3.11.3 からの patch bump）で CHANGELOG 最新エントリと一致する

## AT-008: 変更スコープが Non-Goals を侵食しない

- [ ] [regression] AT-008: ハーネス共通化・fixtures・実行スクリプトに変更が波及していない
  - Given: 作業ブランチと main の差分（`git diff main --name-only`）
  - When: 変更ファイル一覧を検査する
  - Then: 変更が `tests/e2e/*.bats` / `tests/test_skill_test_coverage.bats` / `tests/acceptance/AT-278.bats` / `tests/README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` / `docs/issues/278-*` に限定され、`tests/fixtures/headless/` / `scripts/run-skill-e2e.sh` / `docs/guides/headless-skill-testing.md` に変更がない（`_run_claude` の共通ファイル化は行われていない）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [regression] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [regression] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
