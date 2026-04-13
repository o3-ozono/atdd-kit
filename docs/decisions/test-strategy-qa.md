# Test Strategy — QA (Issue #36)

feat: discover スキルに DoD + AC の二層構造を導入する

---

## 1. Outer Loop (Story Test)

**User Story:**
> As a atdd-kit を使う開発者（PO / Developer / QA エージェント含む），discover スキルが全タスクタイプで DoD を共通成果物として導出し、コード変更タスクでは User Story + AC を追加レイヤーとして導出するようにしたい，so that タスクの完了条件が常に明示され、タスクタイプによって成果物の形式がバラバラにならない。

**選定テスト層:** BATS + skill-creator eval の組み合わせ

**理由:**
- 変更対象は `skills/discover/SKILL.md` のプロンプトテキスト。LLM 実行を伴わない構造検証（フロー定義・テンプレート構造・用語統一）は BATS + grep が最適。
- AC9 (eval regression guard) および AC2/AC3（成果物内容の実質検証）は skill-creator eval で LLM 出力を検証する必要がある。
- Story 全体のアウトカム検証は「eval pass_rate ≥ 0.9」を代理指標とする（AC9）。

---

## 2. Inner Loop — AC → Test Layer マッピング

| AC | テスト層 | 対象ファイル / Eval ID | 検証方法 | 既存流用 / 新規 |
|----|---------|----------------------|---------|----------------|
| AC1: 共通フローで DoD 導出ステップが実行される | BATS / grep | `skills/discover/SKILL.md` | 各フロー（Dev/Bug/Docs/Research）セクションに "DoD" 導出ステップが存在することを grep | **新規** `test_discover_dod_structure.bats` |
| AC2: コード変更タスクで三層構造が導出される | skill-creator eval | eval id=0 (dev-feature), id=1 (bug-fix) | assertion 追加: "DoD"・"User Story"・Given/When/Then の三要素がすべて出力に含まれる | **既存更新** evals.json A1〜A7 に DoD 検証 assertion を追加 |
| AC3: 非コードタスクで DoD のみ導出される | skill-creator eval | eval id=2 (documentation) | assertion 追加（肯定）: "DoD" が含まれる / （否定）: "User Story" / Given/When/Then が含まれない | **既存更新** evals.json C1/C2 を DoD 用語に対応 |
| AC4: Completion Criteria 用語の廃止 | BATS / grep | `skills/discover/SKILL.md` | negative grep: "Completion Criteria" が存在しないことを確認 | **新規** `test_discover_dod_structure.bats` |
| AC5: 成果物テンプレートで DoD が先頭配置 | BATS / grep | `skills/discover/SKILL.md` | 各フローのテンプレートブロック内で "DoD" が先頭セクションとして現れることを行番号順序で確認 | **新規** `test_discover_dod_structure.bats` |
| AC6: Bug Flow 成果物に DoD セクションが含まれる | BATS + eval | `skills/discover/SKILL.md` + eval id=1 | SKILL.md の Bug Flow テンプレートに DoD セクションが Root Cause より前にあることを確認。eval assertion B6 を追加 | **新規** (SKILL.md grep) + **既存更新** (eval B6 追加) |
| AC7: Refactoring 固有の DoD 必須項目 | BATS / grep | `skills/discover/SKILL.md` | Refactoring フローセクションに "外部から観測可能な動作が変わらない" に相当する DoD 必須文言が存在することを grep | **新規** `test_discover_dod_structure.bats` |
| AC8: plan スキルが新ヘッダを正しく読み取る | BATS / grep | `skills/plan/SKILL.md` | plan Step 1 の "Documentation/research" 判定ロジックが "DoD" ヘッダを認識できることを grep（"completion criteria" のみへの依存がないこと） | **新規** `test_discover_dod_structure.bats` |
| AC9: Eval regression guard | skill-creator eval | `skills/discover/evals/baseline.json` + evals.json | `auto-eval` 実行後の pass_rate ≥ 0.9（baseline 1.0 から 10% 以内） | **既存 baseline 比較** |

---

## 3. Coverage Analysis — AC9 (Eval Regression Guard)

### baseline.json の現状

