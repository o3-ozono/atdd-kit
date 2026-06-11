# Plan: Skill E2E テストの claude 起動に --model sonnet を指定 — モデル未指定によるトークン過大消費の解消

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 前提

- 変更対象は `tests/e2e/*.bats`（全 11 ファイル）/ `tests/test_skill_test_coverage.bats`（回帰 pin）/ `tests/acceptance/AT-278.bats` / `tests/README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` に限定する。
- Non-Goals（PRD 準拠）: `_run_claude` の共通ファイル化はしない（11 ファイルそれぞれに同一編集を適用）。headless replay fixtures（`tests/fixtures/headless/`）と `scripts/run-skill-e2e.sh` には触れない。
- 11 ファイルの `_run_claude` は同一構造（`timeout` / `gtimeout` / フォールバックの 3 分岐、各分岐が `"$CLAUDE_BIN" -p "$prompt" \` 行 + `--max-turns 1` + `--permission-mode bypassPermissions`）。設定部の `TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}"` 行は全ファイルに存在する（行番号は 11 or 15 でファイルにより異なるため、編集はパターンベースで行う）。
- design doc は作成しない（デフォルトモデル = sonnet・環境変数名 `SKILL_E2E_MODEL`・追記箇所はすべて PRD で確定済みであり、競合する設計選択肢がない）。

## Implementation

- [ ] `tests/e2e/*.bats` 全 11 ファイルの設定部にある `TIMEOUT_SECS="${SKILL_E2E_TIMEOUT_SECS:-120}"` 行の直後に `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"` を追加する（CS-2: 既存と同じ命名規約・同じ上書き方式）
- [ ] verify: `grep -lF 'E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"' tests/e2e/*.bats | wc -l` が 11、かつ各ファイルで定義行が `TIMEOUT_SECS` 行の直後にある（`grep -A1 'TIMEOUT_SECS=' tests/e2e/*.bats` で確認）

