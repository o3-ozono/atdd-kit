# Plan: User gate を選択肢提示（ワンタップ承認）にする

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

<!-- 設計方針:
     - 既存の `docs/guides/skill-authoring-guide.md` で確立済みの AskUserQuestion + Recommended パターン
       （header ≤12 文字 / options 2-4 / label ≤5 語 / Other 自動付与 / `Recommended: ... — reply 'ok'` 行で bats 後方互換）を
       3 つの User gate にそのまま適用する。新パターンの発明ではなく既存パターンの横展開。
     - 承認/差し戻しの意味論（非 `ok` = 全体差し戻し＋セクション単位 finding 化、部分承認は承認ではない）は不変。
       変えるのは提示方法のみ（PRD Non-Goals / AL-1）。
     - selection UI そのものの実装はしない（harness 提供ツール）。スキル側のゲート記述を合わせるのみ。

     ## 制約: autopilot SKILL.md ライン・バジェット枯渇（review finding #1, P1）
     - `skills/autopilot/SKILL.md` は現在 279/280 行（headroom 1 行）。`tests/test_autopilot_skill.bats:131` の `≤280` ピンは
       DEVELOPMENT.md:59-61 で許される「2 回まで」の昇格を既に消費済み（240→260 #254 / 260→280 #275）。3 回目の昇格は禁止。
     - 設計承認ゲートの AskUserQuestion オプションブロック・Recommended 行・Other 取り扱い prose（タスク 3/4/6）は現実的に
       10-20 行を autopilot SKILL.md に追加し、280 を超過する。第 3 の昇格は不可のため、唯一の remediation は
       DEVELOPMENT.md:61 が定める「loader stub + `docs/methodology/` 詳細 doc への分割」（#283）。
     - したがって本 plan は autopilot SKILL.md の設計承認ゲート詳細を `docs/methodology/autopilot-design-gate.md`（新規）へ切り出し、
       SKILL.md 本体は当該 doc を参照する loader stub に留める。この分割により autopilot SKILL.md は 280 行以下を維持し、
       AskUserQuestion 形式の設計承認ゲート記述は詳細 doc 側に置く。bats の `≤280` ピンは変更しない（昇格しない）。

     ## 制約: マージゲートの位置（review finding #2, P1）
     - 現行設計のマージゲートは HUMAN の判断であり、autopilot が near-green Issue を引き渡し人間が merge する（AL-1 / autopilot SKILL.md:12,38,68,273）。
     - `merging-and-deploying` には現在 in-skill の承認質問は無い。Flow は precondition check（PASS+CI green）→ squash-merge であり、
       唯一の prompt は Trigger レベルの `Run merging-and-deploying skill on <issue>? Y/n`（SKILL.md:12-15）。
     - PRD Non-Goals「ゲートの増減は行わない / 承認・差し戻しの意味論の変更は行わない」と整合させるため、本 plan は
       **新しい in-skill ゲートを追加しない**。マージ選択は既存の Trigger レベル `Y/n` confirm をそのまま使い、その提示を
       選択肢（「(Recommended) マージ」「保留（レビュー継続）」）として表現するのみ（presentation-only）。
       既存の Trigger `Y/n` と二重化しないよう、`Y/n` 文を AskUserQuestion 形式に**置換**し、新規 Flow ステップは設けない。
       autopilot 側のマージは従来どおり人間ハンドオフのままで、autopilot SKILL.md には新ゲートを追加しない。 -->

## Implementation

- [ ] `defining-requirements` SKILL.md の要件承認ゲート（Step 10「Approval gate」`Approve PRD? Reply 'ok' ...`）を AskUserQuestion 形式に書き換える: header「Approve PRD?」、options 第一に「(Recommended) 承認 (ok)」、続けて「Problem を修正」「Outcome を修正」「スコープを変更」、`multiSelect: false`
- [ ] verify: `grep -q 'AskUserQuestion' skills/defining-requirements/SKILL.md` かつ第一選択肢が `(Recommended)` 付き承認である

