# Acceptance Tests: autopilot 埋め込み Workflow script の args fail-closed 化（#252 先行対処後の残差分）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実行コマンド: `bats tests/test_autopilot_skill.bats`（SKILL.md は宣言的成果物のため、AT は BATS の静的 pin として実装する — #252 で導入済みの parse / issue ガード pin と同方式）。

## AT-001: phase 未指定・不正値で即 throw（US-1）

- [x] [green] AT-001: フォールバック既定値が廃止され、phase ガードが throw する
  - Given: `skills/autopilot/SKILL.md` の埋め込み Workflow script
  - When: BATS pin が script 本文を検査する
  - Then: `A.phase !== 'design' && A.phase !== 'impl'` で throw するガードが存在し、フォールバックパターン `? 'impl' : 'design'` が存在しない

## AT-002: design / impl のみ受理（US-1, CS-1）

- [x] [green] AT-002: 受理される phase 値が `'design'` と `'impl'` の 2 値に限定されている
  - Given: phase ガード通過後の `const PHASE = A.phase` 代入
  - When: BATS pin が script 本文を検査する
  - Then: `PHASE` への代入はガード通過後の `A.phase` 直接代入のみで、ガード外で `PHASE` に既定値を与える経路が存在しない

## AT-003: phase ガードの BATS pin が green（US-2）

- [x] [green] AT-003: 追加した phase ガード pin テストがスイート内で通過する
  - Given: `tests/test_autopilot_skill.bats` に phase ガード pin テストが追加されている
  - When: `bats tests/test_autopilot_skill.bats` を実行する
  - Then: 追加テストを含む全テストが pass し、#252 で導入済みの parse / issue ガード pin にも回帰がない

## AT-004: invoke 指示への args 形式注記（US-3）

- [x] [green] AT-004: Flow 節の design / impl 両 invoke 指示に args 形式注記がある
  - Given: SKILL.md の Flow 節 step 2（design phase）と step 4（impl phase）
  - When: BATS pin が SKILL.md を検査する
  - Then: 「args は JSON オブジェクトとして渡す（文字列化した JSON を渡さない）」の注記が両 invoke 指示に存在する

## AT-005: fail-closed — 不正 args では 1 イテレーションも走らない（CS-1）

- [x] [green] AT-005: phase ガードが FREEZE・イテレーションループより前に位置する
  - Given: 埋め込み Workflow script の構造（args parse → 定数定義 → FREEZE → ループ）
  - When: script 内の phase ガードと `freeze:anchor` の出現位置を比較する
  - Then: phase ガードは `pin_anchor`（FREEZE）および最初のイテレーションより前にあり、不正・欠落 args（parse 不能・issue 不正・phase 未指定/不正値）では agent 呼び出しが一度も発生しない

## AT-006: スコープの限定（CS-2）

- [x] [green] AT-006: 変更が script 側ガード + BATS pin + SKILL.md 注記に限定されている
  - Given: 本 Issue のブランチ `fix/256-autopilot-args-fail-closed` の差分
  - When: `git diff --name-only main` で変更ファイル一覧を取得する
  - Then: `skills/autopilot/SKILL.md` / `tests/test_autopilot_skill.bats` / `.claude-plugin/plugin.json` / `CHANGELOG.md` / `docs/issues/256-*` 以外の変更がなく、特に `lib/autopilot_convergence.sh` と Workflow ツール（harness）側の変更を含まない

<!-- 実装開始後は [planned] → [draft] に変更する -->
<!-- テストが通過したら [draft] → [green] に変更する -->
<!-- リグレッション対象になったら [green] → [regression] に変更する -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
