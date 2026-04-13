# Unified Plan — Issue #36 (Finalized)

**Issue:** #36 — feat: discover スキルに DoD + AC の二層構造を導入する
**Finalized by:** PO (team-lead) after Plan Review Round
**Sources:**
- `docs/decisions/impl-strategy-developer.md`
- `docs/decisions/test-strategy-qa.md`
- `docs/decisions/plan-review-developer.md` (Developer review)
- `docs/decisions/plan-review-qa.md` (QA review)

---

## Test Strategy

### Outer Loop (Story Test)
- **User Story:** atdd-kit を使う開発者が discover 成果物を DoD + User Story + AC の三層構造（非コードタスクは DoD のみ）で得られる
- **Test layer:** BATS + skill-creator eval の組み合わせ
- **Rationale:** 変更対象は `skills/discover/SKILL.md` のプロンプトテキスト。構造検証（フロー定義・テンプレート構造・用語統一）は BATS + grep、LLM 出力内容の検証は skill-creator eval が最適。Story 全体のアウトカムは eval pass_rate ≥ 0.9 を代理指標とする（AC9）。
- **Known limitation:** eval は「LLM が正しい構造を出力するか」を検証するが、「モデルが実際に DoD 導出ステップを実行したか」のプロセス検証は不可（QA review P-INFO）。

### Inner Loop — AC → Test Layer マッピング

| AC | Test Layer | Target | 既存流用 / 新規 |
|----|-----------|--------|----------------|
| AC1: 共通フローで DoD 導出ステップが存在 | BATS / grep | `skills/discover/SKILL.md` 各フロー | 新規 `tests/test_discover_dod_structure.bats` |
| AC2: コード変更タスクで三層構造 | skill-creator eval | eval id=0 (dev-feature), id=1 (bug-fix) — A8/A9/B6 追加 | 既存更新 |
| AC3: 非コードタスクで DoD のみ | skill-creator eval | eval id=2 (documentation) — C1/C2 更新、C5 追加 | 既存更新 |
| AC4: Completion Criteria 用語廃止 | BATS / grep (negative, repo-wide scoped) | 後述のスコープファイル | 新規 `test_discover_dod_structure.bats` |
| AC5: 成果物テンプレートで DoD が先頭配置 | BATS / 行番号順序 | `skills/discover/SKILL.md` テンプレート | 新規 `test_discover_dod_structure.bats` |
| AC6: Bug Flow に DoD（Root Cause より前） | BATS + eval B6 | `skills/discover/SKILL.md` + eval | 新規 + 既存更新 |
| AC7: Refactoring 固有 DoD 必須項目 | BATS / grep (複数表現許容) | `skills/discover/SKILL.md` Refactoring Flow | 新規 `test_discover_dod_structure.bats` |
| AC8: plan スキルが新ヘッダを読める | BATS / grep | `skills/plan/SKILL.md` Step 1 | 新規 `test_discover_dod_structure.bats` |
| AC9: Eval regression guard | auto-eval + baseline 比較 | `skills/discover/evals/baseline.json` 比較 + 更新 | 既存 baseline + 更新 |

### AC4 スコープ（明確化 — Developer P1 への対応）

**対象ファイル（rename: Completion Criteria → DoD）:**
1. `skills/discover/SKILL.md`
2. `skills/plan/SKILL.md`
3. `docs/issue-ready-flow.md` (L45, L55)
4. `commands/autopilot.md` (L267)
5. `skills/discover/evals/evals.json` (id=0/id=2 の `expected_output` を含む)

**対象外（Out of Scope — 別 Issue で扱う）:**
- `commands/maintenance.md` L94 `### Completion Criteria`: 保守 Issue のチェックリスト見出しであり、discover ワークフローの概念とは独立。
- `templates/issue/*/development.yml`, `documentation.yml`, `research.yml` (en/ja) + `.github/ISSUE_TEMPLATE/*.yml`: Issue テンプレートのフォームフィールドラベル。ユーザー入力フォーマットの変更は本 Issue のスコープ外。

→ スコープ外のファイルはフォローアップ Issue として別途起票する（`Issue テンプレートの Completion Criteria → DoD リネーム`）。BATS negative assertion は上記 5 ファイルに限定する。

### AC7 Refactoring grep パターン（QA P1 への対応）

BATS grep パターンを広く取り、許容表現を明示する:

```
grep -qEi '外部.*観測|外部.*動作|observable.*behavior|behavior.*unchanged|externally.*visible|不変の動作'
```

