# Acceptance Tests: autopilot 時の壁打ち・確認対話を「判断が必要な点のみ」に省力化する

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実装形態: 本 Issue の成果物は LLM-facing 指針（`skills/autopilot/SKILL.md`）のため、AT は `tests/test_autopilot_skill.bats` の構造ピン（grep）として実装する（CS-3 の要求そのもの）。Step 4（running-atdd-cycle）が各エントリを `[planned]` → `[draft]` → `[green]` に進める。

## AT-001: 質問は「人間にしか決められない点」のみ（US-1）

- [x] [green] AT-001: SKILL.md の Dialog economy セクションに「聞くべき」基準が明文化されている
  - Given: `skills/autopilot/SKILL.md` に `## Dialog economy` セクションが存在する
  - When: BATS ピン `dialog economy (#254): asks only human-only decisions (US-1)` が `ask ONLY` / `trade-off` / `scope` / `Outcome` を grep する
  - Then: すべてヒットし、質問対象が「設計判断が分かれるトレードオフ・割り切り / スコープの増減 / Outcome の合否基準」に限定されていることが検証される

## AT-002: ドラフトは一括提示・固定ゲートで一括承認（US-2）

- [x] [green] AT-002: 逐次 ok 確認の禁止と一括提示・一括承認が明文化されている
  - Given: 同セクションに「聞かない」基準が記載されている
  - When: BATS ピン `dialog economy (#254): drafts are batch-presented, approved once per fixed gate (US-2)` が `batch-present` / `never ask section-by-section` を grep する
  - Then: すべてヒットし、自明セクションの逐次確認 0 回・固定ゲート（PRD 承認 / 設計承認 / merge）で各 1 回の承認方針が検証される

## AT-003: 指針は orchestrator 側にあり対話全般に適用（US-3）

- [x] [green] AT-003: 指針が autopilot SKILL.md（orchestrator）に置かれ、適用範囲が autopilot 中の人間向け対話全般である
  - Given: flow skill 側ではなく `skills/autopilot/SKILL.md` に指針が存在する
  - When: BATS ピン `dialog economy (#254): directive lives in the orchestrator and covers all gate dialogs (US-3/CS-2)` が `## Dialog economy` 見出しと `all human-facing dialog under autopilot` を grep し、Human gates セクションからの参照（`Dialog economy` の出現 3 箇所以上）を数える
  - Then: すべてヒットし、Gate ① 壁打ちと design ゲート提示の双方に指針が適用されることが検証される

## AT-004: 人間ゲートは AL-1 の 3 点固定のまま不変（CS-1）

- [x] [green] AT-004: 新セクション追加後もゲート数の契約が変わっていない
  - Given: Dialog economy セクションが追加された `skills/autopilot/SKILL.md`
  - When: BATS ピン `dialog economy (#254): gates stay exactly three (CS-1)` と既存ピン `orchestration: human gates fixed to three points` を実行する
  - Then: `exactly three` が残存し、削減対象がゲート間・ゲート内のマイクロ確認に限定される旨（AL-1 不変宣言）が検証される

## AT-005: 通常フローの対話設計は不変 — C1 原則（CS-2）

- [x] [green] AT-005: "one question at a time" は通常フローで維持され、オーバーライドは autopilot 側にのみ明記される
  - Given: `skills/defining-requirements/SKILL.md` を含む flow skill 本体
  - When: BATS ピンが autopilot SKILL.md 内の `one question at a time` + オーバーライド文言を grep し、さらに `git diff main -- skills/defining-requirements/ skills/extracting-user-stories/ skills/writing-plan-and-tests/ skills/running-atdd-cycle/ skills/reviewing-deliverables/ skills/merging-and-deploying/` を確認する
  - Then: オーバーライド明記は autopilot SKILL.md 側のみに存在し、flow skill 本体の差分は空である

## AT-006: 指針文言は BATS pin で構造検証される（CS-3）

- [x] [green] AT-006: ピンテスト群が `tests/test_autopilot_skill.bats` に存在し、スイート全体が green
  - Given: AT-001〜AT-004 のピンテストが `tests/test_autopilot_skill.bats` に追加され、line budget テストが新行数（上限 260）に更新されている
  - When: `bats tests/test_autopilot_skill.bats` を実行する
  - Then: 新規 #254 ピンを含む全テストが exit code 0 で green になり、指針の欠落・改変が将来の編集で即検知できる状態になる

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
