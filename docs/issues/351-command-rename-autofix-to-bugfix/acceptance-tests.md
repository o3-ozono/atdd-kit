# Acceptance Tests: コマンド rename `/atdd-kit:autofix` → `/atdd-kit:bugfix`

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     Anchor: docs/issues/351-command-rename-autofix-to-bugfix/user-stories.md（承認済み）。
     #289: version・日付・行数を exact-pin しない。不変条件をアサートする。 -->

## AT-351-1: 起動コマンド `bugfix` が fixing-bugs ルートへ配線（F1 / C1）

- [x] [regression] AT-351-1: `commands/bugfix.md` が存在し fixing-bugs ルートへ配線され、`commands/autofix.md` は存在しない
  - Given: コマンド rename 後のリポジトリ
  - When: `commands/` 配下のコマンドファイルとその内容を検査する
  - Then: `commands/bugfix.md` が存在し、`fixing-bugs` への配線（`Delegates to skills/fixing-bugs/SKILL.md`）と `<issue-number>` 引数を含み、`/atdd-kit:bugfix` 表記を持つ。かつ `commands/autofix.md` は存在せず、`commands/bugfix.md` に `/atdd-kit:autofix` 表記が残らない（alias stub・deprecation 警告なし）

## AT-351-2: live documentation から `autofix` 参照が消える（F2）

- [x] [regression] AT-351-2: live documentation の `autofix` 参照が `bugfix` へ更新されている
  - Given: rename 後のリポジトリ
  - When: live documentation 群（`commands/README.md` / `skills/README.md` / `skills/skill-gate/SKILL.md` / `skills/fixing-bugs/SKILL.md` / `docs/methodology/route-eligibility.md` / `tests/README.md`）を grep する
  - Then: いずれにも `autofix` 文字列が残らず、コマンド表記はすべて `/atdd-kit:bugfix`。historical record（`docs/issues/308-*` / `docs/issues/322-*` / `docs/issues/246-*` / `docs/issues/351-*` の prd・user-stories、`CHANGELOG.md` の #308 既存エントリ）は grep 対象から除外する

## AT-351-3: 既存 AT-308 配線 pin が新コマンド名へ更新されている（F3）

- [x] [regression] AT-351-3: `tests/acceptance/AT-308.bats` のパス pin と `/atdd-kit:autofix` grep が新コマンド名へ更新され green
  - Given: rename 後のリポジトリ
  - When: `tests/acceptance/AT-308.bats` を検査・実行する
  - Then: `@covers` 行とパス変数が `commands/bugfix.md` を指し、配線 grep が `/atdd-kit:bugfix` を検査する。`AT-308.bats` に `autofix` 文字列が残らず、`bats tests/acceptance/AT-308.bats` が green

## AT-351-4: bugfix ルート挙動不変・既存スイート green（C3）

- [x] [regression] AT-351-4: 命名のみの変更でルートのフロー・ゲート・オラクルが不変、既存テストスイートが green
  - Given: rename 後のリポジトリ
  - When: 既存テストスイート（`bats tests/` 相当）を実行し、fixing-bugs ルートのチェーン・cause-agreement 中間ゲート・User merge ゲート・赤→緑 オラクルの記述を確認する
  - Then: スイートが green。fixing-bugs ルートのフロー（`bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`）・ゲート・オラクルの記述に命名以外の差分がない

## AT-351-5: version/CHANGELOG 整合（不変条件 / Finishing）

- [x] [regression] AT-351-5: plugin.json version が CHANGELOG 最新リリース見出しと一致し、#351 エントリが追記されている
  - Given: rename 後のリポジトリ
  - When: `.claude-plugin/plugin.json` の version と `CHANGELOG.md` の最新リリース見出し・#351 エントリを検査する
  - Then: `plugin.json` の version が CHANGELOG 最新リリース見出しと一致（exact-pin せず不変条件でアサート、#289）。`CHANGELOG.md` に #351 の rename エントリが存在し、#308 既存エントリは非改変

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
