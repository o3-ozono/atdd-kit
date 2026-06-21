# Plan: コマンド rename `/atdd-kit:autofix` → `/atdd-kit:bugfix`

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

<!-- Anchor: docs/issues/351-command-rename-autofix-to-bugfix/prd.md + user-stories.md（承認済み）。
     historical record（CHANGELOG #308 既存エントリ / docs/issues/308-* / 322-* / 246-*）は非改変（C2）。
     bugfix ルートのフロー・ゲート・オラクルは不変、命名のみ（C3）。 -->

## Implementation

### F1: 起動コマンドを `bugfix` で呼べる（commands/bugfix.md へハード rename）

- [ ] `git mv commands/autofix.md commands/bugfix.md`（ファイル名リネーム・履歴保持・alias stub なし）
- [ ] verify: `test -f commands/bugfix.md && ! test -f commands/autofix.md` が真（新規存在・旧不在）

- [ ] `commands/bugfix.md` 本文更新: 見出し `# /atdd-kit:autofix — bugfix Lightweight Route` → `# /atdd-kit:bugfix — bugfix Lightweight Route`、Usage コードブロック `/atdd-kit:autofix <issue-number>` → `/atdd-kit:bugfix <issue-number>`、"When to Use" の `Use autofix when...` → `Use bugfix when...`。`Delegates to skills/fixing-bugs/SKILL.md` 配線と `<issue-number>` 引数は維持
- [ ] verify: `grep -c 'atdd-kit:autofix' commands/bugfix.md` が 0、かつ `grep -q 'atdd-kit:bugfix' commands/bugfix.md` と `grep -q 'fixing-bugs' commands/bugfix.md` が真

### F2: live documentation から `autofix` 参照を `bugfix` へ更新

- [ ] `commands/README.md` の autofix 行を更新: 表示名 `[autofix](autofix.md)` → `[bugfix](bugfix.md)`、起動列 `/atdd-kit:autofix <issue>` → `/atdd-kit:bugfix <issue>`
- [ ] verify: `grep -c autofix commands/README.md` が 0、かつ `grep -q 'bugfix.md' commands/README.md` が真

- [ ] `skills/README.md` の fixing-bugs 行の `/atdd-kit:autofix <issue>` → `/atdd-kit:bugfix <issue>`
- [ ] verify: `grep -c autofix skills/README.md` が 0

- [ ] `skills/skill-gate/SKILL.md` の route 案内 `/atdd-kit:autofix` → `/atdd-kit:bugfix`
- [ ] verify: `grep -c autofix skills/skill-gate/SKILL.md` が 0、かつ skill-gate BATS が green

- [ ] `skills/fixing-bugs/SKILL.md` の description frontmatter `Explicit via /atdd-kit:autofix <issue>.` と Upstream 行 `explicit /atdd-kit:autofix <issue>` を `bugfix` へ更新
- [ ] verify: `grep -c autofix skills/fixing-bugs/SKILL.md` が 0、description が trigger 条件のみ（workflow 要約化しない／DEVELOPMENT.md Skill Description Field Rules）、`tests/test_fixing_bugs_skill.bats` が green

- [ ] `docs/methodology/route-eligibility.md` の起動コマンド表記 `/atdd-kit:autofix` → `/atdd-kit:bugfix`（route 名 `bugfix` は既に正、コマンド表記のみ）
- [ ] verify: `grep -c 'atdd-kit:autofix' docs/methodology/route-eligibility.md` が 0

- [ ] `tests/README.md` の AT-308 行の `autofix コマンド配線` を `bugfix コマンド配線` へ更新
- [ ] verify: `grep -c autofix tests/README.md` が 0

## Testing

### F3: 新コマンド配線を AT で検証（AT-308.bats 更新 ＋ 新規 AT 追加）

- [ ] `tests/acceptance/AT-308.bats` の既存 autofix 参照を更新: `@covers` 行の `commands/autofix.md` → `commands/bugfix.md`、変数 `AUTOFIX="commands/autofix.md"` → `BUGFIX="commands/bugfix.md"`（参照箇所も置換）、AT-308-6 の `grep -qE '/atdd-kit:autofix' "$AUTOFIX"` → `grep -qE '/atdd-kit:bugfix' "$BUGFIX"`、テスト名の `commands/autofix.md` 表記も更新
- [ ] verify: `grep -c autofix tests/acceptance/AT-308.bats` が 0、かつ `bats tests/acceptance/AT-308.bats` が green

- [ ] 新規 AT（AT-351）を実装（実コードは running-atdd-cycle が own、本 Step は AT 設計のみ）: ①`commands/bugfix.md` 存在＋`fixing-bugs` 配線 ②`/atdd-kit:bugfix` 表記を含む ③`commands/autofix.md` 不在 ④live docs に `autofix` 参照が残らない（historical record 除外）
- [ ] verify: 新規 AT が green（実装は Step 4）。historical record（docs/issues/308-*, 322-*, 246-*, CHANGELOG #308 エントリ, docs/issues/351-* の prd/user-stories）を grep 対象から除外し非改変を担保

- [ ] 既存テストスイート全体を実行し回帰なしを確認（C3）
- [ ] verify: `bats tests/` 相当が green（命名のみ変更でルート挙動・ゲート不変）

## Finishing

- [ ] `CHANGELOG.md` の `## [Unreleased]` に #351 の rename エントリを `### Changed` として追記（`/atdd-kit:autofix` → `/atdd-kit:bugfix` のハード rename・alias なし）。#308 既存エントリは非改変
- [ ] verify: `grep -q '#351' CHANGELOG.md` が真、かつ #308 既存エントリの diff が空

- [ ] `.claude-plugin/plugin.json` の version を bump（コマンド rename。スキル id `fixing-bugs` は不変＝DEVELOPMENT.md「Skill rename = major」には非該当。コマンド rename はユーザー自動化に影響しうるため minor 以上を検討、最終判断は実装時）
- [ ] verify: plugin.json version が CHANGELOG 最新リリース見出しと一致（AT-308-10 不変条件・exact-pin しない）

- [ ] ドキュメント整合性チェック: live docs 全体で `autofix` 残存が historical record のみであることを確認
- [ ] verify: `grep -rln autofix commands skills docs/methodology tests rules --include='*.md' --include='*.bats'` の結果が historical record（docs/issues/308-*, 322-*, 246-*, docs/issues/351-* の prd/user-stories）と CHANGELOG #308 エントリのみ