加えて、テストコメントに「外部挙動不変」を意味する表現がマッチすれば PASS とすることを明記する。実装者ガイドとして `Refactoring Flow` のセクションに「例: 外部から観測可能な動作が変わらない」と例示を入れる。

### Eval 更新計画（QA P2/P3 への対応）

| Eval ID | Field | 変更 |
|---------|-------|------|
| 0 (dev-feature) | assertion A8 | 追加: "DoD セクションが User Story より前に配置されている" |
| 0 (dev-feature) | assertion A9 | 追加: "DoD セクションが存在し完了条件がリスト化されている" |
| 0 (dev-feature) | `expected_output` | 更新: "DoD list at top, then user story, then 3+ ACs in Given/When/Then format" |
| 1 (bug-fix) | assertion B6 | 追加: "DoD セクションが Root Cause より前に存在する" |
| 1 (bug-fix) | `expected_output` | 更新: "DoD list at top, then root cause classification, then fix ACs" |
| 2 (documentation) | assertion C1 | 更新: "DoD セクションが検証可能な項目リストとして記述されている" |
| 2 (documentation) | assertion C2 | 更新: "User Story と Given/When/Then が含まれず、DoD のみが成果物に含まれている" |
| 2 (documentation) | assertion C5 | 追加: "'Completion Criteria' の表記が使用されていない" |
| 2 (documentation) | `expected_output` | 更新: "Verifiable DoD items as list (not Given/When/Then), approach exploration, no User Story, no Acceptance Criteria section" |

### AC9 Baseline 比較手順（QA P4 への対応 + Developer R5 への対応）

1. 実装前: `skills/discover/evals/baseline.json` の pass_rate=1.0 を記録（既存）
2. SKILL.md + evals.json 変更後 `/atdd-kit:auto-eval` を実行
3. 新 pass_rate ≥ 0.9（baseline から 10% 以内）を確認 → PASS
4. 0.9 未満なら該当 assertion を特定し SKILL.md を修正、再実行
5. PASS 後に `baseline.json` を更新（**Commit 8 に含める**）

---

## Implementation Strategy

### Target Files（Developer review への対応で 7 → 10 ファイルに拡張）

| File | Role | Action |
|------|------|--------|
| `skills/discover/SKILL.md` | 主要変更対象 — DoD 導出ステップ挿入、テンプレート更新、用語統一 | Modify |
| `skills/plan/SKILL.md` | Step 1 テキスト + description 更新（AC8） + Completion Criteria → DoD | Modify |
| `skills/discover/evals/evals.json` | eval assertion 追加・更新 + `expected_output` 更新 | Modify |
| `skills/discover/evals/baseline.json` | AC9 auto-eval 実行後の pass_rate 更新 | Modify |
| `docs/issue-ready-flow.md` | L45/L55 の completion criteria → DoD | Modify |
| `commands/autopilot.md` | L267 の completion criteria → DoD | Modify |
| `tests/test_discover_dod_structure.bats` | 新規 BATS テスト（AC1/4/5/6/7/8 + regression） | Create |
| `CHANGELOG.md` | [Unreleased] エントリ追加 | Modify |
| `.claude-plugin/plugin.json` | v1.7.0 → v1.8.0 | Modify |


### Architecture Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | DoD 導出ステップを **Step 2.5** として挿入（Step 3 以降を繰り上げない） | 既存 BATS テスト `test_discover_autopilot_approval.bats` の Step 7/8 抽出への影響を最小化。 |
| 2 | Bug Flow の DoD はテンプレート先頭（Root Cause の前） | AC6 の Then 条件。 |
| 3 | Refactoring フロー固有の DoD 必須項目はフロー**説明**の冒頭（`## Refactoring Flow` 見出し直下）に箇条書きで追記 | Developer review で「追記場所が不明瞭」との指摘。箇条書きで明示することで実装者の判断余地を排除。 |
| 4 | plan SKILL.md は Step 1 のテキストのみ変更（State Gate は変更しない） | plan State Gate は `startswith("## discover Deliverables")` で検出。ヘッダは変更しない。 |
| 5 | evals.json の既存 eval を更新（新規 eval は追加しない） | baseline.json のリセットを避ける。 |
| 6 | `expected_output` フィールドも assertion と同時に更新 | QA P2/P3 対応。eval runner の判定基準と assertion を整合させる。 |

### AC Dependencies