- [ ] 同ゲートに `Recommended: 承認 (ok) — reply 'ok' to accept, or name a section to revise` 行を残し、selection UI 非対応チャネルでは従来の `ok` テキスト入力にフォールバックする旨を 1 文で明記する
- [ ] verify: `grep -qiE 'recommended.*ok' skills/defining-requirements/SKILL.md` が一致し、フォールバック文言が存在する

- [ ] （finding #3, P2 トレーサビリティ）要件承認ゲートの選択肢提示化は `defining-requirements` のみで行う。autopilot の Gate ① は独自の要件質問を出さず `defining-requirements`（壁打ち）を再利用するため、autopilot 側に別の要件承認ゲートは存在しない旨を 1 文で明記する（AL-1 トレーサビリティ。例:「autopilot Gate ① は defining-requirements に委譲し、autopilot 独自の要件承認ゲートは存在しない」）
- [ ] verify: autopilot の Gate ① が defining-requirements に委譲し別の要件承認ゲートが無い旨の注記が plan / SKILL.md いずれかに存在する（grep で「Gate ①」「defining-requirements に委譲」相当の記述を確認）

- [ ] （finding #1, 先行タスク）autopilot SKILL.md のライン・バジェット枯渇に対応するため、設計承認ゲートの詳細を `docs/methodology/autopilot-design-gate.md`（新規）へ切り出し、SKILL.md 本体を当該 doc 参照の loader stub に留める分割を行う（DEVELOPMENT.md:61 / #283、第 3 の昇格はしない）
- [ ] verify: `wc -l < skills/autopilot/SKILL.md` が 280 以下であり、`docs/methodology/autopilot-design-gate.md` が存在し autopilot SKILL.md からリンク参照されている。`tests/test_autopilot_skill.bats:131` の `≤280` ピンは未変更

- [ ] `autopilot` 設計承認ゲート（Flow Step 3、`設計成果物（user-stories / plan / acceptance-tests）を承認しますか? 'ok' で ...`）を AskUserQuestion 形式に書き換える（記述は loader stub から切り出した `docs/methodology/autopilot-design-gate.md` 側に置き、SKILL.md からは参照する）: header「Approve design?」、options 第一に「(Recommended) 承認 (ok)」、続けて「User Stories を修正」「Plan を修正」「Acceptance Tests を修正」、`multiSelect: false`
- [ ] verify: `grep -q 'AskUserQuestion' docs/methodology/autopilot-design-gate.md`（または autopilot SKILL.md）かつ設計ゲート文言に 3 つの成果物別差し戻し選択肢が含まれ、autopilot SKILL.md は依然 280 行以下

- [ ] 設計承認ゲートの記述に、非 `ok`（部分承認含む）は全体差し戻し＋セクション単位 finding 化という現行ロジックがそのまま適用される旨を維持・明記する（意味論は不変、選択結果を既存ロジックへマッピング）
- [ ] verify: 全体差し戻し・セクション単位 finding 化・部分承認は承認ではない、の 3 記述が設計ゲート節（loader stub または切り出し doc）に残存している

- [ ] （finding #2）`merging-and-deploying` SKILL.md の**既存の Trigger レベル confirm**（Trigger 節 `Run merging-and-deploying skill on <issue>? Y/n`、SKILL.md:12-15）を AskUserQuestion 形式に**置換**する: header「Merge?」、options 第一に「(Recommended) マージ」、続けて「保留（レビュー継続）」、`multiSelect: false`、`Recommended: ... — reply 'ok'` 行付き。**新しい in-skill Flow ゲートは追加しない**（既存の Y/n confirm の提示方法を変えるだけ。Flow の precondition check → squash-merge は不変）。autopilot 側のマージは従来どおり人間ハンドオフのまま（autopilot SKILL.md に新ゲートを追加しない）
- [ ] verify: `grep -q 'AskUserQuestion' skills/merging-and-deploying/SKILL.md` かつ「マージ」「保留」両選択肢が存在し、置換前の `Y/n` テキスト confirm 文言が二重に残っていない（既存 confirm を置換、ゲートを増やしていない）。Flow 節に新規承認質問ステップが追加されていない

