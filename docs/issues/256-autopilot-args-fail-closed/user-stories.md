# User Stories: autopilot 埋め込み Workflow script の args fail-closed 化（#252 先行対処後の残差分）

## Functional Story

### US-1: phase の明示必須化（フォールバック既定値の廃止）

**I want to** `skills/autopilot/SKILL.md` 埋め込み Workflow script が `A.phase !== 'design' && A.phase !== 'impl'` のとき即 throw する（`const PHASE = A.phase === 'impl' ? 'impl' : 'design'` のフォールバックを廃止する）,
**so that** args が文字列のまま届くなどで phase が欠落・不正でも impl 実行が design に化けず、設計承認ゲートの意味が壊れない.

### US-2: phase ガードの BATS pin 追加

**I want to** `tests/test_autopilot_skill.bats` に phase ガード（未指定・不正値で throw、`design` / `impl` のみ受理）の pin テストが追加されている,
**so that** #252 で導入済みの parse / issue ガードの pin と合わせて全ガードが pin され、回帰で無言に消えない.

### US-3: invoke 指示への args 形式注記

**I want to** SKILL.md の Flow 節の invoke 指示に「args は JSON オブジェクトとして渡す（文字列化した JSON を渡さない）」という注記が追加されている,
**so that** Workflow ツール呼び出し時に args を誤って文字列化する事象（#251 design phase で実発生）を呼び出し側で予防できる.

## Constraint Story (Non-Functional)

### CS-1: fail-closed（不正・欠落 args では 1 イテレーションも走らない）

**I want to** 不正・欠落 args（parse 不能・issue 不正・phase 未指定/不正値）では収束ループが 1 イテレーションも走らず即停止する,
**so that** worktree 名からの推測などの偶然のリカバリで走る AL-2（anchor 接地）違反が構造的に発生しない.

### CS-2: スコープの限定（防御の恒久化）

**I want to** 変更が script 側ガードと BATS pin・SKILL.md 注記に限定され、Workflow ツール（harness）側の修正や `lib/autopilot_convergence.sh` の変更を含まない（ツール側が直っても script 側ガードは防御として残る）,
**so that** プラグイン管轄内で完結する最小差分で防御が恒久化され、#248（監査ログ堅牢化）等の他 Issue のスコープと衝突しない.
