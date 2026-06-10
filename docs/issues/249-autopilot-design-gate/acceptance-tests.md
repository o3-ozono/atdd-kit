# Acceptance Tests: autopilot 設計承認ゲート（#249）

<!-- AT lifecycle: planned → draft → green → regression。skill 実装の AT は
     Unit Test（tests/test_*.bats, claude 非起動の構造検証）と Skill E2E Test
     （tests/e2e/*.bats, claude が SKILL.md を読んで挙動を再現）の 2 層で検証する。 -->

## AT-001: 人間ゲート 3 点（F1）

- [x] [green] AT-001: SKILL.md が人間ゲートを要求承認 / 設計承認 / merge の 3 点に固定する
  - Given: `skills/autopilot/SKILL.md`
  - When: 読む（Unit: grep / E2E: LLM に「人間の介入点はどこか」を問う）
  - Then: 設計承認（design approval）ゲートが ATDD（impl phase）の前に記述され、要求承認・merge と合わせて 3 点である

## AT-002: フェーズ分離と 2 段 pin（F2）

- [x] [green] AT-002: design phase と impl phase が分離され、anchor がフェーズごとに正しい
  - Given: `skills/autopilot/SKILL.md` の埋め込み Workflow script
  - When: 読む（Unit: grep）
  - Then: design = [extracting-user-stories, writing-plan-and-tests] / pin = `autopilot-prd.pin`（prd.md）、impl = [running-atdd-cycle] / pin = `autopilot-design.pin`（prd.md + user-stories.md）。design phase の STEPS に AT_STEP が混入したら throw する fail-closed がある

## AT-003: 差し戻し再投入（F3）

- [x] [green] AT-003: 設計承認ゲートの差し戻しコメントが finding として design loop に再投入される
  - Given: `skills/autopilot/SKILL.md`
  - When: 読む（Unit: grep）
  - Then: 差し戻しコメントを evidence_ref 付き finding として design phase を再実行する記述がある

## AT-004: 既存原則の維持（C1）

- [x] [green] AT-004: flow skill / lib 無変更、行数 budget、impl phase の決定論ゲート維持
  - Given: 本 PR の diff + `skills/autopilot/SKILL.md`
  - When: diff と SKILL.md を確認（Unit: wc -l / grep）
  - Then: `skills/{defining-requirements,extracting-user-stories,writing-plan-and-tests,running-atdd-cycle,reviewing-deliverables}/` と `lib/` に変更がなく、SKILL.md ≤240 行、impl phase に deterministic AT gate + coverage gate が残る

## AT-005: テスト・ドキュメント同期（C2）

- [x] [green] AT-005: BATS / README / CHANGELOG / iron-law / version が同期
  - Given: リポジトリ全体
  - When: 確認（Unit: grep / バージョン値）
  - Then: test_autopilot_skill.bats と e2e/autopilot.bats が 3 ゲート・2 段 pin を pin し、README ×3 と iron-law が 3 ゲート記述、CHANGELOG に Changed 記載、plugin.json = 3.7.0

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