- [ ] 3 ゲート共通で「Other（自由記述）」が harness 自動付与であり手動追加しない旨、および Other 選択時は自由記述をそのまま現行の自然言語フィードバック経路に流す旨を各ゲート記述で担保する（skill-authoring-guide (c)/(f) と整合）
- [ ] verify: 各ゲートで Other を手動列挙していない（skill-authoring-guide 準拠）かつ自由記述経路維持の記述がある

- [ ] `docs/guides/skill-authoring-guide.md` (f)「Key Decision Points by Skill」に 3 つの User gate（要件承認・設計承認・マージ）を decision point として追記する
- [ ] verify: skill-authoring-guide の (f) に autopilot 設計承認ゲートと merging-and-deploying マージゲートの行が追加されている

## Testing

- [ ] bats に各ゲートのアサーションを追加する（既存 `test_question_design_migration.bats` の AskUserQuestion/Recommended grep 規約に倣う）: 3 ゲートの SKILL.md が AskUserQuestion を含み、第一選択肢が承認/マージで、`recommended.*ok` 行を持つこと
- [ ] verify: 追加 bats が green（`bats tests/test_defining_requirements_skill.bats tests/test_autopilot_skill.bats tests/test_merging_and_deploying_skill.bats tests/test_question_design_migration.bats` がパス）

- [ ] フォールバック・意味論不変・AL-1 不変のアサーションを追加する（非 `ok` 全体差し戻しロジックの記述存続、ゲート数 3 のまま増減なし）
- [ ] verify: フォールバック文言・意味論記述・ゲート数不変の bats がパスする

- [ ] （finding #4, P2 AT-006 のテスト設計）ゲート数不変（AL-1）は per-skill grep ではなく、ゲートを実際に**カウント**する既存メカニズムで担保する。具体的には `tests/test_autopilot_skill.bats:339-347` の「`## User gates` 節内の番号付き項目（`^[0-9]+\. `）を数えて `== 3`」アサーションを維持し、4 つ目のゲート（finding #2 のマージゲート挿入リスク）が混入したら fail することを確認する。selection UI 化で番号付きゲート項目数が 3 から変化しないことを同テストで検証する（merging-and-deploying 側は Trigger confirm の置換であり新ゲート項目を増やさない、と finding #2 で確定済み）
- [ ] verify: `bats tests/test_autopilot_skill.bats` の「gates stay exactly three」テスト（`## User gates` 節の番号付き項目カウント == 3）がパスし、意図的に 4 つ目のゲート行を加えると fail することを手動確認した（カウント機構が実際に効いている）

- [ ] 既存スキル bats スイート全体を実行し、変更が既存の構造ピン（行数バジェット等）を壊していないことを確認する。特に autopilot SKILL.md の `≤280` ピン（`test_autopilot_skill.bats:131`）は loader stub 分割（finding #1）により未昇格のまま green を維持すること
- [ ] verify: `bats tests/` が green。autopilot SKILL.md が 280 行以下（finding #1 の分割が効いており、第 3 の昇格なしで line-budget assertion がパス）

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を minor bump し、`CHANGELOG.md` に Keep a Changelog 形式でエントリを追加する（既存ゲートへの選択肢提示の追加 = minor）
- [ ] verify: version が CHANGELOG 最新見出しと一致する（`scripts/check-plugin-version.sh` 相当の整合）

- [ ] ドキュメント整合性チェック: `skills/README.md` のスキル一覧不変確認、新規 `docs/methodology/autopilot-design-gate.md`（finding #1 分割）を `docs/methodology/README.md` の一覧に追記、変更した `docs/` と SKILL.md の相互整合、README/README.ja 同期の要否確認
- [ ] verify: 関連ドキュメントが変更内容と整合し、DEVELOPMENT.md の README 更新ルール（変更した top-level dir の README 更新）を満たしている。`docs/methodology/README.md` に新規 doc のエントリが存在する
