# User Stories: skill テスト体系の再定義（#222）

> 注: B2 (#189 extracting-user-stories skill) 未実装期間の手動代行。形式は `templates/docs/issues/user-stories.md` + `persona 抜き Connextra` 規約に準拠。

## Functional Stories

### FS-1: 2 層体系への統一と旧用語廃止

**I want to** skill テストを **Unit Test (claude 呼ばない BATS)** と **Skill E2E Test (実 claude 起動)** の 2 層に統一し、旧用語 (SAT / L1-L3 / Fast / Integration) を CHANGELOG.md 以外から全廃したい,
**so that** レビュー基準が安定し、用語の混乱が再発しない。

### FS-2: 影響範囲算定ロジック

**I want to** 変更ファイルから影響を受ける skill を path-based マッピング（`skills/<X>/` → 対応 E2E、`rules/` `templates/` `methodology/` → 全 E2E、`lib/` `scripts/` → 利用元 skill の E2E）で自動算定したい,
**so that** 手動でテスト対象を選ぶ手間と漏れがない。

### FS-3: 専用 runner

**I want to** `scripts/run-skill-e2e.sh` 1 コマンドで影響範囲分の Skill E2E Test を実行しログ（対象一覧 / PASS-FAIL / git SHA / timestamp）を生成したい,
**so that** reviewer 引き渡し前の証跡作成が機械化される。

### FS-4: 証跡コメント必須化

**I want to** PR コメントに最新 git SHA の Skill E2E Test all green ログが貼付されている状態を reviewing-deliverables 引き渡しの強制ゲートにしたい,
**so that** 古いログや嘘 check による merge を防げる。

### FS-5: 1 skill = 1 E2E ファイル / 1 US = 1 case 構造

**I want to** Skill E2E Test を 1 skill = 1 ファイル、内部に `@test "I want to X, so that Y"` で 1 User Story = 1 case の構造で書きたい,
**so that** SKILL.md と E2E の対応が構造的に明示される。

### FS-6: 関連 Issue AC 再記述

**I want to** 本 Issue 結論を #204 (evals 廃止) / #207 (docs 更新) / #208 (CI 整備) / #196 (SAT 揃い検証) の AC に反映する更新案を提示したい,
**so that** epic #179 の整合性が保たれる。

## Constraint Stories (Non-Functional)

### CS-1: evals 廃止整合

In order to **keep epic #179 Step E3 (#204) 整合**, the system must `evals/evals.json` (skill-creator 互換) 系の存続を仮定しない（Skill E2E Test に一本化）。

### CS-2: 古いログ / bypass 不可

In order to **嘘 check や古いログでの merge を構造的に防ぐ**, the system must Skill E2E Test ログを「最新 git SHA との一致」で機械的に検証可能にする。

### CS-3: 時間効率

In order to **atdd-kit maintainer の作業効率を保つ**, the system must 影響範囲外の Skill E2E Test を実行しない（全実行は共有資材 (`rules/` `templates/` `methodology/`) 変更時のみ）。