```
pass_rate: 1.0
- dev-feature: 7/7
- bug-fix:     5/5
- documentation: 4/4
```

### evals.json 更新計画

#### eval id=0 (dev-feature) — 追加 assertion

```jsonc
{"id": "A8", "text": "DoDセクションが成果物の先頭に配置されている（User Story より前）", "type": "structural"},
{"id": "A9", "text": "DoDセクションが存在し、タスク固有の完了条件がリスト化されている", "type": "structural"}
```

#### eval id=1 (bug-fix) — 追加 assertion

```jsonc
{"id": "B6", "text": "DoDセクションが成果物に含まれ、Root Cause セクションより前に配置されている", "type": "structural"}
```

#### eval id=2 (documentation) — 更新 assertion

- C1 更新: "完了基準が検証可能なチェックリスト形式" → "DoDセクションが検証可能な項目リストとして記述されている"
- C2 更新: "Given/When/Then 形式ではなくチェックリスト形式を使用している" → "User Story と Given/When/Then が含まれず、DoDのみが成果物に含まれている"
- C5 追加: `{"id": "C5", "text": "成果物に 'Completion Criteria' の表記が使用されていない", "type": "structural"}`

### baseline 比較手順

1. 実装前に現 baseline.json が pass_rate=1.0 であることを確認（既存）
2. SKILL.md 変更後、`auto-eval` を実行
3. 出力 pass_rate が 0.9 以上であることを確認（AC9 の合格基準）
4. 0.9 未満の場合: 低下した eval とアサーションを特定し、SKILL.md の該当箇所を修正してから再実行
5. pass_rate が 0.9 以上になったら baseline.json を更新（上書き）

---

## 4. Regression Risk

### 既存 BATS テストへの影響

| テストファイル | 影響 | 理由 |
|--------------|------|------|
| `test_discover_approach_parity.bats` | **影響なし** | Step 2 の equal-detail ルールは変更なし |
| `test_discover_autopilot_approval.bats` | **影響なし** | Step 7/8 の autopilot 分岐ロジックは変更なし |
| `test_legacy_terms.bats` | **要確認** | "Completion Criteria" が legacy term になるため、AC4 の grep negative テストと重複しないよう調整が必要。ただし現行 `test_legacy_terms.bats` は "type:investigation" 等を対象としており直接競合しない |
| その他 43 ファイル | **影響なし** | `skills/discover/SKILL.md` の構造変更に依存するテストは上記 2 ファイルのみ |

### eval への影響

- 既存 C1/C2 assertion は "Completion Criteria" を前提としているため、SKILL.md 変更後に **false negative** が発生する（テストが PASS するが正しい動作を検証できていない）。上記の assertion 更新で対処する。
- 新規 assertion (A8, A9, B6, C5) の追加により total テスト数が増加するため、pass_rate は新規 assertion が FAIL した場合に低下する。これは regression ではなく「新規要件の非充足」として扱う。

### plan スキルへの影響

Developer レビュー (ac-review-developer.md) で指摘されたとおり、`skills/plan/SKILL.md` Step 1 の判定ロジックが "completion criteria" のみに依存している場合、documentation タスクの plan フローが壊れる。AC8 の BATS テストで plan Step 1 に "DoD" ヘッダへの対応が含まれていることを確認する。

---

## 5. Tests to Add

### 新規 BATS ファイル: `tests/test_discover_dod_structure.bats`

