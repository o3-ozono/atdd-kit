# User Stories: 全 Skill の SKILL.md ローダー stub 分割（行数バジェット恒久対策）— research

> 本 Issue は research（方針＋計画確立）。成果物は `docs/methodology/skill-loader-split.md`（仮）。
> 各 Story は PRD `## What` 1-6 に対応し、実装（実際の分割）は派生 Issue が担うため、
> 各 Story の境界は「方針・計画・影響分析まで」で閉じる（PRD `## Non-Goals` を Story 境界に反映）。

## Functional Story

<!-- 各 Functional Story は PRD ## What の項目に 1:1 で対応。goal は research 成果物に書く内容、reason は派生実装 Issue が得る恩恵で記述する。 -->

### FS-1 標準分割パターン設計（PRD What 1）

**I want to** SKILL.md を「薄いローダ/エントリ stub」と「`docs/methodology/<skill>-*.md` の本体詳細」に分ける標準分割パターンと、stub に残すもの／分離するものの基準を確立する,
**so that** 各 Skill を個別 Issue で対症的に分割せず、autopilot 先例に統一された一貫した手順で分割できる.

- 境界: パターン定義と基準の文書化まで。実際の SKILL.md 改変は本 Issue 対象外（PRD Non-Goal「各 Skill の実際の分割実装」）。

### FS-2 全 Skill 棚卸し表（PRD What 2）

**I want to** 各 Skill の現行行数・pin 上限・budget 逼迫度ランキング・分割優先度を一覧化した棚卸し表を作る,
**so that** どの Skill から分割すべきかをデータに基づいて判断でき、優先度順に派生 Issue を起票できる.

- 境界: 棚卸しと優先度付けまで。分割実装は別 Issue。
- **未解決スコープ（PRD Open Question 3）**: 逼迫度しきい値・適用優先度の具体は research 実施中に確定する。本 Story はこの open question を明示的に保持し、棚卸し表内でしきい値・優先度を確定 or 未確定として記録する（FS-6 と連動）。

### FS-3 i18n / language policy・既存 AT 影響分析（PRD What 3）

**I want to** 分割が string-pin 系 AT・テンプレート同期・行数 pin テストに与える影響と対応方針を分析する,
**so that** 派生実装 Issue が分割時に既存 AT を壊さず、i18n / language policy（English-only LLM-facing）を維持できる.

- 境界: 影響分析と対応方針まで。AT の実改修は別 Issue。

### FS-4 #304 / autopilot との関係づけ（PRD What 4）

**I want to** autopilot を reference implementation に位置づけ、#304（個別分割・merge 済）を先行事例として参照整理する,
**so that** 標準パターンが「既に動いている実例」に裏付けられ、派生 Issue が手本として参照できる.

- 境界: 参照のみ。autopilot の再分割は対象外（PRD Non-Goal）。

### FS-5 DEVELOPMENT.md line-budget ルール整合（PRD What 5）

**I want to** 分割後の pin 運用（stub budget・分離先 budget の pin 方法）を DEVELOPMENT.md の line-budget ルール（2 回までの raise・3 回目で分割）と整合させる,
**so that** 分割後も pin 運用が DEVELOPMENT.md ルールと矛盾せず、将来の budget 衝突を恒久的に回避できる.

- 境界: 整合確認まで。DEVELOPMENT.md ルール自体の改定は対象外（PRD Non-Goal）。

### FS-6 適用計画（PRD What 6）

**I want to** 優先度順の適用順序（どの Skill をどの順で分割するか・各々別 Issue 群として）を計画化する,
**so that** research 結論を受けた実装フェーズが、優先度の高い Skill から順に派生 Issue として迷わず着手できる.

- 境界: 計画立案まで。実装は派生 Issue 群。
- **未解決スコープ（PRD Open Question 3）**: 適用優先度の具体は FS-2 の逼迫度しきい値確定に依存する。本 Story はこの open question を明示的に引き継ぎ、適用順序を「しきい値確定後に最終化」する形で計画へ反映する。

## Constraint Story (Non-Functional)

<!-- PRD ## Outcome / ## What 末尾の構造 bats ピン要件・## Non-Goals から導出した品質制約。 -->

### CS-1 成果物の構造ピン（PRD What 末尾「構造 bats でピン」）

**I want to** 成果物 `docs/methodology/skill-loader-split.md` が構造 bats でピンされている（English-only / README 登録 / Loaded-by メタを検証）,
**so that** methodology doc の構造が回帰で守られ、後続の編集が必須メタを欠落させない.

### CS-2 実装非混入（PRD Outcome / Non-Goals: 実装は別 Issue）

**I want to** 本 Issue の成果物が方針＋計画（design doc 相当）に限定され、いかなる Skill の SKILL.md 実改変も含まない,
**so that** research フェーズと実装フェーズが明確に分離され、未承認の本番コード変更がレビュー範囲に紛れ込まない.

### CS-3 language policy 準拠（DEVELOPMENT.md: LLM-facing は English-only）

**I want to** LLM-facing な methodology doc が English-only で、`*.ja.md` 翻訳を持たない,
**so that** DEVELOPMENT.md の language policy に準拠し、翻訳同期の負債を発生させない.
