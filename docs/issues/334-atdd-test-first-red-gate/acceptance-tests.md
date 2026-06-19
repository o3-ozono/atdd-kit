# Acceptance Tests: ATDD の test-first（AT red 先行）を構造的に担保する

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     [regression] AT は将来の全ブランチで走るため、時点固定値（プラグインバージョン・日付・行数）を
     exact-pin しない。invariant（不変条件）を assert する。 -->

## AT-334-A: 決定的 red ゲート（F1 / C1）

新規 AT について red 証跡が無い限り impl phase の satisfaction oracle が満たされないことを、LLM 判断ではなく exit code で機械検証する。

- [x] [regression] AT-334-A1: red 証跡ありで redObserved=true（収束可）
  - Given: 新規 AT を含む test コミットが impl コミットより先行し、test コミット時点で当該 AT が red（非0 exit）だった証跡が記録されている
  - When: `check_red_evidence <test-commit> <impl-commit>` を実行する
  - Then: exit 0（redObserved を真にできる）を返す

- [x] [regression] AT-334-A2: red 証跡欠如で fail-closed（収束不可）
  - Given: 新規 AT について red 証跡が記録されていない（red を一度も踏まず green になった）
  - When: `check_red_evidence` を実行する
  - Then: 非0 exit を返し、satisfaction oracle の redObserved 項が false になる（green でも収束しない）

- [x] [regression] AT-334-A3: コミット順序逆転で fail-closed
  - Given: impl コミットが test コミットより先行している（実装が先・test が後）
  - When: `check_red_evidence <test-commit> <impl-commit>` を実行する
  - Then: 非0 exit を返す

- [x] [regression] AT-334-A4: 空入力・破損入力は fail-closed（fail-safe）
  - Given: test/impl コミット引数が空、または red 証跡行が空 exit・改行・引用符混入で破損している
  - When: `check_red_evidence` / `record_red_evidence` を実行する
  - Then: 非0 exit を返し、破損行を dark に書かない（既存 `record_iteration` の fail-closed 規約と同型）

- [x] [regression] AT-334-A5: satisfaction oracle が5項 AND で redObserved を含む
  - Given: `skills/autopilot/SKILL.md` の impl phase オラクル定義
  - When: オラクル式を読む
  - Then: `AND(redObserved, atGreen, coverageOk, overall_correctness == "correct", confirmed P0/P1 == 0)` であり、redObserved が deterministic（exit code 由来）かつ AL-3 green ゲートの対であると明記されている

## AT-334-B: test/impl コミット分離による red→green の機械検証（F2）

- [x] [regression] AT-334-B1: running-atdd-cycle が test/impl コミット分離を必須化する
  - Given: `skills/running-atdd-cycle/SKILL.md` の Flow（C2 RED-first）
  - When: ステップ2「Confirm RED」周辺を読む
  - Then: test を含むコミットと impl コミットの分離が必須として記述され、コミット履歴から red→green 粒度が機械検証できる根拠であることが明記されている

## AT-334-C: Gate③後フィードバックの正規ルート（F3）

- [x] [regression] AT-334-C1: iron-law に規模分岐ルートが明文化されている
  - Given: `docs/methodology/autopilot-iron-law.md`
  - When: Gate③後フィードバックの節を読む
  - Then: 「Gate③後の新ACは直接実装しない」「小（設計アンカー不変）= 同一Issue内 design 差し戻し / 大（設計アンカー変更を伴う）= 新Issue」「一次基準は設計アンカー変更の有無」が記述されている

- [x] [regression] AT-334-C2: overview が iron-law を正典参照する（陳腐化防止）
  - Given: `docs/methodology/autopilot-overview.md`
  - When: ライフサイクル節を読む
  - Then: Gate③後ルートの要約があり、正典として iron-law を参照している（両ドキュメントが独立に乖離しない相互参照）

## AT-334-D: 効率は test-first 逸脱の理由にしない（C2）

- [x] [regression] AT-334-D1: iron-law に効率逸脱禁止が正典として明記
  - Given: `docs/methodology/autopilot-iron-law.md`
  - When: 該当節を読む
  - Then: 「効率（session limit / トークン / 速さ）は test-first 逸脱（red 先行スキップを含む）の理由にしない」が文言として存在する

- [x] [regression] AT-334-D2: rules が正典を参照しつつバジェット維持
  - Given: `rules/atdd-kit.md`
  - When: Iron Laws / Workflow 節を読む
  - Then: 効率逸脱禁止の参照が存在し、かつ全体行数が 60 行以下のバジェットを維持している（invariant; 行数を exact-pin しない）

## AT-334-E: リリース整合（invariant 回帰）

- [x] [regression] AT-334-E1: バージョンと CHANGELOG が整合
  - Given: `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: バージョンと最上位リリース見出しを照合する
  - Then: plugin.json の version が CHANGELOG 最上位リリース見出しと一致する（特定バージョン値を固定しない invariant）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
