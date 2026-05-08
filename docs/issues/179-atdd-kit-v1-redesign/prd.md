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
| User Story 形式 | Connextra `As a..., I want..., so that...` | Davies 2001 / Cohn 2004 |
| 制約 Story | NFR を Story 形式で表現 | Pichler 2013 |
| Plan 構造 | 2-5 分粒度タスク + verification | superpowers writing-plans |
| Design Doc | 任意 (trade-off / alternatives ある時のみ) | Ubl 2020 |
| skill 構造 | flat / kebab-case / 命名は capability | superpowers |
| docs 構造 | Issue ベース (`docs/issues/NNN/`) | atdd-kit 設計判断 |
| AT 配置 | `tests/acceptance/` in repo | XP / CD |
| AT lifecycle | planned → draft → green → regression | atdd-kit 設計 |
| Branch / PR 規律 | commit する瞬間に Draft PR | atdd-kit 設計 (並列作業対応) |
| Subagent レビュー | 各 Step 完了時に専門 subagent (合計 50 観点) | superpowers subagent-driven-development |

### Story Splitting (約 25 sub PR 想定)

詳細は Issue #179 本体を参照。Step A-H の構成:

- Step A: 準備 (4 PR、非破壊)
- Step B: 新 skill 実装 (8 PR、並列可)
- Step C: テスト (2 PR)
- Step D: L4 → Acceptance Test 改称 (4 PR)
- Step E: 旧構造削除 (Breaking Change。autopilot / 旧 phase-name skill / evals / priority タグ / その他 旧機構)
- Step F: doc 整備 (1 PR)
- Step G: CI 更新 (1 PR)
- Step H: 既存 Open Issue 棚卸し

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

## Open Questions

- [ ] subagent レビューの並列化方法 (Step 5 で developer + qa を同時に走らせるか)
- [ ] 適用先プロジェクトでの dogfood タイミング (どの Step が完了したら投入するか)
- [ ] Step 7 の post-deploy regression の具体的な仕組み (AT を production-like 環境で再実行する手段、特に Skill 系プロジェクトでの再実行方法)
- [ ] launching-preview の手動起動コマンドの最終形 (`claude skill atdd-kit:launching-preview` の引数仕様)
