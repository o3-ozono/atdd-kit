# Acceptance Tests: autopilot 復活 — 自律収束ループ（converging-deliverables）

<!-- AT lifecycle: planned → draft → green → regression。skill 実装の AT は
     Unit Test（tests/test_*.bats, claude 非起動の構造検証）と Skill E2E Test
     （tests/e2e/*.bats, claude が SKILL.md を読んで挙動を再現）の 2 層で検証する。 -->

> 状態（2026-06-08）: **Unit Test 全 green**（test_converging_deliverables_skill 15 / test_autopilot_convergence 11 / test_reviewing_deliverables_skill の #246 アサーション 3）。**Skill E2E** は `run-skill-e2e.sh --dry-run` で構造解決済み（converging-deliverables.bats / reviewing-deliverables.bats）、実 claude 実行は CI（`skill-e2e-subscription`, self-hosted サブスク内）。

## AT-001: 半自動運転オーケストレーション (F1)

- [x] [green] AT-001: SKILL.md が既存 6-step skill を順に呼び、人間ゲートを最初(AC承認)と最後(merge)に絞る
  - Given: `skills/converging-deliverables/SKILL.md` が存在する
  - When: SKILL.md を読む（Unit: grep / E2E: LLM に「人間の介入点はどこか」を問う）
  - Then: `extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables` を順に呼ぶ記述と、人間ゲート = AC 承認 / merge の2点に絞る記述がある

## AT-002: 満足オラクルによる自律収束 (F2)

- [x] [green] AT-002: 満足オラクル `AND(AT緑, verdict=correct, P0/P1=0)` まで generate→review→fix を反復
  - Given: `skills/converging-deliverables/SKILL.md`
  - When: 読む（Unit: grep AND ゲート / E2E: LLM に「収束条件は何か」を問う）
  - Then: `AND(実行可能 AT 緑, verdict=correct, P0/P1 findings=0)` と generate→review→fix ループ、満たしたら次 step へ進む記述がある

## AT-003: 安全に失敗する (F3)

- [x] [green] AT-003: 非収束検出と escalation、verdict の JSONL 永続化
  - Given: `skills/converging-deliverables/SKILL.md` + `lib/autopilot_convergence.sh`
  - When: SKILL.md を読む / sameness-detector に同一 fingerprint を2連続入力する（Unit）
  - Then: MAX_ITERATIONS / sameness-detector(sha256) / stuck(window=3) / COMPLETED_WITH_DEBT / human escalation / JSONL の記述があり、sameness-detector が同一 fingerprint 2連続で非ゼロ終了する

## AT-004: autopilot 専用 Iron Law (F4)

- [x] [green] AT-004: autopilot モードで標準 Iron Law を AL-1〜6 で上書き
  - Given: `docs/methodology/autopilot-iron-law.md` + `rules/atdd-kit.md` 参照 + SKILL.md
  - When: 読む（Unit: grep / E2E: LLM に「autopilot で Iron Law #2 はどう扱うか」を問う）
  - Then: AL-1〜6 が定義され、autopilot モードで標準 Iron Law を上書き、人間ゲート2点、AL-2 が標準 #2 を置換、の記述がある

## AT-005: 既存 skill を恒久変更しない / verdict 後方互換 (C1)

- [x] [green] AT-005: reviewing-deliverables の verdict が後方互換（findings 追加、PASS/FAIL 維持）
  - Given: `skills/reviewing-deliverables/SKILL.md`
  - When: 読む（Unit: grep）
  - Then: `AGG_SCHEMA` に `overall_correctness` / `findings` が追加され、既存 `verdict` / `summary` / `byLens` が維持されている

## AT-006: ゼロ依存 + 行数規律 (C2)

- [x] [green] AT-006: 安全レールが pure bash、SKILL.md が行数 budget 内
  - Given: `lib/autopilot_convergence.sh` + `skills/converging-deliverables/SKILL.md`
  - When: チェック（Unit: 外部依存 grep / `wc -l`）
  - Then: 外部コマンド依存がない（pure bash + coreutils のみ）、SKILL.md が行数 budget 内

## AT-007: skill 変更のテスト証拠 (C3)

- [x] [green] AT-007: Unit + Skill E2E + lib + verdict の BATS が存在
  - Given: `tests/`
  - When: ファイルを確認（Unit）
  - Then: `tests/test_converging-deliverables_skill.bats` / `tests/e2e/converging-deliverables.bats` / `tests/test_autopilot_convergence.bats` が存在し、`tests/test_reviewing_deliverables_skill.bats` に verdict アサーションがある

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
