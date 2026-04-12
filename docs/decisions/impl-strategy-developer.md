# Implementation Strategy — Developer

**Issue:** #3 — bug: discover の autopilot モード検出が PO 直接呼び出しを認識しない
**Author:** Developer
**Date:** 2026-04-12
**Prior Decision:** `docs/decisions/ac-review-developer.md`

## 1. Flag Detection Specification

### Detection Method

ARGUMENTS 文字列に対する単純な contains チェック。SKILL.md はマークダウン指示であり LLM が解釈するため、プログラム的なパース（正規表現等）は不要。

**判定基準:**
- ARGUMENTS に `--autopilot` が含まれる → **Autopilot mode**
- ARGUMENTS に `--autopilot` が含まれない → **Standalone mode**

**記述パターン（全スキル共通）:**
```
If ARGUMENTS contains `--autopilot`: [autopilot behavior]
If ARGUMENTS does not contain `--autopilot`: [standalone behavior]
```

**Rationale:**
- LLM が自然言語指示として解釈するため `contains` で十分
- 引数順序（`"3 --autopilot"` vs `"--autopilot 3"`）に依存しない
- 将来のフラグ追加（`"3 --autopilot --verbose"`）にも対応可能
- `<teammate-message>` のようなコンテキスト依存ではなく明示的フラグなので確実に制御可能

## 2. Target Files and Changes

### File 1: `skills/discover/SKILL.md` (AC1 + AC2)

**4 箇所の変更:**

#### 1a — HARD-GATE autopilot exception (L15)

```
Before:
**Autopilot exception:** When discover is invoked via autopilot (`<teammate-message>` from team-lead is present), the approval gate in Step 7 is satisfied by the AC Review Round that follows. The user approves the final AC set after Three Amigos review — not during discover's Step 7. This is NOT a bypass of the approval requirement; it is a relocation of when approval occurs. Both conditions must hold: (1) `<teammate-message>` from team-lead is present, AND (2) the AC Review Round completes with user approval.

After:
**Autopilot exception:** When discover is invoked via autopilot (ARGUMENTS contains `--autopilot`), the approval gate in Step 7 is satisfied by the AC Review Round that follows. The user approves the final AC set after Three Amigos review — not during discover's Step 7. This is NOT a bypass of the approval requirement; it is a relocation of when approval occurs. Both conditions must hold: (1) ARGUMENTS contains `--autopilot`, AND (2) the AC Review Round completes with user approval.
```

#### 1b — AUTOPILOT-GUARD (L18-23)

```
Before:
<AUTOPILOT-GUARD>
If this skill was invoked directly by the user (via slash command) and NOT as a subagent dispatched by autopilot (i.e., no `<teammate-message>` context is present):
- Display warning: "This skill is designed to run within autopilot. Use `/atdd-kit:autopilot <number>` instead."
- **Do not block execution.** Proceed normally after showing the warning.
If this skill was dispatched as a subagent by autopilot (a `<teammate-message>` from team-lead is present): skip this warning silently.
</AUTOPILOT-GUARD>

After:
<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display warning: "This skill is designed to run within autopilot. Use `/atdd-kit:autopilot <number>` instead."
- **Do not block execution.** Proceed normally after showing the warning.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this warning silently.
</AUTOPILOT-GUARD>
```

#### 1c — Step 7 (L230-232)

```
Before:
**Autopilot mode** (a `<teammate-message>` from team-lead is present): Skip the approval request. Output the draft AC set and return to the caller. The AC Review Round in autopilot will handle user approval. Do NOT proceed to Step 8.

**Standalone mode** (no `<teammate-message>` — user invoked discover directly): Present the full AC set to the user:

After:
**Autopilot mode** (ARGUMENTS contains `--autopilot`): Skip the approval request. Output the draft AC set and return to the caller. The AC Review Round in autopilot will handle user approval. Do NOT proceed to Step 8.

**Standalone mode** (ARGUMENTS does not contain `--autopilot` — user invoked discover directly): Present the full AC set to the user:
```

#### 1d — Step 8 (L251)

```
Before:
> **Autopilot mode skip:** When discover was invoked via autopilot (`<teammate-message>` from team-lead), this step is skipped entirely. Issue comment posting and plan execution are handled by the autopilot AC Review Round after user approval.

After:
> **Autopilot mode skip:** When ARGUMENTS contains `--autopilot`, this step is skipped entirely. Issue comment posting and plan execution are handled by the autopilot AC Review Round after user approval.
```

**AC2 (Standalone 維持):** 上記 1b の AUTOPILOT-GUARD と 1c の Step 7 の Standalone モード記述を維持。AC1 の変更後もフラグなし呼び出しは従来通り動作する。検証は同一コミット内で行う。

---

### File 2: `skills/plan/SKILL.md` (AC3)

**1 箇所の変更:**

#### 2a — AUTOPILOT-GUARD (L16-21)

