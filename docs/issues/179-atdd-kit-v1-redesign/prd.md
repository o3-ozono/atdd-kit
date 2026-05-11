# PRD: atdd-kit v1.0 構造再設計

> Issue: #179
> 作成日: 2026-05-08
> 担当: @o3-ozono

## Problem

現行 atdd-kit は **autopilot の快適性を優先した結果、開発・レビューしにくい状態になっている**。

具体的には:

- `discover` skill が **787 行**に肥大化（superpowers の中央値 ~150 行に対して 5 倍）
- `plan` skill が **385 行**
- `tests/test_autopilot_*.bats` が **20+ ファイル**で skill 1 個に対するテストが発散
- phase-name skill (`discover` / `plan` / `atdd` / `verify` / `ship`) が autopilot に従属し、単体で完結しない
- レビュー単位が phase ではなく autopilot 全体になりがちで、PR が大きくレビューしにくい
- `evals/` システムが skill ごとに分散しメンテ負荷が高い

これは「autopilot が中央集権 orchestrator として全 phase を駆動する」という設計判断の hard limit が顕在化した状態。

## Why now?

3 つの外部要因が揃っているため、今が再設計のタイミング:

1. **適用先プロジェクトでの dogfood 知見が蓄積** — atdd-kit を実プロジェクトに適用した結果、「制約 Story」「Robot Pattern + XCTContext.runActivity」「testplan 分離による draft → green lifecycle」などの具体的設計パターンが確立した。
2. **superpowers の skill 設計思想がコミュニティ標準として確立** — capability-name / 中央値 ~150 行 / orchestrator なし / Integration セクションでの handoff など、参照すべき型が明確化。
3. **採用する ATDD 解釈の固定** — concrete examples / draft → green / TDD inner ネスト / Agile Testing Quadrants の Q2 が atdd-kit の根本指針として確定。これに合わせた構造の再設計が必須。

## Audience

| Primary | Secondary |
|---------|-----------|
| **atdd-kit の開発者** (自分、@o3-ozono) | atdd-kit を適用するプロジェクトの開発者 |

## Outcome / Success

完了時に以下の状態が達成されている:

- **フロー駆動 6 skill (capability-name) で各 step が独立してレビューしやすい**
  - 各 SKILL.md が ~200 行以内に収まる
  - skill 単体で完結し、autopilot のような orchestrator に依存しない
- **`docs/issues/NNN/` で成果物が Issue ごとにまとまる**
  - 1 Issue = 1 ディレクトリ = 5 種類の artifact (prd / user-stories / plan / acceptance-tests / 任意の design-doc)
- **並列 worktree / multi-session で同時に複数 Issue を進められる**
  - 1 Issue = 1 worktree = 1 branch = 1 Draft PR の対応
  - skill-gate が並列衝突を検出
- **採用する ATDD 解釈 (C1-C5) が機構として強制される**
  - C1: AC は Concrete Examples (Markdown / Domain language)
  - C2: AC ライフサイクル draft → green → regression
  - C3: TDD は ATDD の中にネスト
  - C4: AT は story 単位 / TDD は unit 単位
  - C5: External (ATDD) と Internal (TDD) の 2 feedback loop を skill 構造で分離
- **動作保証は AT のみで完結 (evals 廃止、レビュアーは成果物を見る)**
  - レビュアーは preview を必須では使わない
  - 動作の正しさは Acceptance Test の green で完結
  - Reviewer は コード / PRD / plan / AT / doc をレビュー

### 測定可能な指標

| 指標 | 目標値 |
|------|--------|
| 最長 SKILL.md 行数 | 200 行以下 |
| 1 PR あたりレビュー対象 skill 数 | 1 (Step 単位レビュー) |
| autopilot 関連ファイル数 | 0 |
| evals 関連ファイル数 | 0 |
| 並列実行可能な skill 数 | 8/14 (フロー駆動 6 + on-demand 2) |

## What

### 新フロー全体像

```
[Step 1+2] Discovery & Definition  → docs/issues/NNN/prd.md
[Step 3]   US 抽出                 → docs/issues/NNN/user-stories.md
[Step 4]   Plan + AT 方針          → plan.md / acceptance-tests.md / (任意) design-doc.md
[Step 5]   ATDD 実装               → tests/acceptance/AT-NNN.* (draft → green)
[Step 6]   Review                  → 成果物中心、動作確認は AT で完結
[Step 7]   Merge + Deploy          → AT を本番で再実行 (post-regression)
```