```bash
#!/usr/bin/env bats

# Issue #36: discover スキルに DoD + AC の二層構造を導入する
# Tests verify DoD derivation structure, terminology, and template placement

DISCOVER="skills/discover/SKILL.md"
PLAN="skills/plan/SKILL.md"

# --- AC1: 各フローに DoD 導出ステップが存在する ---

@test "AC1: Development Flow contains DoD derivation step" {
  local dev_flow
  dev_flow=$(sed -n '/## Development Flow/,/## Bug Flow/p' "$DISCOVER")
  echo "$dev_flow" | grep -qi 'DoD\|Definition of Done'
}

@test "AC1: Bug Flow contains DoD derivation step" {
  local bug_flow
  bug_flow=$(sed -n '/## Bug Flow/,/## Refactoring Flow/p' "$DISCOVER")
  echo "$bug_flow" | grep -qi 'DoD\|Definition of Done'
}

@test "AC1: Documentation/Research Flow contains DoD derivation step" {
  local doc_flow
  doc_flow=$(sed -n '/## Documentation \/ Research Flow/,/## Skill Completion/p' "$DISCOVER")
  echo "$doc_flow" | grep -qi 'DoD\|Definition of Done'
}

# --- AC4: "Completion Criteria" 用語が存在しない ---

@test "AC4: SKILL.md does not contain 'Completion Criteria' term" {
  ! grep -q 'Completion Criteria' "$DISCOVER"
}

# --- AC5: 成果物テンプレートで DoD が先頭に配置されている ---

@test "AC5: Development Flow template has DoD section before User Story" {
  local template_section
  template_section=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  local dod_line us_line
  dod_line=$(echo "$template_section" | grep -n 'DoD\|Definition of Done' | head -1 | cut -d: -f1)
  us_line=$(echo "$template_section" | grep -n 'User Story' | head -1 | cut -d: -f1)
  [[ -n "$dod_line" ]]
  [[ -n "$us_line" ]]
  [[ "$dod_line" -lt "$us_line" ]]
}

@test "AC5: Documentation/Research Flow template has DoD section" {
  local doc_template
  doc_template=$(sed -n '/## Documentation \/ Research Flow/,/## Skill Completion/p' "$DISCOVER")
  echo "$doc_template" | grep -qi '### DoD\|## DoD\|DoD'
}

# --- AC6: Bug Flow テンプレートに DoD セクションが Root Cause より前に存在する ---

@test "AC6: Bug Flow template has DoD section before Root Cause" {
  local bug_template
  bug_template=$(sed -n '/## Bug Flow/,/## Refactoring Flow/p' "$DISCOVER")
  local dod_line rc_line
  dod_line=$(echo "$bug_template" | grep -n 'DoD\|Definition of Done' | head -1 | cut -d: -f1)
  rc_line=$(echo "$bug_template" | grep -n 'Root Cause' | head -1 | cut -d: -f1)
  [[ -n "$dod_line" ]]
  [[ -n "$rc_line" ]]
  [[ "$dod_line" -lt "$rc_line" ]]
}

# --- AC7: Refactoring フローの DoD に「外部動作不変」必須項目の記述がある ---

@test "AC7: Refactoring Flow mentions externally-observable behavior unchanged in DoD" {
  local refactoring_flow
  refactoring_flow=$(sed -n '/## Refactoring Flow/,/## Documentation/p' "$DISCOVER")
  echo "$refactoring_flow" | grep -qi '外部.*動作\|observable.*behavior\|behavior.*unchanged\|externally'
}

# --- AC8: plan Step 1 が DoD ヘッダを認識できる ---

@test "AC8: plan Step 1 reads discover deliverables by DoD header (not only completion criteria)" {
  local step1
  step1=$(sed -n '/### Step 1/,/### Step 2/p' "$PLAN")
  # plan は "User Story + ACs" または "DoD" で識別できる必要がある
  # "completion criteria" のみへの依存は NG
  echo "$step1" | grep -qi 'DoD\|User Story'
}

# --- REGRESSION: Mandatory Checklist に DoD チェック項目がある ---

@test "REGRESSION: Mandatory Checklist includes DoD derivation check" {
  local checklist
  checklist=$(sed -n '/## Mandatory Checklist/,/^$/p' "$DISCOVER")
  echo "$checklist" | grep -qi 'DoD'
}
```

### evals.json 追加 assertion 一覧（再掲）

| Eval | Assertion ID | 内容 | 種別 |
|------|-------------|------|------|
| dev-feature | A8 | DoD セクションが User Story より前に配置されている | structural |
| dev-feature | A9 | DoD セクションが存在し完了条件がリスト化されている | structural |
| bug-fix | B6 | DoD セクションが Root Cause セクションより前に存在する | structural |
| documentation | C1 (更新) | DoD セクションが検証可能な項目リストとして記述されている | structural |
| documentation | C2 (更新) | User Story と Given/When/Then が含まれず DoD のみが成果物に含まれている | structural |
| documentation | C5 (追加) | "Completion Criteria" の表記が使用されていない | structural |
