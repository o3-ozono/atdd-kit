# Plan: ATDD の test-first（AT red 先行）を構造的に担保する

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。 -->

User Stories（`user-stories.md`）の F1/F2/F3/C1/C2 を実装する。設計の中核は **「red 証跡」を LLM の自律判断ではなく deterministic な信号（コミット分離＋当時の red exit）から導く** こと。設計上のトレードオフ（red 証跡の記録媒体の選択）は `design-doc.md` に記録した。

スコープ:

- **A（F1/F2/C1）** = `lib/autopilot_convergence.sh` に red ゲート判定関数を追加し、autopilot 影響度オラクル（`skills/autopilot/SKILL.md` AL-3 周辺）に `redObserved` 項を AND 配線。`running-atdd-cycle` の手順に test/impl コミット分離を必須化。
- **B（F3）** = `docs/methodology/autopilot-iron-law.md` ＋ `docs/methodology/autopilot-overview.md` に Gate③後フィードバックの正規ルート（規模分岐）を明文化。
- **C（C2）** = Iron Law を正典、`rules/atdd-kit.md` から参照する形で「効率は test-first 逸脱の理由にしない」を明記。

## Implementation

### A. 決定的 red ゲート（F1 / F2 / C1）

- [ ] `lib/autopilot_convergence.sh` に `check_red_evidence <test-commit-sha> <impl-commit-sha>` 関数を追加する。新規 AT について、test コミットが impl コミットより祖先（先行）であり、かつ test コミット時点で当該 AT が red（非0 exit）だった証跡が記録されている場合のみ exit 0 を返す。証跡欠如・順序逆転・空入力は fail-closed（非0）とする
- [ ] verify: `bash -c 'source lib/autopilot_convergence.sh; check_red_evidence <tc> <ic>'` が、red 証跡あり＋順序正で 0、欠如/逆転/空で 非0 を返す（後述 AT-334-A で機械検証）

- [ ] red 証跡の記録媒体を確定する: `record_red_evidence` で red exit を JSONL 監査ログとは別の `red.jsonl`（または既存 JSONL の `step=red` 行）に追記する関数を `lib/autopilot_convergence.sh` に追加する。記録は `record_iteration` と同じ fail-closed 規約（空 fingerprint 拒否・改行/引用符拒否）を踏襲する
- [ ] verify: `record_red_evidence` 呼び出し後に red 行が1行追記され、空 exit/改行混入が refuse される（既存 `record_iteration` のセキュリティ BATS と同型のケースで検証）

- [ ] `skills/autopilot/SKILL.md` の satisfaction oracle（現 `AND(atGreen, coverageOk, overall_correctness, P0/P1==0)`）に `redObserved`（deterministic）項を追加し `AND(redObserved, atGreen, coverageOk, overall_correctness, P0/P1==0)` にする。impl phase のみ発火し、AL-3（green）と対称な deterministic gate であることを明記する
- [ ] verify: `grep -q 'redObserved' skills/autopilot/SKILL.md` かつ oracle 行が5項 AND になっている（AT-334-A）

- [ ] `skills/autopilot/SKILL.md` のフロー（deterministic AT gate の節）に「red ゲートは AL-3 green ゲートの対。red 証跡が無い限り redObserved=false で oracle は満たされない」を1段落で明記する
- [ ] verify: red ゲートが green ゲートと対であることが SKILL.md 本文に存在する

- [ ] `skills/running-atdd-cycle/SKILL.md` の Flow ステップ2（Confirm RED）に、test コミットと impl コミットの**分離を必須化**する文言を追加する（test を含むコミット → red 観測 → 別コミットで impl）。C2 説明にもコミット分離が red→green の機械検証根拠であることを追記する
- [ ] verify: `grep -qE 'commit' skills/running-atdd-cycle/SKILL.md` で test/impl コミット分離の記述が存在し、ステップ2が「分離」を要求している（AT-334-B）

### B. Gate③後フィードバックの正規ルート（F3）

- [ ] `docs/methodology/autopilot-iron-law.md` の AL-1（または AL-6 付近）に「Gate③（merge）後のユーザー実機フィードバックで新ACが生じたら直接実装しない。規模で分岐: 小（設計アンカー不変・少数AC）= 同一Issue内 design 差し戻し / 大（設計アンカー変更を伴うまとまった新機能）= 新Issue」を明文化する。一次基準は「設計アンカー（pin）変更を伴うか」とする
- [ ] verify: iron-law に「Gate③」「新AC」「design 差し戻し」「新Issue」「設計アンカー」の分岐記述が存在する（AT-334-C）

- [ ] `docs/methodology/autopilot-overview.md` の該当ライフサイクル節に B のルートを1段落で追記し、正典は iron-law、overview は要約参照とする（ドキュメント二重化による陳腐化を避ける相互参照）
- [ ] verify: overview に Gate③後ルートの要約があり iron-law を参照している

### C. 効率は逸脱理由にしない（C2 / 横断ルール）

- [ ] `docs/methodology/autopilot-iron-law.md` に「効率（session limit / トークン / 速さ）は test-first 逸脱（red 先行スキップを含む）の理由にしない」を正典として明記する（AL-3 / red ゲートの節、または「Why these overrides are legitimate」節の近傍）
- [ ] verify: iron-law に「効率」「test-first」「逸脱」を含む禁止文言が存在する（AT-334-D）

- [ ] `rules/atdd-kit.md` の Iron Laws または Workflow（既存「Test-first, always.」行の近傍）から、上記の正典文言を1行で参照する。60行バジェットを超えないよう既存行に追記する形にする
- [ ] verify: `wc -l rules/atdd-kit.md` が 60 行以下を維持し、効率逸脱禁止の参照が存在する（AT-334-D / 既存バジェット BATS）

## Testing

- [ ] `tests/test_autopilot_convergence.bats` に `check_red_evidence` / `record_red_evidence` の deterministic 判定テストを追加する（red 証跡あり=0 / 欠如・逆転・空=非0、改行/引用符 refuse）
- [ ] verify: `bats tests/test_autopilot_convergence.bats` が green

- [ ] `tests/test_autopilot_skill.bats` に oracle 5項 AND（`redObserved` 含む）と red=green 対称ゲートの構造アサーションを追加する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が green

- [ ] `tests/test_running_atdd_cycle_skill.bats` に test/impl コミット分離の要求アサーションを追加する（C2 RED-first テストの拡張）
- [ ] verify: `bats tests/test_running_atdd_cycle_skill.bats` が green

- [ ] iron-law / overview / rules の文言を機械検証する BATS（既存 methodology テスト or 新規 `tests/test_iron_law_doc.bats`）に B・C の grep アサーションを追加する
- [ ] verify: 該当 BATS が green

## Finishing

- [ ] `CHANGELOG.md` の `[Unreleased]` に red ゲート / Gate③後ルート / 効率逸脱禁止の追加を Keep a Changelog 形式（### Added / ### Changed）で記載する
- [ ] verify: `[Unreleased]` にエントリが存在する

- [ ] `.claude-plugin/plugin.json` のバージョンを minor bump する（新ゲート＝新機能 / skill rename なし → minor）。現 3.28.1 → 3.29.0
- [ ] verify: `plugin.json` version が CHANGELOG 最上位リリース見出しと整合する（invariant; 数値固定しない）

- [ ] 影響ディレクトリの README 整合（`lib/` に新関数追加なら該当 README、`scripts/` 同様）と DEVELOPMENT ルール（skill 変更の BATS 前後 green）を確認する
- [ ] verify: 関連ドキュメント・README が変更内容と整合している
