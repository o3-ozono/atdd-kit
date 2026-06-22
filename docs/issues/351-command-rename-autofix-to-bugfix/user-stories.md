# User Stories: コマンド rename `/atdd-kit:autofix` → `/atdd-kit:bugfix`

## Functional Story

### F1: 起動コマンドを `bugfix` で呼べる

**I want to** bugfix 軽量ルート（`bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying`）を `/atdd-kit:bugfix <issue-number>` で起動でき、`commands/bugfix.md` が fixing-bugs ルートへ配線されている,
**so that** コマンド名が実体スキル `fixing-bugs` とユーザーの直感（バグ修正＝bugfix）に一致し、`autofix` の準予約語的衝突による誤読・誤起動がなくなる.

### F2: live documentation から `autofix` 参照が消える

**I want to** live documentation（`commands/README.md` / `skills/README.md` / `skills/skill-gate/SKILL.md` / `skills/fixing-bugs/SKILL.md` / `docs/methodology/route-eligibility.md` / `tests/README.md`）の `autofix` 参照が `bugfix` へ更新され、`commands/autofix.md` が存在しない,
**so that** historical record を除く現行ドキュメントから旧コマンド名が残らず、参照経路がすべて新コマンド名で一貫する.

### F3: 新コマンド配線が AT で検証される

**I want to** 既存 AT（`tests/acceptance/AT-308.bats` のパス pin と `/atdd-kit:autofix` grep）が新コマンド名へ更新され、加えて `commands/bugfix.md` の存在と fixing-bugs ルートへの配線、および `commands/autofix.md` の不在を検証する Acceptance Test が追加されている,
**so that** リネームの完了状態（新コマンド存在・旧コマンド廃止）が構造的に保証され回帰しない.

## Constraint Story (Non-Functional)

### C1: ハード rename（後方互換 alias なし）

**I want to** `commands/autofix.md` が削除され、deprecated alias stub も deprecation 警告も実装されず、`/atdd-kit:autofix` が完全に廃止されている,
**so that** #308 で最近導入され外部利用が浅い前提に従い、stub 保守コストを避けてコマンド体系がクリーンに保たれる.

### C2: historical record を改変しない

**I want to** `CHANGELOG.md` の #308 既存エントリと `docs/issues/308-*` / `docs/issues/322-*` / `docs/issues/246-*` の Issue 成果物を書き換えず、#351 の rename は CHANGELOG の新規エントリとしてのみ記録される,
**so that** Keep a Changelog 原則と Issue 記録の append-only 性に従い、過去に出荷した事実・当時の決定が保全される.

### C3: bugfix ルートの挙動を変えず既存スイートを green に保つ

**I want to** bugfix ルートのフロー・ゲート・オラクルを一切変えず命名のみを変更し、既存テストスイートが green のまま維持される,
**so that** 本 Issue が命名変更に閉じていることが保証され、ルート利用者の挙動に影響が出ない.