各 Step 完了時に専門 subagent でレビュー (PRD / US / Plan / Code / AT / Final、合計 50 観点)。

### 新 skill 構成 (14 skill)

| カテゴリ | skill |
|---------|-------|
| **フロー駆動** | defining-requirements / extracting-user-stories / writing-plan-and-tests / running-atdd-cycle / reviewing-deliverables / merging-and-deploying |
| **on-demand cross-cutting** | launching-preview / writing-design-doc |
| **特殊フロー** | bug / debugging |
| **infrastructure** | session-start / skill-gate / skill-fix / sim-pool / ui-test-debugging |

### 採用する設計判断 (出典)

| 領域 | 採用 | 出典 |
|------|------|------|
| ATDD 解釈 | concrete examples / draft → green / TDD inner ネスト / Agile Testing Quadrants Q2 | 採用する解釈 (本 PRD で確定) |
| User Story 形式 | **persona 抜き Connextra** `I want to <goal>, so that <reason>` | atdd-kit 設計判断 (v1.0) — Connextra (Davies 2001 / Cohn 2004) から persona フィールドを除去 |
| 制約 Story | NFR を Story 形式で表現 | Pichler 2013 |
| Plan 構造 | 2-5 分粒度タスク + verification | superpowers writing-plans |
| Design Doc | 任意 (trade-off / alternatives ある時のみ) | Ubl 2020 |
| skill 構造 | flat / kebab-case / 命名は capability | superpowers |
| docs 構造 | Issue ベース (`docs/issues/NNN/`) | atdd-kit 設計判断 |
| AT 配置 | `tests/acceptance/` in repo | XP / CD |
| AT lifecycle | planned → draft → green → regression | atdd-kit 設計 |
| Branch / PR 規律 | commit する瞬間に Draft PR | atdd-kit 設計 (並列作業対応) |
| Subagent レビュー | 各 Step 完了時に専門 subagent (合計 50 観点) | superpowers subagent-driven-development |

### 不採用判断 (v1.0 で明示的に採らないもの)

採用判断表に**載っていない設計判断は不採用**として扱う。下記は誤って採用されないよう明示する。

| 領域 | 不採用理由 | 影響範囲 |
|------|-----------|---------|
| **persona 概念** | discover 時の persona 自動 lookup / bootstrap / precheck 機構を含め全削除。User Story から `As a [persona]` フィールドを除く | `docs/personas/` / `lib/persona_check.sh` / `docs/methodology/persona-guide.md` / `agents/*.md` の persona traceability criteria / `templates/docs/issues/user-stories.md` の `[persona]` placeholder / `skills/discover/SKILL.md` Step 3a / `docs/methodology/us-quality-standard.md` MUST-1 / `docs/methodology/definition-of-ready.md` R2 / `docs/methodology/us-ac-format.md` persona frontmatter / `docs/specs/TEMPLATE.md` persona / その他 persona 言及全箇所 → **Step E6 で一括削除** |
| **Example Mapping** (Wynne 2015) | 旧 Phase C #169 由来。v1.0 では US methodology として導入しない | #188 AC の "Example Mapping を機構として持つ" は不採用に整合させ削除（#188 AC 修正タスクとして Step A0 完了後に処理） |
| **INVEST** (Wake 2003) | persona / Story 分割系列と組み合わせて使う指針。persona 廃止と整合させ不採用 | #186 / #188 AC の INVEST 言及 + `agents/us-reviewer.md` criterion #5 (INVEST) は Step E6 で削除 |
| **Story Splitting (US methodology として)** | SPIDR / Lawrence 9-pattern など。本 epic で言う "Story Splitting (約 25 sub PR 想定)" は **PR 分割** の意味で別概念。methodology としては不採用 | #188 AC の "Story Splitting heuristic" は削除。`docs/methodology/story-splitting.md` は Step E6 で削除 (PR 分割は別表現に置き換え) |

### Step 構造 (約 26 sub PR 想定)

詳細は Issue #179 本体を参照。Step A0-H の構成:

