# Plan Review: QA Perspective

**Issue:** #34 -- タスクタイプ別ワークフロー分岐・エージェント再設計・トークン最適化
**Reviewer:** QA Agent
**Date:** 2026-04-12

## Overall Verdict: CONDITIONAL PASS

下記 6 件の指摘（MUST x 4, SHOULD x 1, INFO x 1）を解消すれば PASS。

---

## 1. テスト層の妥当性

### 1-1. AC2 / AC3 を Unit にする判断について

AC2（タスクタイプ別構成切り替え）と AC3（可変人数ユーザー承認）は「autopilot.md 内にテキストが存在するか」の静的チェックとして Unit に分類されている。現行テスト（`test_po_dev_qa.bats`）の grep パターン踏襲であり、テスト手段としては合理的。

ただし AC2 の Then 節「タスクタイプに応じて動作する」は、本来は構成テーブルの参照ロジックを検証すべき Integration レベルの要件。autopilot.md がマークダウン文書でありロジック実行は LLM ランタイム依存のため、静的テストしか書けないという制約は理解するが、テストの限界として Plan に明記すべき。

**指摘 Q1 (INFO):** AC2 のテストは「autopilot.md にタスクタイプ別分岐の記述が存在する」ことしか検証できない。「実際に正しいエージェントが spawn される」ことはテスト対象外であることを Plan に明記すること。

### 1-2. AC4 を Integration にした判断

AC4（ready-to-go ラベル導入）を Integration にした判断は適切。ラベルフロー全体の整合性（`rules/atdd-kit.md`, `commands/autopilot.md`, `docs/workflow-detail.md` 横断）を検証するため、単一ファイルの Unit では不十分。

### 1-3. AC6 の Unit テスト

AC6（autopilot 専用化）で 5 スキルの AUTOPILOT-GUARD が block モードかを検証する Unit テストは妥当。ただし「block モードである」の正の証拠（`block execution`, `STOP`, `ブロック` 等の文言存在）と負の証拠（`Do not block execution` の不在）の両方を検証すべき。

**判定: PASS（Q1 は INFO レベル）**

---

## 2. カバレッジ戦略の網羅性

### 2-1. AC7 の grep ベース検証の限界

AC7（旧用語残存ゼロ）の検証方法は「grep で旧用語がリポジトリ内に残存していないことを検証」とある。以下のケースで grep が漏れる:

| 漏れパターン | 例 | grep で検出? |
|-------------|-----|-------------|
| ファイル内容 | `labels: ["type:investigation"]` | 検出可能 |
| GitHub API 文字列 | `gh label create "type:investigation"` | 検出可能 |
| ファイル名自体 | `templates/issue/en/investigation.yml` | 検出不可 |
| `.github/ISSUE_TEMPLATE/` | `investigation.yml`, `investigation-ja.yml` | 検出不可 |
| CHANGELOG.md 過去エントリ | 過去の変更履歴に旧用語 | 意図的残存だが除外ルールが必要 |

現在確認できる旧用語ファイル名:
- `templates/issue/en/investigation.yml`
- `templates/issue/ja/investigation.yml`
- `.github/ISSUE_TEMPLATE/investigation.yml`
- `.github/ISSUE_TEMPLATE/investigation-ja.yml`

**指摘 Q2 (MUST):** AC7 のテストに「ファイル名に旧用語が含まれていないこと」の検証を追加すること。`find . -name '*investigation*'` 相当のチェックが必要。Target Files にはリネームが記載されているが、テスト側で検証できていない。

**指摘 Q3 (MUST):** AC7 テストで CHANGELOG.md を除外対象とするルールを明記すること。過去のリリースノートに `investigation` や `ready-to-implement` が出現するのは正常であり、これを誤検知すると CI が壊れる。

### 2-2. AUTOPILOT-GUARD block 化のテスト（AC6 補足）

現状 discover/plan/atdd の AUTOPILOT-GUARD は warn モード（`Do not block execution.`）、verify/ship は GUARD 自体がない。変更後は全 5 スキルが block モードになる。テスト計画では block モードの正の証拠も検証すべき（Q1-3 参照の上、具体的なテストパターンは実装時に確定で可）。

**判定: WARN（Q2, Q3 の解消が必要）**

---

## 3. AC の検証可能性