- [ ] 全 11 ファイルの `_run_claude` の **timeout 分岐**: `timeout "$TIMEOUT_SECS" "$CLAUDE_BIN" -p "$prompt" \` 行の直後に `--model "${E2E_MODEL}" \` 行を挿入する（インデント・行継続 `\` は既存の `--max-turns 1 \` 行と同形）
- [ ] verify: `grep -A1 'timeout "\$TIMEOUT_SECS" "\$CLAUDE_BIN"' tests/e2e/*.bats | grep -c -- '--model "\${E2E_MODEL}"'` が 11（gtimeout 重複ヒット分を除いて確認）

- [ ] 全 11 ファイルの **gtimeout 分岐**: `gtimeout "$TIMEOUT_SECS" "$CLAUDE_BIN" -p "$prompt" \` 行の直後に同一の `--model "${E2E_MODEL}" \` 行を挿入する
- [ ] verify: `grep -A1 'gtimeout "\$TIMEOUT_SECS" "\$CLAUDE_BIN"' tests/e2e/*.bats | grep -c -- '--model "\${E2E_MODEL}"'` が 11

- [ ] 全 11 ファイルの **フォールバック分岐**（`else` 側の `"$CLAUDE_BIN" -p "$prompt" \`）の直後に同一の `--model "${E2E_MODEL}" \` 行を挿入する
- [ ] verify: `grep -c -- '--model "\${E2E_MODEL}"' tests/e2e/*.bats` の全 11 行が `:3`（CS-1: 全 3 分岐で一貫）

- [ ] 編集後の全 e2e ファイルが bats として構文破壊していないことを確認する
- [ ] verify: `bats --count tests/e2e/` がエラーなく従来どおりのテスト総数を返す

## Testing

- [ ] `tests/test_skill_test_coverage.bats` に回帰 pin の @test を 2 件追加する（US-3）: (a) **モデル変数 pin** — `tests/e2e/*.bats` の全ファイル（glob ベース。新規追加ファイルも自動的に対象）が `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"` 定義を含む、(b) **--model 全分岐 pin** — 各ファイルで `"$CLAUDE_BIN" -p` の起動行数と `--model "${E2E_MODEL}"` の出現数が一致する（= どの分岐にもモデル指定漏れがない。CS-1 のエンコード）。失敗時は対象ファイル一覧を出力する既存 @test と同形式にする
- [ ] verify: `bats tests/test_skill_test_coverage.bats` が green（既存 4 件 + 新規 2 件 = 6 件 PASS）

- [ ] 回帰 pin が実際に検出能力を持つことをネガティブ確認する: 任意の 1 ファイルから `--model` 行を一時的に外して pin が FAIL することを確認し、元に戻す
- [ ] verify: 改変中は該当 @test が FAIL、復元後は `bats tests/test_skill_test_coverage.bats` が green かつ `git diff tests/e2e/` の差分が意図した挿入行のみ

- [ ] `tests/acceptance/AT-278.bats` に acceptance-tests.md の AT のうち実行可能なもの（AT-001 / AT-002 / AT-004 / AT-005 / AT-006 / AT-008 の機械検証部分）をエンコードする（Step 4 / running-atdd-cycle で draft → green に進める）
- [ ] verify: `bats tests/acceptance/AT-278.bats` が green

- [ ] BATS suite 全体を回し、既存テストへの回帰がないことを確認する
- [ ] verify: `bats tests/` が green（`claude` バイナリ非依存。Skill E2E 本体の実行は対象外）

- [ ] （任意・実機スモーク）`claude` バイナリのある環境で最小の 1 ファイルを実行し、sonnet 指定でも E2E が従来どおり成立することを確認する: `bats tests/e2e/bug.bats`（3 @test、最小コスト）
- [ ] verify: 3 件 PASS（`claude` 不在環境では setup の skip が機能することのみ確認）

## Finishing

- [ ] `tests/README.md` の Skill E2E Tests 節（`## Skill E2E Tests (tests/e2e/)`）にモデルポリシーを 1-2 行追記する: 実行モデルはデフォルト **sonnet**（#259 ベンチ準拠のコスト最適化）、`SKILL_E2E_MODEL` 環境変数で上書き可能（US-4）
- [ ] verify: `grep -n 'SKILL_E2E_MODEL' tests/README.md` が Skill E2E Tests 節内にヒットし、デフォルト sonnet と上書き方法の両方が読み取れる

- [ ] `tests/README.md` の test_skill_test_coverage.bats のテーブル行説明を、モデル指定 pin を含む内容に同期する
- [ ] verify: `grep -n 'test_skill_test_coverage' tests/README.md` の説明が実ファイルの @test 構成（Unit+E2E 揃い検証 + モデル指定 pin）と一致する

- [ ] `CHANGELOG.md` の `## [Unreleased]` 直下に `## [3.11.3]` の `### Fixed` エントリを追加する（#278: Skill E2E の claude 起動に `--model`（デフォルト sonnet・`SKILL_E2E_MODEL` で上書き）を指定し、モデル未指定によるトークン過大消費を解消）
- [ ] verify: `bats tests/test_changelog_format.bats` が green、エントリに #278 参照が含まれる

- [ ] `.claude-plugin/plugin.json` の version を `3.11.2` → `3.11.3` に bump する（テストハーネスのコスト修正 = patch）
- [ ] verify: `scripts/check-plugin-version.sh` が green、CHANGELOG 最新エントリと version が一致する

- [ ] スコープ最終確認: 変更ファイルが前提のリストに限定されていることを突き合わせる（Non-Goals の `tests/fixtures/headless/` / `scripts/run-skill-e2e.sh` / `docs/guides/headless-skill-testing.md` が無変更）
- [ ] verify: `git diff main --name-only` が `tests/e2e/*.bats` / `tests/test_skill_test_coverage.bats` / `tests/acceptance/AT-278.bats` / `tests/README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` / `docs/issues/278-*` のみを返す