- **Step A0: PRD 修正 (1 PR、非破壊)** ← 本 PRD 改訂（#216）
- Step A: 準備 (4 PR、merged)
- Step B: 新 skill 実装 (8 PR、並列可、A0 後に AC 修正してから着手)
- Step C: テスト (2 PR)
- Step D: L4 → Acceptance Test 改称 (4 PR)
- **Step E: 旧構造削除 (Breaking Change)**
  - E1: autopilot 完全廃止 (#202)
  - E2: 旧 phase-name skill 削除 (#203)
  - E3: evals システム廃止 (#204)
  - E4: priority タグ廃止 (#205)
  - E5: その他旧機構整理 (#206)
  - **E6: 旧 persona 機構全削除 (要新 Issue)** — A1/A3 merged の訂正含む（templates / agents / skills / lib / docs / tests に残る persona 機構を一括削除）
- Step F: doc 整備 (1 PR、#207)
- Step G: CI 更新 (1 PR、#208)
- Step H: 既存 Open Issue 棚卸し (完了)

## Non-Goals

| Non-Goal | 理由 |
|---------|------|
| BDD ツール (Cucumber / Gherkin / playwright-bdd / Cucumberish) を採用する | iOS の Cucumberish が半 dormant で長期保守リスクが高い。各プラットフォーム純正フレームワーク + Robot Pattern で十分 |
| Web/iOS で `.feature` ファイルを使う | Domain language で柔軟に記述する方針と整合する。Gherkin 形式に縛らない |
| preview 環境のグローバル URL 払い出し | ローカル起動で十分。インフラコスト不要 |
| レビュアーが手動で動作確認する義務 | ATDD で動作保証が完結 (XP / CD 流)。レビュアーは成果物の品質を見る |
| AC (Acceptance Criteria) を独立成果物として持つ | AT (Acceptance Test) の domain language テスト名で代替 |
| ADR ファイルを別管理 | AI agent が無意識参照しないため、設計判断は rules / CLAUDE.md / SKILL.md に直接書く |
| autopilot を縮小して残す | 完全廃止。orchestrator なしで skill-gate + Integration セクションで代替 |
| 段階的移行 (Phase 1 → 2 → 3) | Big Bang で一気に置換 (約 25 PR で逐次マージ、最終 main で v1.0.0 メジャー bump) |

## Open Questions (Step A0 #216 で解決)

| # | Question | Resolution |
|---|----------|------------|
| 1 | subagent レビューの並列化方法 (Step 5 で developer + qa を同時に走らせるか) | **直列実行** に確定。subagent context 分離 (cross-talk 回避) を優先。並列化は後発 Issue で再検討可能。`agents/*.md` と `skills/reviewing-deliverables/SKILL.md` (#192) に直列前提で記述する。 |
| 2 | 適用先プロジェクトでの dogfood タイミング | **Step E5 完了後** (Breaking Change が一通り適用された v1.0.0-rc 相当の時点)。E6 (persona 廃止) の完了も合わせて待つ。dogfood で発見した不具合は本 epic 外の Issue として扱う。 |
| 3 | Step 7 の post-deploy regression の具体的な仕組み | **#193 (B6 merging-and-deploying) の discover で確定**。本 PRD では先送りし、AC 文言から「PRD Open Question 解決」参照を削除する (#193 AC 修正タスクを A0 完了後に処理)。 |
| 4 | launching-preview の手動起動コマンドの最終形 | **#194 (B7 launching-preview) の discover で確定**。本 PRD では先送り。#194 AC 文言の「PRD Open Question 解決」参照を削除する。 |

## 関連 Issue / AC 修正タスク (Step A0 #216 完了直後に実施)

PRD 修正 (本 #216) が merged されたら、以下を順次処理:

1. **Step E6 (新規 Issue)** — 旧 persona 機構全削除（A1 #210 / A3 #211 で merged された persona artifacts の訂正含む）
2. **#188 (B1) AC 修正** — "Example Mapping / INVEST / Story Splitting heuristic を機構として持つ" を削除
3. **#189 (B2) AC 修正** — "persona traceability 強制" を削除
4. **#192 (B5) AC 修正** — "subagent 並列化（PRD Open Question で確定された方式）" → "直列実行（Step A0 PRD で確定）"
5. **#193 (B6) AC 修正** — "Skill 系プロジェクト向けの再実行手段（PRD Open Question 解決）" → "B6 discover 中に決定"
6. **#194 (B7) AC 修正** — "引数仕様が確定（PRD Open Question 解決）" → "B7 discover 中に決定"
7. **#207 ポスト済みコメント訂正** — Example Mapping / INVEST に基づく `example-mapping.md` 新規追加提案を撤回
