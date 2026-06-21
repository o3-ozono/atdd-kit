# PRD: コマンド rename `/atdd-kit:autofix` → `/atdd-kit:bugfix`

## Problem

bugfix 軽量ルート（`bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`）を起動するコマンドが `/atdd-kit:autofix` という名前になっている。

- **現状:** コマンド名 `autofix` は、一般エコシステムで「ツールがコードを自動でパッチする」挙動を指す準予約語的な用語と衝突している（GitHub code scanning autofix / Dependabot autofix、ESLint・Prettier・ruff 等の linter `--fix`/autofix、IDE の Auto-Fix）。一方 atdd-kit の `autofix` は「defect Issue を bugfix 軽量ルートで回す、人間ゲート付きのワークフロー起動」であり別物。さらに実体スキル名は `fixing-bugs` なのにコマンド名だけ `autofix` で**不一致**。
- **困ること:** 名前から挙動が誤読される。実際にユーザーがこのルートを呼ぼうとして `/bugfixing` とタイプし、コマンド名 `autofix` を想起できなかった（= 名前が直感に反している）のが起票のきっかけ。

## Why now

`autofix` ルートは #308 で最近導入されたばかりで、参照箇所（live documentation）が 8 ファイルに限られ、外部利用も浅い。命名が定着して参照が増殖し、ユーザーの誤起動・誤解が常態化する前に改称するのが最も低コスト。リネーム対象が小さい今が機会コスト最小のタイミング。

## Outcome

- 起動コマンドが `/atdd-kit:bugfix <issue-number>` になり、実体スキル `fixing-bugs` と整合し、ユーザーの直感（バグ修正＝bugfix）とも一致する。
- 旧コマンド `/atdd-kit:autofix` は**完全に廃止**（ハード rename・alias なし）。`commands/autofix.md` は存在しない。
- live documentation（SKILL.md / README / methodology docs / AT）に `autofix` への参照が残らない（historical record を除く）。
- 既存テストスイートが green。新コマンド配線を検証する AT が green。

## What

- `commands/autofix.md` → `commands/bugfix.md` にリネーム（中身の `/atdd-kit:autofix` 表記・見出しも `bugfix` へ更新）。alias stub は残さない。
- live documentation 内の `autofix` 参照を `bugfix` へ更新:
  - `commands/README.md`（コマンド一覧表）
  - `skills/README.md`（fixing-bugs 行の明示コマンド表記）
  - `skills/skill-gate/SKILL.md`（route 案内）
  - `skills/fixing-bugs/SKILL.md`（description frontmatter ＋ Upstream 表記）
  - `docs/methodology/route-eligibility.md`（bugfix Route Signals の起動コマンド表記）
  - `tests/README.md`（AT-308 行の `autofix コマンド配線` 表記）
- AT 更新: `tests/acceptance/AT-308.bats` の `commands/autofix.md` パス pin と `/atdd-kit:autofix` grep を新コマンド名へ更新。
- 新コマンド配線を検証する Acceptance Test を追加（`commands/bugfix.md` が存在し fixing-bugs ルートへ配線、かつ `commands/autofix.md` が存在しない）。
- `CHANGELOG.md` に #351 の新エントリを追記（rename / コマンド名変更として記載）。

## Non-Goals

- **後方互換 alias の維持** — ハード rename を選択（ユーザー判断）。`commands/autofix.md` は削除し deprecated alias stub も deprecation 警告も実装しない。理由: #308 で最近導入され外部利用が浅く、stub 保守コストを避けクリーンにするため。
- **historical record の書き換え** — `CHANGELOG.md` の #308 既存エントリ（過去の出荷状態の記録）、`docs/issues/308-*` / `docs/issues/322-*` / `docs/issues/246-*` の Issue 成果物（当時の決定の記録）は書き換えない。理由: Keep a Changelog 原則と Issue 記録の append-only 性に従い、過去の事実を改変しない。新事実は #351 の新 CHANGELOG エントリで記録する。
- **bugfix ルート自体の挙動変更** — ルートのフロー・ゲート・オラクルは一切変えない。本 Issue は命名のみ。

## Open Questions

なし（後方互換は「ハード rename・alias なし」でユーザー確定済み。historical record 非改変は標準慣行に従う）。
