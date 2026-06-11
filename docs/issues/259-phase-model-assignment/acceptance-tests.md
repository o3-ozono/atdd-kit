# Acceptance Tests: フェーズ別モデル割り当て — impl / review の Sonnet 化

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実行コマンド: `bats tests/test_reviewing_deliverables_skill.bats tests/test_autopilot_skill.bats tests/test_running_atdd_cycle_skill.bats tests/test_phase_model_assignment.bats tests/test_issue_105_frontmatter_session_inheritance.bats`（SKILL.md / README は宣言的成果物のため、AT は BATS の静的 pin として実装する — #256 と同方式）。

## AT-001: review Workflow の Scout〜Verify が Sonnet（US-1, CS-1）

- [x] [green] AT-001: reviewing-deliverables の Workflow script で Scout / Generate / Review / Verify の `agent()` が `model: 'sonnet'` を持つ
  - Given: `skills/reviewing-deliverables/SKILL.md` の埋め込み Workflow script
  - When: BATS pin が script 本文を検査する
  - Then: Scout / Generate / Review / Verify の 4 種の `agent()` オプションすべてに `model: 'sonnet'` が存在する

## AT-002: Aggregate のみセッションモデル維持（US-1）

- [x] [green] AT-002: Aggregate の `agent()` には `model` 指定がない
  - Given: 同 script の Aggregate phase（`{ phase: 'Aggregate', schema: AGG_SCHEMA }`）
  - When: BATS pin が Aggregate の `agent()` オプションを検査する
  - Then: `model` キーが存在せず、セッションモデル継承の理由コメント（#259）が付いている

## AT-003: impl phase の推奨モデルガイダンス（US-2）

- [x] [green] AT-003: autopilot と running-atdd-cycle に impl phase の推奨モデルが明文化されている
  - Given: `skills/autopilot/SKILL.md` の Model assignment 節と `skills/running-atdd-cycle/SKILL.md` の注記
  - When: BATS pin が両 SKILL.md を検査する
  - Then: impl phase subagent は Sonnet 標準・設計絡み Issue はセッションモデルへ昇格、が両方から読み取れ、line budget pin（autopilot 260 行 / running-atdd-cycle 200 行）も green を維持する

## AT-004: agents/README.md のポリシー更新（US-3, CS-1）

- [x] [green] AT-004: 「intentionally unset」が新ポリシー + ベンチ要点に置換されている
  - Given: `agents/README.md` のモデルポリシー節
  - When: BATS pin が README を検査する
  - Then: `intentionally unset` の文言が存在せず、impl / review = Sonnet の新ポリシー、escalation path、ベンチ要点（コスト比 Sonnet 1.0 : Opus 2.2 : Fable 4.1）が存在する

## AT-005: escalation トリガーの決定的定義（CS-2）

- [x] [green] AT-005: 昇格経路がトリガー条件付きで規定されている
  - Given: `skills/autopilot/SKILL.md` の Model assignment 節と `agents/README.md` の escalation path
  - When: BATS pin が両ファイルを検査する
  - Then: 収束失敗系 halt（`MAX_ITERATIONS` / `sameness-detector` / `stuck`）でセッションモデルへ昇格する経路が両方に存在し、トリガー定義が両ファイルで同一である

## AT-006: 適用範囲の限定 — design phase / メインループ / agent frontmatter 不変（CS-3）

- [x] [green] AT-006: 変更が impl / review の subagent 指定とガイダンス文書に限定されている
  - Given: ブランチ `feat/259-phase-model-assignment` の差分と #105 リグレッションガード
  - When: `git diff --name-only main` と `bats tests/test_issue_105_frontmatter_session_inheritance.bats` を実行する
  - Then: `skills/extracting-user-stories/` / `skills/writing-plan-and-tests/` / `agents/*.md`（README 除く）/ `lib/` に変更がなく、#105 の 4 pin（frontmatter に `model:` / `effort:` なし、README に Model / Effort 列なし、session 言及あり）が全件 pass する

## AT-007: スイート全体の green 維持（CS-1, CS-3）

- [x] [green] AT-007: 追加 pin を含む BATS スイート全体が pass する
  - Given: 本 Issue の全変更（SKILL.md × 3、agents/README.md、BATS pin、version / CHANGELOG）
  - When: `bats tests/` を実行する
  - Then: 新規 `test_phase_model_assignment.bats` を含む全テストが pass し、`scripts/check_bats_covers.sh` が OK を返す

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