```
AC4 (Completion Criteria 廃止 — 用語置換)
  ↓
AC1 (共通フロー DoD 導出ステップ挿入)
  ├── AC5 (テンプレート先頭配置)
  ├── AC6 (Bug Flow DoD)
  └── AC7 (Refactoring 必須項目)

AC3 (非コード DoD のみ) ← AC4 と連動

AC2 (三層構造) ← AC1 + AC3 + AC5 の完了後に eval で検証

AC8 (plan 対応) ← AC1/AC3/AC4 完了後

AC9 (Eval regression + baseline 更新) ← 全 AC 完了後
```

### Commit Strategy（9 コミット）

| # | Commit | AC(s) | Files |
|---|--------|-------|-------|
| 1 | `refactor: AC4 -- discover Completion Criteria を DoD に用語統一 (#36)` | AC4 | discover SKILL.md + docs/issue-ready-flow.md + commands/autopilot.md |
| 2 | `feat: AC3 -- discover Documentation/Research フローを DoD フォーマットに移行 (#36)` | AC3 | discover SKILL.md (Docs/Research Flow) |
| 3 | `feat: AC1+AC5 -- discover Development フローに DoD 導出ステップ追加、全テンプレートに先頭 DoD セクション (#36)` | AC1, AC5 | discover SKILL.md (Dev Flow + 全テンプレート + Mandatory Checklist) |
| 4 | `feat: AC6 -- discover Bug Flow に DoD セクション追加 (#36)` | AC6 | discover SKILL.md (Bug Flow) |
| 5 | `feat: AC7 -- discover Refactoring フローに DoD 必須項目追記 (#36)` | AC7 | discover SKILL.md (Refactoring Flow) |
| 6 | `test: AC2 -- evals.json に DoD 三層構造 assertion 追加 (#36)` | AC2 | evals.json (A8/A9/B6 + C1/C2 更新 + C5 + expected_output 更新) |
| 7 | `feat: AC8 -- plan スキルを discover の新 DoD ヘッダに対応 (#36)` | AC8 | plan SKILL.md |
| 8 | `test: AC9 -- BATS 新規テスト追加、eval regression guard 確認、baseline 更新 (#36)` | AC9 | test_discover_dod_structure.bats + baseline.json |
| 9 | `chore: v1.8.0 CHANGELOG + plugin.json バンプ (#36)` | — | CHANGELOG.md + plugin.json |

### Risks & Mitigations

| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| R1 | eval pass_rate が 10% 以上低下（AC9 violation） | 高 | 変更前後で eval を比較。evals.json の assertion + `expected_output` の更新を Commit 6 に含め、SKILL.md 変更と整合させる。 |
| R2 | plan Step 1 が "DoD" ヘッダを含む doc/research コメントを誤判定 | 中 | plan Step 1 に "DoD" ヘッダへの明示対応を追加。AC8 の BATS で検証。 |
| R3 | BATS の Step 番号依存テストが Step 2.5 挿入で誤検出 | 低 | DoD ステップを Step 2.5 として挿入し既存 Step 3-8 の番号を保持。 |
| R4 | Mandatory Checklist 更新漏れ | 低 | Commit 3（AC1）で Checklist 更新を明示的サブタスクとして含める。 |
| R5 | baseline.json 更新漏れ（Developer 指摘） | 中 | Commit 8 の Target Files に `baseline.json` を明示的に含める。 |
| R6 | AC7 grep パターンの文言依存（QA P1） | 低 | grep パターンを複数表現でマッチするよう拡張。実装時に Refactoring Flow 説明に例示を入れる。 |

### Follow-up Issues（本 Issue のスコープ外）

1. **Issue テンプレート rename:** `templates/issue/*/` と `.github/ISSUE_TEMPLATE/*.yml` の `Completion Criteria` フィールドラベルを `DoD` に変更（ユーザー入力フォーム変更のためスコープ分離）
2. **`commands/maintenance.md` 用語統一:** 保守 Issue チェックリストの `### Completion Criteria` 見出しを `### DoD` に変更（discover ワークフローとは独立した保守 Issue テンプレート）
3. **researcher agent の Write/Edit 権限欠落:** Issue #43 として起票済み

---

## Readiness Check

| Check | Result |
|-------|--------|
| All ACs mapped to test layers | OK |
| Test layer choices justified | OK |
| Target files identified (exact paths) | OK (10 files) |
| Design decisions resolved | OK (6 decisions) |
| Outer loop test defined | OK (BATS + eval 組み合わせ) |
| Plan Review feedback integrated | OK (Developer + QA の全 MUST/SHOULD 指摘に対応) |
