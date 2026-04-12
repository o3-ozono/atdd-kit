# Plan Review -- Developer

**Issue:** #34 -- タスクタイプ別ワークフロー分岐・エージェント再設計・トークン最適化
**Reviewer:** Developer
**Date:** 2026-04-12
**Reviewed artifact:** Implementation Plan (Issue comment 2026-04-12T09:39:58Z)

## Overall Verdict: PASS with Minor concerns

Plan は 7 つの AC と正確に対応しており、38 ���ァイルの変更対象リストは概ね妥当。AC 依存順序にも論理的な問題はない。ただし旧用語 (`investigation`, `ready-to-implement`) の残存箇所について Target Files に 14 ファイルの漏れがあり、テスト修正にも注意点がある。BLOCKER は 0 件。

---

## 1. ファイル構成の妥当性（38 ファイル）

### 1.1 Target Files と旧用語残存箇所の突合

`investigation` を含むファイル（24 ファイル 54 箇所）と `ready-to-implement` を含むファイル（19 ファイル 46 箇所）を grep で網羅的に確認し、Plan の Target Files 38 ファ���ルと突合した。

#### Plan に含まれているファイル（問題なし）

| File | investigation | ready-to-implement | Plan の Action |
|------|:---:|:---:|---|
| agents/researcher.md | 1 | - | Modify |
| commands/autopilot.md | - | 2 | Modify |
| commands/setup-github.md | 3 | 1 | Modify |
| docs/bug-fix-process.md | 1 | - | Modify |
| docs/error-handling.md | 2 | - | Modify |
| docs/getting-started.md | - | 1 | Modify |
| docs/issue-ready-flow.md | 2 | 6 | Modify |
| docs/workflow-detail.md | - | 5 | Modify |
| README.md | 1 | 1 | Modify |
| README.ja.md | - | 1 | Modify |
| DEVELOPMENT.md | - | 1 | Modify |
| DEVELOPMENT.ja.md | - | 1 | Modify |
| rules/atdd-kit.md | - | 1 | Modify |
| skills/atdd/SKILL.md | - | 4 | Modify |
| skills/discover/SKILL.md | 7 | - | Modify |
| skills/issue/SKILL.md | 3 | - | Modify |
| skills/plan/SKILL.md | 1 | - | Modify |
| skills/README.md | 1 | 2 | Modify |
| templates/issue/en/investigation.yml | 2 | - | Rename -> research.yml |
| templates/issue/ja/investigation.yml | 1 | - | Rename -> research.yml |
| templates/README.md | 1 | - | Modify |
| tests/test_label_flow.bats | - | 3 | Modify |
| tests/test_state_gates.bats | - | 5 | Modify |
| tests/test_gate_integration.bats | - | 2 | Modify |
| tests/test_po_dev_qa.bats | - | - | Modify |

#### Plan に含まれていないが旧用語を含むファイル（潜在漏れ 14 件）

| File | investigation | ready-to-implement | 対応要否 |
|------|:---:|:---:|---|
| skills/debugging/SKILL.md | 6 | - | **要対応** -- investigation タスクタイプへの言及。research への置換必要 |
| skills/ui-test-debugging/SKILL.md | 2 | - | **要対応** -- 同上 |
| skills/session-start/SKILL.md | 1 | - | **要対応** -- investigation テンプレート参照 |
| skills/bug/SKILL.md | 1 | - | **要対応** -- investigation への言及 |
| commands/auto-sweep.md | - | 1 | **要対応** -- ready-to-implement ラベル監視 |
| .github/ISSUE_TEMPLATE/investigation.yml | 2 | - | **要対応** -- rename to research.yml |
| .github/ISSUE_TEMPLATE/investigation-ja.yml | 1 | - | **要対応** -- rename to research-ja.yml |
| .github/ISSUE_TEMPLATE/development.yml | 1 | - | **要検討** -- investigation への言及 |
| tests/test_bilingual_templates.bats | 3 | - | **要対応** -- `investigation` テンプレート名ハードコード |
| tests/test_skill_adapters.bats | 1 | - | **要検討** -- investigation への間接参照 |
| tests/test_autonomy_levels.bats | - | 2 | **要対応** -- ready-to-implement チェック x2 |
| skills/atdd/evals/evals.json | - | 4 | **要対応** -- プロンプト・期待値に ready-to-implement |
| skills/verify/evals/evals.json | - | 1 | **要対応** -- プロンプトに ready-to-implement |
| .claude/rules/workflow-overrides.md | - | 2 | **要対応** -- Plan Review フローに直接影響 |

### 1.2 不要なファイルの有無

Target Files に明らかに不��なファイルはない。38 ファイル全てが変更理由を持っている。