### 3-1. AC2 の Then 節の曖昧さ

> Then: タスクタイプに応じて Design Decision の Phase 1 / Phase 2 のエージェント構成で動作する

「動作する」は曖昧。テストで検証できるのは「autopilot.md にタスクタイプ別のエージェント構成テーブルが記述されている」ことまで。

**指摘 Q4 (SHOULD):** AC2 の Then 節を具体化すること。例: 「autopilot.md にタスクタイプ別のエージェント構成テーブルが記述されており、各タスクタイプに対応する Phase 1 / Phase 2 のエージェント名が明記されている」

### 3-2. その他の AC

- AC1: ファイル存在 + フロントマター検証で明確。PASS。
- AC3: autopilot.md 内の手順記述検証で対応可能。PASS。
- AC4: ラベル名変更の横断整合性検証で明確。PASS。
- AC5: ラベル名・テンプレート名の整合性で明確。PASS。
- AC6: block モードの文言検証で明確。PASS。
- AC7: grep + ファイル名検証で明確（Q2, Q3 解消後）。PASS。

**判定: PASS（Q4 は SHOULD レベル）**

---

## 4. リグレッションリスク

### 4-1. autopilot Phase 判定の `ready-to-implement` → `ready-to-go` 変更

38 ファイル変更の中で最もリスクが高いのは Phase 0.5 の Phase Determination テーブル。現在:

```
| ready-to-implement | Phase 3: Implementation |
```

これが `ready-to-go` に変更される。影響範囲:
1. `commands/autopilot.md` Phase 0.5
2. `rules/atdd-kit.md` Label Flow
3. `skills/atdd/SKILL.md` State Gate（`ready-to-implement` を 3 箇所で参照）
4. `docs/workflow-detail.md`, `docs/issue-ready-flow.md`
5. `commands/setup-github.md` の `gh label create`

既存テストの `ready-to-implement` 直接参照箇所:
- `tests/test_label_flow.bats`: 1 箇所（L4）
- `tests/test_state_gates.bats`: 3 箇所（AC3 の atdd State Gate テスト、L64/67/69）
- `tests/test_gate_integration.bats`: 1 箇所（L23）

**指摘 Q5 (MUST):** テスト内の `ready-to-implement` → `ready-to-go` 置換を漏らすと CI が全滅する。実装戦略として「テスト側を最初に更新する」か「一括置換で同時に更新する」かを Plan に明記すること。

### 4-2. test_po_dev_qa.bats の `reviewer` 排除テストの破壊

現行テスト `test_po_dev_qa.bats` L24-28:

```bash
@test "AC1: no old role names (implementer/reviewer) in agents/" {
  result=$(grep -rl 'implementer\|[Rr]eviewer' agents/ 2>/dev/null || true)
  [[ -z "$result" ]]
}
```

L30-34 と L36-39 にも同様の `reviewer` 排除テストがある（`commands/` と `skills/` 対象）。

新設計では `agents/reviewer.md` を正式に作成し、`commands/autopilot.md` や `skills/` 内でも Reviewer を参照する。これらのテストが全て失敗する。

**指摘 Q6 (MUST):** `test_po_dev_qa.bats` の旧ロール名排除テスト（L24-28, L30-34, L36-39）が `reviewer.md` 新設で破壊される。Plan の Target Files にこのテストファイルは含まれているが、この具体的な破壊ケースへの言及がない。テスト期待値の更新方針を明記すること。

---

## 指摘一覧

| # | 重要度 | 対象 | 内容 |
|---|--------|------|------|
| Q1 | INFO | AC2 テスト | 静的テストの限界（ランタイム動作は検証対象外）を Plan に明記 |
| Q2 | MUST | AC7 テスト | ファイル名に旧用語が含まれていないことの検証を追加 |
| Q3 | MUST | AC7 テスト | CHANGELOG.md を grep 除外対象にするルールを明記 |
| Q4 | SHOULD | AC2 | Then 節を具体化（「動作する」→ テキスト記述検証に限定） |
| Q5 | MUST | リグレッション | テスト内の `ready-to-implement` → `ready-to-go` 更新戦略を明記 |
| Q6 | MUST | リグレッション | `test_po_dev_qa.bats` の旧ロール名排除テストが `reviewer.md` 新設で破壊される。更新方針を明記 |