```
Before:
<AUTOPILOT-GUARD>
If this skill was invoked directly by the user (via slash command) and NOT as a subagent dispatched by autopilot (i.e., no `<teammate-message>` context is present):
- Display warning: "This skill is designed to run within autopilot. Use `/atdd-kit:autopilot <number>` instead."
- **Do not block execution.** Proceed normally after showing the warning.
If this skill was dispatched as a subagent by autopilot (a `<teammate-message>` from team-lead is present): skip this warning silently.
</AUTOPILOT-GUARD>

After:
<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--autopilot` (user invoked directly via slash command):
- Display warning: "This skill is designed to run within autopilot. Use `/atdd-kit:autopilot <number>` instead."
- **Do not block execution.** Proceed normally after showing the warning.
If ARGUMENTS contains `--autopilot` (invoked by autopilot): skip this warning silently.
</AUTOPILOT-GUARD>
```

---

### File 3: `skills/atdd/SKILL.md` (AC4)

**1 箇所の変更:**

#### 3a — AUTOPILOT-GUARD (L12-17)

File 2 と完全同一パターンの書き換え。

---

### File 4: `commands/autopilot.md` (AC5)

**2 箇所の変更:**

#### 4a — Phase 1, step 3 (L124)

```
Before:
3. Use Skill tool to invoke `atdd-kit:discover` for the Issue

After:
3. Use Skill tool to invoke `atdd-kit:discover` with args `"<number> --autopilot"` for the Issue
```

#### 4b — Phase 3, step 1 (L187)

```
Before:
1. Use SendMessage to: "Developer" with ATDD implementation instructions. Include Issue number, approved AC set, unified Plan, and all prior Decision Trail file paths as context — Developer uses Skill tool to invoke `atdd-kit:atdd`

After:
1. Use SendMessage to: "Developer" with ATDD implementation instructions. Include Issue number, approved AC set, unified Plan, and all prior Decision Trail file paths as context — Developer uses Skill tool to invoke `atdd-kit:atdd` with args `"<number> --autopilot"`
```

---

### File 5: `tests/test_discover_autopilot_approval.bats` (AC6)

**テスト更新方針:**

既存テストは Issue #155 の AC 体系に基づいている。検出メカニズムが `<teammate-message>` → `--autopilot` に変わるため、以下を更新:

#### 更新が必要なテスト（3 件）

| Test (Line) | Current assertion | After |
|-------------|-------------------|-------|
| L12-16 "HARD-GATE contains autopilot exception clause" | `grep -q 'teammate-message'` | `grep -q '\-\-autopilot'` |
| L18-24 "HARD-GATE exception requires BOTH..." | `grep -qi 'teammate-message'` + テスト名 | `grep -qi '\-\-autopilot'` + テスト名を `--autopilot AND AC Review Round` に変更 |
| L32 Step 7 conditional | `grep -qi 'teammate-message\|autopilot'` | `grep -qi '\-\-autopilot\|autopilot'` (引き続きマッチするため実質変更不要だが、明示的に `--autopilot` を先頭にすべき) |

#### 変更不要なテスト（11 件）

| Test group | Reason |
|------------|--------|
| L28-31 "Step 7 has autopilot-mode conditional branch" | `autopilot` でマッチするため変更不要（`--autopilot` は `autopilot` を含む） |
| L35-39 "Step 7 outputs draft AC" | `draft` のアサーション — 影響なし |
| L41-45 "Step 7 skips approval" | `skip` のアサーション — 影響なし |
| L47-51 "Step 8 has autopilot skip" | `skip\|autopilot` — 引き続きマッチ |
| L55-71 AC2 Standalone tests | `Approve`, `gh issue comment`, `plan` のアサーション — 影響なし |
| L75-91 AC4 autopilot tests | autopilot.md の AC Review Round セクションをテスト — 影響なし |
| L95-111 AC3 Three Amigos tests | autopilot.md をテスト — 影響なし |
| L115-125 Cross-file consistency | `AC Review Round` と `approval` のアサーション — 影響なし |

#### 新規テスト追加（2 件）

新規 AC に対応するテストを追加:

```bash
# --- AC5: autopilot.md passes --autopilot flag in Skill calls ---

@test "AC5: autopilot Phase 1 passes --autopilot in discover Skill call" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -q '\-\-autopilot'
}

@test "AC5: autopilot Phase 3 passes --autopilot in atdd Skill call" {
  local phase3
  phase3=$(sed -n '/## Phase 3/,/## Phase 4/p' "$AUTOPILOT")
  echo "$phase3" | grep -q '\-\-autopilot'
}
```

#### AUTOPILOT-GUARD テスト追加（3 件）

```bash
# --- AUTOPILOT-GUARD uses --autopilot flag ---

@test "discover AUTOPILOT-GUARD uses --autopilot flag for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  echo "$guard" | grep -q '\-\-autopilot'
}

@test "plan AUTOPILOT-GUARD uses --autopilot flag for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "skills/plan/SKILL.md")
  echo "$guard" | grep -q '\-\-autopilot'
}