### 1.3 まとめ

| 判定 | 内容 |
|------|------|
| PASS | 38 ファイルの変更理由は全て妥当 |
| Minor | **14 ファイルの潜在漏れ**。AC7 の BATS テスト（旧用語 grep チェック）で検出可能だが、事前に Target Files に追加しておくと実装効率が上がる |

---

## 2. 実装順序のリスク評価

Plan の依存順序:
```
AC5(ラベル整備) -> AC4(ready-to-go) -> AC2(タスクタイプ別切り替え)
AC1(エージェント定義) -> AC2(タスクタイプ別切り替え)
AC6(autopilot 専用化) -- 独立
AC3(可変人数ユーザー承認) -- AC2 の後
AC7(ドキュメント更新) -- 最後
```

| 順序 | リスク | 評価 |
|------|--------|------|
| AC5 を最初に | ラベル名変更は影響範囲が広い（実際には 38+14=52 ファイル）。ただし grep で検出可能な機械的置換 | LOW |
| AC1 を AC2 の前に | エージェント定義は独立したファイル。先に作成しても他に影響なし | LOW |
| AC4 を AC2 の前に | ready-to-go ラベルは AC2 のフロー分岐で使用。先に導入するのは正しい依存順序 | LOW |
| AC6 を独立実施 | discover/plan/atdd は既に warn モードの GUARD あり。verify/ship は新設。2 パターンだが共に単純 | LOW |
| AC7 を最後に | 旧用語残存チェックが全変更後に実行される安全弁 | LOW |

**依存順序に問題なし。** AC3（可変人数承認）は AC2 の一部として autopilot.md に記述されるため、AC2 と同時実装が自然。

---

## 3. 技術リスク評価

### 3.1 autopilot.md の大規模改修（268 行 -> 推定 400-500 行）

| 観点 | リスク | 評価 |
|------|--------|------|
| 可読性 | MEDIUM | 分岐テーブル方式で緩和可能。Plan の方針に同意 |
| Phase 0.5 拡張 | LOW | 既存判定テーブルにタスクタイプラベル読み取りを追加するだけ |
| Phase 0.9 spawn ロジック | MEDIUM | 最大 7 種のエージェントを条件分岐で spawn。テーブル駆動で複雑度抑制可能 |
| 5 タイプ x 2 フェ���ズ | MEDIUM | 10 パターンの分岐。テーブル 1 つで管理すべき |

**推奨:** autopilot.md 冒頭にエージェント構成テーブルを配置:

```markdown
| タスクタイプ | Phase 1 エージェント | Phase 2 エージェント |
|---|---|---|
| development | PO, Developer, QA | PO, Developer, Reviewer x N |
| bug | PO, Tester, Developer | Developer, Tester, Reviewer x N |
| research | PO | PO, Researcher x N |
| documentation | PO | PO, Writer, Reviewer x N |
| refactoring | PO | PO, Developer, Reviewer x N |
```

### 3.2 既存テスト修正リスク

| テストファイル | 修正内容 | リスク |
|---------------|---------|--------|
| test_po_dev_qa.bats L24-28 | `no old role names (implementer/reviewer)` -- reviewer.md 追加で**確実に失敗** | MEDIUM |
| test_po_dev_qa.bats L30-34, L36-39 | 同上。commands/ と skills/ 内の reviewer チェック | MEDIUM |
| test_bilingual_templates.bats L9,15,23 | `investigation` テンプレート名ハードコード -> `research` | LOW |
| test_autonomy_levels.bats L27-28 | `ready-to-implement` x2 | LOW |
| test_label_flow.bats | `ready-to-implement` x3 | LOW |
| test_state_gates.bats | `ready-to-implement` x5 | LOW |
| test_gate_integration.bats | `ready-to-implement` x2 | LOW |

**特記:** test_po_dev_qa.bats の「old role names」テスト (L24-28, L30-34, L36-39) は reviewer が正式エージェントになることで根本的に意図が変わる。対応方針:
1. `implementer` のみを「旧 role 名」としてチェックするよう変更
2. `reviewer` は正式 role のため negative test から除外
3. テスト名を `no old role names (implementer) in agents/` に変更

### 3.3 evals ファイルの修正（Plan から漏れ）

| ファイル | 箇所 | 内容 |
|---------|------|------|
| skills/atdd/evals/evals.json | 4 箇所 | `ready-to-implement` がプロンプト・期待値に |
| skills/verify/evals/evals.json | 1 箇所 | 同上 |

evals は BATS テストとは別系統だが、旧用語が残るとスキル評価結果が不正確になる。

### 3.4 AUTOPILOT-GUARD warn -> block

