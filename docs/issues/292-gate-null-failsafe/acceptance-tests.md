# Acceptance Tests: autopilot Workflow の `agent()` null フェイルセーフ化（#292）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

検証方式: `skills/autopilot/SKILL.md` は Workflow を実行する LLM 向けスクリプトで、claude を実走させずに構造アサーション（grep）で挙動を pin する（既存 `tests/test_autopilot_skill.bats` と同方式）。各 AT は SKILL.md の該当 null ガード文字列・fail-safe セマンティクス（reason / 継続条件）を pin する。`[regression]` 化する AT は時点固定値（version・日付・行数）を素の数値で pin せず、不変条件（ガード文字列・fail-open 禁止コメントの存在）を pin する（#289）。

## AT-001: at-gate の null をループ継続で吸収（AC1 / FS-1）

- [x] [regression] AT-001: at-gate の `agent()` 戻り値 null が atGreen=false（gate 未通過）に倒れ、クラッシュしない
  - Given: SKILL.md の deterministic AT gate（label: `at-gate:step`）の `atGreen` 算出
  - When: 構造 pin（grep）を実行する
  - Then: `atGreen = at != null && at.exitCode === 0 && at.green === true` を含み（null=未通過でループ継続）、null ガード無しの `at.exitCode === 0 && at.green === true` 単独行が残っていない

## AT-002: coverage の null をループ継続で吸収（AC2 / FS-2）

- [x] [regression] AT-002: coverage の `agent()` 戻り値 null が coverageOk=false・uncovered=[] に倒れ、クラッシュしない
  - Given: SKILL.md の AC→AT coverage gate（label: `coverage:step`）の算出
  - When: 構造 pin（grep）を実行する
  - Then: `uncovered = cov?.uncovered || []` と `coverageOk = cov != null && cov.allCovered === true && uncovered.length === 0` を含み、オプショナルチェーン無しの素参照 `cov.allCovered === true` が残っていない

## AT-003: review の null を未収束扱いでループ継続（AC3 / FS-3）

- [x] [regression] AT-003: review（verdict）の `agent()` 戻り値 null が「未収束」（overall_correctness 不一致・findings 無し）に倒れ、PASS にならずクラッシュしない
  - Given: SKILL.md の review 結果（verdict）を参照する oracle 算出
  - When: 構造 pin（grep）を実行する
  - Then: `verdict.overall_correctness === 'correct'` が fail-safe 形（`verdict != null && verdict.overall_correctness === 'correct'` または等価のオプショナルチェーン）になり、null の verdict が `converged === true` に到達しない（fail-open しない）

## AT-004: freeze の null をフェイルクローズで安全終了（AC4 / FS-4）

- [x] [regression] AT-004: freeze（frozen）の `agent()` 戻り値 null が COMPLETED_WITH_DEBT（reason 系: freeze-error）で安全終了し、クラッシュしない
  - Given: SKILL.md の FREEZE ステップ（label: `freeze:anchor`）の戻り値ガード
  - When: 構造 pin（grep）を実行する
  - Then: `frozen == null` を含むガードと `reason: 'freeze-error'`（COMPLETED_WITH_DEBT）が存在し、`frozen.logLines` 参照が null ガードより後にある

## AT-005: audit の null をフェイルクローズで安全終了（AC5 / FS-5）

- [x] [regression] AT-005: audit（rec）の `agent()` 戻り値 null が既存 recordOk 経路に合流し COMPLETED_WITH_DEBT（reason: record-error）で安全終了する
  - Given: SKILL.md の AUDIT ステップ（label: `audit:step`）の返却ガード
  - When: 構造 pin（grep）を実行する
  - Then: 返却ガードが `rec == null || rec.recordOk !== true` を含み、`reason: 'record-error'` が存在する

## AT-006: rails の null をフェイルクローズで halt（AC6 / FS-6）

- [x] [regression] AT-006: rails（r）の `agent()` 戻り値 null が halt（COMPLETED_WITH_DEBT, reason: rails-error）で安全終了し、`r.acDriftExit` 等を null 参照しない
  - Given: SKILL.md の safety rails ステップ（label: `rails:step`）の halt 算出
  - When: 構造 pin（grep）を実行する
  - Then: `r == null` を含むガードと `reason: 'rails-error'` が存在し、`r.acDriftExit !== 0` 参照が null ガードより後にある

## AT-007: null は決して fail-open しない（AC7 / CS-1）— 不変条件

- [x] [regression] AT-007: いずれの null 経路も「収束済み / PASS」と誤判定しないことが SKILL.md に明示される
  - Given: SKILL.md の null フェイルセーフ方針コメント
  - When: 構造 pin（grep）を実行する
  - Then: fail-open を禁止する旨のコメント（「never fail-open」または同義表現）が存在し、ループ継続経路（at-gate / coverage / review）の null セマンティクスがいずれも gate 未通過 / 未収束（false 側）に倒れている

## AT-008: BATS テスト証跡と既存スイート green 維持（AC8 / CS-3）

- [x] [regression] AT-008: null フェイルセーフの構造アサーションが追加され、既存 BATS スイートが green を維持する
  - Given: 変更後の `skills/autopilot/SKILL.md` と `tests/test_autopilot_skill.bats`
  - When: `bats tests/test_autopilot_skill.bats` を実行する
  - Then: #292 セクションの AT-001…AT-007 相当の新規 test が pass し、既存の全 test も pass する（exit code 0）

## AT-009: SKILL.md 行バジェット遵守（AC9 / CS-3）— 不変条件

- [x] [regression] AT-009: SKILL.md が行バジェット内に収まる（第 3 回引き上げ不可のため上限固定）
  - Given: 変更後の `skills/autopilot/SKILL.md`
  - When: 行数を確認する
  - Then: `wc -l skills/autopilot/SKILL.md` が 280 以下（in-line ガード中心で行数増を最小化）

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
