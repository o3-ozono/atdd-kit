# Plan: 全 Skill の SKILL.md ローダー stub 分割（行数バジェット恒久対策）— research

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

> 本 Issue は research（方針＋計画確立）。唯一の成果物は `docs/methodology/skill-loader-split.md`。
> いかなる Skill の SKILL.md 実改変も含まない（PRD Non-Goals / CS-2）。実装（実際の分割）は派生 Issue 群が担う。
> 各 `## Implementation` タスクは methodology doc の 1 セクションを書く操作に対応し、FS-1〜FS-6 / CS-1〜CS-3 に紐づく。

## Implementation

<!-- FS-1 標準分割パターン設計 -->
- [ ] `docs/methodology/skill-loader-split.md` を新規作成し、冒頭に `> **Loaded by:**` メタコメント（参照元 Skill / 派生 Issue 群）と H1 見出しを置く
- [ ] verify: `head -3 docs/methodology/skill-loader-split.md` に `> **Loaded by:**` が含まれ、`grep -P '[ぁ-んァ-ヶ一-龥]'` が冒頭メタにヒットしない（English-only・CS-3）

- [ ] 「## Split Pattern」節を書く: SKILL.md = 薄いローダ stub、本体詳細 = `docs/methodology/<skill>-*.md`。stub に残すもの（frontmatter / Trigger / Input / Output / 各 detail doc への参照ポインタ）と分離するもの（手順詳細・ガード本文・表）の基準を明文化（FS-1）
- [ ] verify: 当該節に「stub に残す」基準と「分離する」基準の両方が箇条書きで列挙され、参照ポインタ形式（`docs/methodology/<skill>-*.md` を `grep -qF`）が例示されている

- [ ] autopilot 先例（#283/#304）を split pattern の reference implementation として明記: autopilot SKILL.md → `autopilot-iron-law.md` / `autopilot-design-gate.md` / `route-eligibility.md` / `autopilot-overview.md` への分離実例を表で示す（FS-4）
- [ ] verify: 当該節が `autopilot-iron-law.md` 等の実在 detail doc 名を列挙し、各行が「SKILL.md 側のポインタ ↔ 分離先 doc」の対応になっている

<!-- FS-2 全 Skill 棚卸し表 -->
- [ ] 「## Skill Inventory」節に全 20 Skill の棚卸し表を書く: 列 = Skill / 現行行数 / pin 上限（無い場合は "none"）/ headroom / 逼迫度ランク。autopilot=279/280、session-start=231/none、reviewing-deliverables=228/240 を含む（FS-2）
- [ ] verify: 表に 20 行（全 SKILL.md）が存在し、`for f in skills/*/SKILL.md; do wc -l $f; done` の実測値と現行行数列が一致する

- [ ] 逼迫度しきい値を確定して節に明記し（PRD Open Question 3 / FS-2）、各 Skill を CRITICAL / HIGH / MEDIUM / LOW に分類する（しきい値 = headroom 行数および pin 有無で定義）
- [ ] verify: しきい値の数値定義が文章で明示され、各 Skill 行の逼迫度ランクがそのしきい値定義から機械的に導ける

- [ ] session-start（231 行・budget pin 無し）を「pin 未設置の逼迫リスク」として明示的に記録し、棚卸し表の備考に反映（FS-2 finding）
- [ ] verify: 棚卸し節に session-start の "no pin" が明記され、`grep -rn 'session.start' tests/*.bats` に line-budget pin が無いこと（=未ガード）が裏付けとして記述されている

<!-- FS-3 i18n / language policy・既存 AT 影響分析 -->
- [ ] 「## Impact Analysis」節を書く: 分割が (a) string-pin 系 AT、(b) テンプレート同期、(c) 行数 pin テストに与える影響と対応方針を 3 観点で整理（FS-3）
- [ ] verify: 3 観点すべてが小見出しまたは表で区別され、各々に「影響」と「対応方針」が対で記述されている

- [ ] 既存 string-pin 移行ルールを明記: SKILL.md 側でガードしていた BATS 検証文字列が detail doc へ移る場合、両テストの pin を棚卸しし `@covers` を分離先へ広域化する（MEMORY #304 教訓の一般化）（FS-3）
- [ ] verify: 当該対応方針に「分離元・分離先の両 pin 棚卸し」と「@covers の付け替え／広域化」が明記されている

<!-- FS-5 DEVELOPMENT.md line-budget ルール整合 -->
- [ ] 「## Pin Operation」節を書く: 分割後の pin 運用 — stub budget pin（縮小後の上限）と分離先 doc の構造 pin（Loaded-by / English-only / README 登録）を DEVELOPMENT.md「2 回まで raise・3 回目で分割」ルールと整合させる（FS-5）
- [ ] verify: 当該節が DEVELOPMENT.md の該当ルール（SKILL.md Line-Budget Raises / 3 回目で loader stub 分割）を引用し、分割後の stub・detail 双方の pin 設置方針を述べている

<!-- FS-6 適用計画 -->
- [ ] 「## Rollout Plan」節を書く: FS-2 のしきい値・逼迫度ランクに基づく優先度順の適用順序（各 Skill = 別派生 Issue）を表で計画化。session-start の pin 設置を含む（FS-6）
- [ ] verify: 適用順序が逼迫度ランク降順で並び、各行に「対象 Skill / 推定派生 Issue スコープ / 前提依存」が記載され、FS-2 しきい値への依存が明記されている

## Testing

<!-- CS-1 構造ピン: 既存 test_phase_test_policy.bats（AT-300〜AT-312）が methodology doc 構造 pin の先例。
     実テストファイルの作成は running-atdd-cycle（Step 4）が担う。本 plan は AT 設計まで。 -->
- [ ] acceptance-tests.md に CS-1（構造 pin: Loaded-by / README 登録 / English-only）の AT を `[planned]` で起票し、`test_phase_test_policy.bats` の AT-311/AT-312 系を pin の手本として明記（CS-1 / CS-3）
- [ ] verify: acceptance-tests.md に Loaded-by メタ・README 登録・日本語不在（English-only）を検証する AT が各 1 件以上存在し、各 Then が `grep`/`head` で機械検証可能な表現になっている

- [ ] CS-2（実装非混入）の AT を `[planned]` で起票: 本 Issue の diff が `skills/*/SKILL.md` を 1 行も変更しないことを検証する regression を設計（FS 各境界の総括ガード）
- [ ] verify: acceptance-tests.md に「`git diff main...HEAD -- skills/` が空である」型の AT が存在し、不変条件（invariant）として書かれている（point-in-time pin でない）

## Finishing

- [ ] `docs/methodology/README.md` の Documents 表に `skill-loader-split.md` 行を追記する（DEVELOPMENT.md Directory READMEs ルール）
- [ ] verify: `grep -q 'skill-loader-split' docs/methodology/README.md` が成功し、README が English-only（`grep -P '[ぁ-んァ-ヶ一-龥]'` で日本語不在）を維持

- [ ] ドキュメント整合性チェック（CHANGELOG エントリ・本 research の結論と PRD/US の整合）
- [ ] verify: methodology doc が PRD `## What` 1-6 と US FS-1〜FS-6 / CS-1〜CS-3 を漏れなくカバーし、Non-Goals（実装混入なし）に反する記述が無い