@test "atdd AUTOPILOT-GUARD uses --autopilot flag for detection" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "skills/atdd/SKILL.md")
  echo "$guard" | grep -q '\-\-autopilot'
}
```

#### 残骸チェックテスト追加（1 件）

```bash
# --- No teammate-message residue in autopilot detection ---

@test "No teammate-message references remain in skill AUTOPILOT-GUARDs" {
  for skill in discover plan atdd; do
    local guard
    guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "skills/$skill/SKILL.md")
    ! echo "$guard" | grep -qi 'teammate-message'
  done
}
```

## 3. Implementation Order

```
AC3 (plan AUTOPILOT-GUARD)           ← 最小変更、パターン確立
  ↓
AC4 (atdd AUTOPILOT-GUARD)           ← 同一パターン適用
  ↓
AC1+AC2 (discover 4箇所 + Standalone 維持) ← 最大変更
  ↓
AC5 (autopilot.md 呼び出し側更新)     ← 判定側と呼び出し側を接続
  ↓
AC6 (テスト更新 + 全件 PASS)          ← 最終検証
```

**Rationale:**
1. **AC3 → AC4:** plan/atdd の AUTOPILOT-GUARD は完全同一パターン。最小変更（1箇所ずつ）から着手してパターンを確立する。
2. **AC1+AC2:** discover は 4 箇所の変更があり blast radius が最大。AC3/AC4 で確立したパターンを適用する。AC2 は AC1 の変更が Standalone 動作を壊していないことの検証であり、同一コミットに含める。
3. **AC5:** 判定側（SKILL.md）の変更完了後に、呼び出し側（autopilot.md）を更新して接続を完成させる。
4. **AC6:** 全変更完了後にテストを更新し、`bats tests/` で全件 PASS を確認する。

### Commit Strategy

| Order | AC | Commit message |
|-------|-----|---------------|
| 1 | AC3 | `fix: AC3 -- plan AUTOPILOT-GUARD を --autopilot フラグ検出に移行 (#3)` |
| 2 | AC4 | `fix: AC4 -- atdd AUTOPILOT-GUARD を --autopilot フラグ検出に移行 (#3)` |
| 3 | AC1+AC2 | `fix: AC1+AC2 -- discover の全 autopilot 検出を --autopilot フラグに移行 (#3)` |
| 4 | AC5 | `fix: AC5 -- autopilot.md の Skill 呼び出しに --autopilot フラグ付与 (#3)` |
| 5 | AC6 | `test: AC6 -- テストを --autopilot フラグベースに更新 (#3)` |

## 4. AC Dependencies

```
AC3 ──┐
      ├── 独立（並行実装可能だが順次実装を推奨）
AC4 ──┘
      ↓
AC1 ── AC2（同一変更セット）
      ↓
AC5（呼び出し側。AC1/AC3/AC4 の判定条件に依存）
      ↓
AC6（全変更の検証。全 AC に依存）
```

## 5. Risks and Mitigations

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|------------|------------|
| R1 | `teammate-message` の残骸が SKILL.md に残り LLM が旧ロジックに従う | 中 | 低 | 実装後に `grep -r 'teammate-message' skills/{discover,plan,atdd}/SKILL.md` で 0 件確認。AC6 の残骸チェックテストでも検証。 |
| R2 | テスト更新漏れで BATS FAIL | 低 | 中 | AC6 で `bats tests/` 全件 PASS を確認 |
| R3 | Bug Flow Step 5 / Docs Flow Step 4 の autopilot 対応漏れ | 低 | 低 | これらは "same as development flow Step 7" と記述。Step 7 の変更が波及。ただし実装時にテキスト確認 |
| R4 | discover HARD-GATE 内の条件更新漏れ | 高 | 低 | AC1 の変更スコープに L15 を明示的に含めている |
| R5 | Skill description フィールドに `teammate-message` 残骸 | なし | なし | description は trigger 条件のみで autopilot 検出ロジックを含まない |

## 6. Verification Plan

実装完了後の検証手順:

1. `bats tests/test_discover_autopilot_approval.bats` — 全テスト PASS
2. `bats tests/` — 全テストスイート PASS（リグレッション確認）
3. `grep -r 'teammate-message' skills/discover/SKILL.md skills/plan/SKILL.md skills/atdd/SKILL.md` — 0 件（AUTOPILOT-GUARD/HARD-GATE/Step 7/Step 8 に旧ロジック残骸なし）
4. `grep -r '\-\-autopilot' skills/discover/SKILL.md skills/plan/SKILL.md skills/atdd/SKILL.md commands/autopilot.md` — 全変更箇所がヒット

## 7. Files NOT Changed (with rationale)

| File | Reason |
|------|--------|
| `.claude/rules/workflow-overrides.md` | autopilot 検出方式に言及していない |
| `agents/po.md`, `agents/developer.md`, `agents/qa.md` | Agent 定義は autopilot 検出ロジックを含まない |
| `CHANGELOG.md` | plan フェーズで扱う（versioning rule に従い PR 内で更新） |
| `.claude-plugin/plugin.json` | 同上 |