| スキル | 現状 | 変更後 |
|--------|------|--------|
| discover | warn (proceed after warning) | block |
| plan | warn (proceed after warning) | block |
| atdd | warn (proceed after warning) | block |
| verify | GUARD なし | block (新設) |
| ship | GUARD なし | block (新設) |

block 化により手動実行が完全に不可能になる。Discussion で「warn-only + --force」を却下済みであり妥当。ただし Agent Teams 未設定環境でのフォールバック消失を認識しておくべき。

---

## 4. エージェント定義の設計評価

### 4.1 新規エージェント 3 種の tools/skills 構成提案

Plan では新規 3 エージェントの tools/skills 構成が未定義。以下を提案:

**Tester (agents/tester.md)**
```yaml
model: sonnet
effort: high
tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - Agent
skills:
  - atdd-kit:debugging
```
理由: バグ再現スクリプト作成・テスト実行に Write/Edit/Bash が必要。debugging スキルで根本原因調査を支援。

**Reviewer (agents/reviewer.md)**
```yaml
model: sonnet
effort: high
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - WebSearch
  - WebFetch
```
理由: QA と同等の読み取り専用 tools。コード編集不要。QA との差別化は system_prompt で「コードレビュー専門」として定義。

**Writer (agents/writer.md)**
```yaml
model: sonnet
effort: high
tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
```
理由: ドキュメント作成に Write/Edit が必要。Skill プリロードは不要（ドキュメント作成は汎用的）。

### 4.2 既存エージェント model/effort 変更

| エージェント | 現状 | 変更後 | 評価 |
|-------------|------|--------|------|
| PO | model: inherit | model: opus, effort: high | 妥当 -- 判断品質重視 |
| Developer | model: inherit | model: sonnet, effort: high | 妥当 -- コスト削減 |
| QA | model: inherit | model: sonnet, effort: high | 妥当 |
| Researcher | model: inherit | model: sonnet, effort: high | 妥当 |

**注意:** `model: opus` / `model: sonnet` がエイリアスとして解決されるか、フル model ID (`claude-opus-4-6`, `claude-sonnet-4-6`) が必要かは実装時に検証すべき��

### 4.3 QA と Reviewer の役割分担

- **QA:** 開発タスクの Phase 1（plan レビュー）。テスト戦略策定が主務
- **Reviewer:** Phase 2 のコードレビュー。可変人数

分離は合理的。system_prompt で明確に役割境界を定義する必要あり。

### 4.4 Researcher の活用シーン

research タスク���イプ Phase 2 で「同一テーマ最低 2 名」と定義。Issue #4 の課題に対する回答として適切。development/bug の Phase 1 での活用は将来拡張として検討可能。

---

## 5. 追加リスク

### 5.1 .claude/rules/workflow-overrides.md

`ready-to-implement` を 2 箇所で参照。Plan Review Round のフローに直接影響するため、AC4 または AC7 で `ready-to-go` への置換が必須。Target Files に含まれて��ない。

### 5.2 CHANGELOG.md / plugin.json のバージョンバンプ

Target Files に含まれているが、AC 依存順序にタイミング未記載。AC7 の後に実施するのが自然。

### 5.3 grep チェックの拡張子カバレッジ

AC7 の旧���語 grep チェックでは `.md`, `.yml` だけでなく `.bats`, `.json` (evals) も対象に含めるべき。

---

## Summary

| # | 観点 | 判定 | 詳細 |
|---|------|------|------|
| 1 | ファイル構成 | PASS (Minor) | 38 ファイルは妥当。**14 ファイ���の潜在漏れ** あり |
| 2 | 実装順序 | PASS | AC 依存順序は正しく、リスクは全て LOW |
| 3 | autopilot.md 改修 | PASS (Minor) | 268行 -> 推定 400-500行。テーブル駆動設計を推奨 |
| 4 | 既存テスト修正 | PASS (Minor) | test_po_dev_qa.bats reviewer negative test の意図再設計、test_bilingual_templates/test_autonomy_levels も修正必要 |
| 5 | evals ファイル | PASS (Minor) | 2 ファイルが Target Files から漏れ |
| 6 | エー��ェント定義 | PASS (Minor) | 新規 3 エージェントの tools/skills 構成を提案済み |
| 7 | GUARD block 化 | PASS | Discussion で検討済み。妥当 |
| 8 | model フロントマター | PASS (Minor) | エイリアス解決は実装時検証 |

**BLOCKER: 0 件。実装着手可能。**

Minor 指摘の多くは AC7 で旧用語 grep チェックにより検出される設計だが、14 ファイルの漏れを事前に Target Files に追加しておくことを推奨する。
