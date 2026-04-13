# Implementation Strategy — Developer

**Issue:** #36 — feat: discover スキルに DoD + AC の二層構造を導入する
**Author:** Developer
**Date:** 2026-04-12
**Prior Decisions:** `docs/decisions/ac-review-developer.md`, `docs/decisions/ac-review-qa.md`

## 1. Target Files and Changes

### File 1: `skills/discover/SKILL.md` — 主要変更対象

**変更セクション:**

#### 1a — HARD-GATE (L13) の説明文更新

`deliverables (ACs or completion criteria)` → `deliverables (DoD, ACs, or completion criteria)` に更新し、DoD が共通成果物であることを明示する。

#### 1b — 説明文 (L25) 更新

`structured deliverables (ACs for dev tasks, completion criteria for docs/research)` → `structured deliverables (DoD for all tasks; User Story + ACs for code-change tasks; DoD replaces completion criteria for docs/research)` に更新。

#### 1c — Development Flow に Step 2.5 を挿入（DoD 導出）

Step 2（アプローチ探索）と Step 3（User Story 導出）の間に新ステップを挿入:

```
### Step 2.5: DoD Derivation

Based on the approved approach, derive the Definition of Done.

List verifiable completion conditions for this task. These are different from ACs:
- ACs describe **how** the feature behaves (user-visible behavior)
- DoD describes **when the task is complete** (delivery conditions)

Typical DoD items:
- Implementation passes all ACs
- All new code has tests at the appropriate layer
- No regression in existing tests (pass_rate maintained)
- PR review approved and merged

Confirm with user or proceed with defaults.
```

ステップ番号の繰り上げ: 現行 Step 3-8 → Step 3-9（内容は変更なし、番号のみ）。

#### 1d — Bug Flow に DoD 導出ステップを挿入（AC6 対応）

Bug Flow Step 4（Fix AC Derivation）の前に DoD 導出ステップを追加。Bug Flow の Issue コメントテンプレートに `### DoD` セクションを Root Cause の前に追加。

#### 1e — Refactoring Flow に DoD 必須項目を追記（AC7 対応）

Refactoring フロー説明セクションに以下を追加:

```
- **DoD required item:** Always include a DoD item stating "externally observable behavior is unchanged" 
  (verified by regression test suite).
```

#### 1f — Documentation/Research Flow の Step 3 改名

`### Step 3: Define Completion Criteria` → `### Step 3: DoD Derivation`

テキスト全体を「completion criteria」から「DoD」に書き換え。提示フォーマットを以下に変更:

```
Are these DoD items acceptable?

- [ ] [verifiable DoD item 1]
- [ ] [verifiable DoD item 2]
```

#### 1g — 全フローの Issue コメントテンプレートに DoD セクションを先頭追加（AC5 対応）

Development Flow Step 9（旧 Step 8）、Bug Flow Step 6、Docs/Research Flow Step 5 のテンプレートを更新:

```markdown
## discover Deliverables

### DoD (Definition of Done)
- [ ] [条件1]
- [ ] [条件2]
...

### Approach  ← 現行と同じ位置
...
```

コード変更タスクのテンプレートはその後に User Story + AC セクションが続く。

#### 1h — Mandatory Checklist に DoD 項目を追加

```
- [ ] DoD derivation step completed (Step 2.5 for dev/bug/refactoring; Step 3 for docs/research)
- [ ] DoD section is at the top of the Issue comment template
```

#### 1i — 「Completion Criteria」用語の完全廃止（AC4 対応）

全箇所（L13, L25, Step 3 heading, Step 3 body, Step 4 presentation, Step 5 template heading）で `completion criteria` / `Completion Criteria` を `DoD` / `Definition of Done` に置換。

---

### File 2: `skills/plan/SKILL.md` — 小規模変更（AC8 対応）

**変更箇所: Step 1 (L81-82)**

```
Before:
   - Development/bug/refactoring: User Story + ACs (Given/When/Then)
   - Documentation/research: completion criteria

After:
   - Development/bug/refactoring: DoD + User Story + ACs (Given/When/Then)
   - Documentation/research: DoD (replaces completion criteria)
```

`description` フィールド (L3) も更新:

```
Before:
description: "Create test strategy and implementation strategy from discover's ACs. Second step of the Issue Ready flow."

After:
description: "Create test strategy and implementation strategy from discover's deliverables (DoD + ACs). Second step of the Issue Ready flow."
```

---

### File 3: `skills/discover/evals/evals.json` — eval 更新（AC9 対応）

**変更対象: eval id=2 "documentation"**

assertion C1/C2 を更新して DoD ヘッダの存在を確認:

```json
{"id": "C1", "text": "完了基準が検証可能なチェックリスト形式で記述されている（曖昧な表現なし）", "type": "structural"},
{"id": "C2", "text": "成果物に 'DoD' または 'Definition of Done' セクションが含まれており、'Completion Criteria' という表記は使われていない", "type": "structural"},
```

**追加 eval assertions (dev-feature / bug-fix):**

dev-feature (id=0) に DoD 三層構造の検証アサーションを追加:

```json
{"id": "A8", "text": "成果物に 'DoD' または 'Definition of Done' セクションが含まれている", "type": "structural"},
{"id": "A9", "text": "DoD セクションが User Story セクションより前に配置されている", "type": "structural"}
```

bug-fix (id=1) に Bug Flow DoD の検証を追加:

```json
{"id": "B6", "text": "成果物に 'DoD' セクションが含まれており、Root Cause セクションより前に配置されている", "type": "structural"}
```

---

### File 4: `tests/test_discover_approach_parity.bats` — 影響なし

Step 2 の equal-detail ルールのみをテスト。Step 番号変更の影響を受けない（ヘッダ名称 `### Step 2: Approach Exploration` は変更しない）。

---

### File 5: `tests/test_discover_autopilot_approval.bats` — 軽微な影響確認が必要

Step 7/Step 8 の sed 抽出は `### Step 7` / `### Step 8` ヘッダに依存している。今回のステップ番号繰り上げ（Step 3-8 → Step 3-9）で Step 7/Step 8 ヘッダが変わる可能性がある。

**確認事項:** DoD ステップ挿入後、Step 7/Step 8 ヘッダが何番になるかを確認し、BATS テストのヘッダ抽出範囲を更新する。

---

### File 6: `CHANGELOG.md` — 必須更新

```markdown
## [Unreleased]
### Changed
- discover: DoD (Definition of Done) derivation step added to all task type flows
- discover: Documentation/Research flow "Completion Criteria" renamed to "DoD"
- discover: Code-change tasks (development/bug/refactoring) now produce DoD → User Story → AC three-layer structure
- plan: Step 1 updated to read new "DoD" heading from discover deliverables
```

---

### File 7: `.claude-plugin/plugin.json` — バージョンバンプ

`"version": "1.7.0"` → `"version": "1.8.0"` (minor feature addition)

---

## 2. Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| DoD 導出ステップを Step 2.5 として挿入（Step 3 にしない） | 既存 Step 3（User Story 導出）は DoD に依存しないため、DoD を先に導出してから User Story に進む順序が自然。既存 BATS テストの Step 番号依存箇所への影響を最小化するため中間ステップとして挿入。 |
| Bug Flow の DoD はコメントテンプレートの先頭に配置（Root Cause の前） | AC6 の Then 条件。Bug タスクでも「何を持って完了とするか」を最初に明示することがフローの一貫性を保つ。 |
| Refactoring フロー固有の DoD 必須項目をフロー説明に追記 | 既存 Refactoring Flow は Development Flow と同一パターンで動作するため、フロー本体には変更不要。フロー説明セクションに必須項目ルールを追記するだけで済む。 |
| `plan` SKILL.md は Step 1 テキストのみ変更（State Gate のパターンマッチは変更しない） | plan State Gate (L29) は `startswith("## discover Deliverables")` で Issue コメントを検出する。このヘッダは変更しないため State Gate のコマンドは変更不要。Step 1 の説明テキスト（人間可読）のみ更新する。 |
| evals.json の documentation eval を更新（新規 eval は追加しない） | 既存 eval で十分なカバレッジが得られる。新規 eval を追加すると baseline.json のリセットが必要になるため、既存 eval の assertion を更新する方針とする。 |
| Step 番号は繰り上げ（2.5 挿入、3-8 → 3-9）ではなく 3-8 → 3-9 としない | DoD ステップを「Step 2.5」として挿入することで既存 Step 3-8 の番号を保持し、BATS テストへの影響を最小化する。 |

---

## 3. AC Dependencies

```
AC4 (Completion Criteria 廃止 — 用語置換)
  ↓
AC1 (共通フロー DoD 導出ステップ挿入)
  ├── AC5 (テンプレート先頭配置 — AC1 のテンプレート変更に依存)
  ├── AC6 (Bug Flow DoD — AC1 と同一パターン)
  └── AC7 (Refactoring 必須項目 — AC1 のフロー説明追記)

AC3 (非コードタスク DoD のみ — Documentation/Research フロー変更)
  └── AC4 と連動（Completion Criteria → DoD の名称変更）

AC2 (三層構造 — AC1 + AC3 + AC5 が揃うと検証可能)

AC8 (plan スキル対応 — discover の新ヘッダに依存)
  └── AC1/AC3/AC4 の完了後に実施

AC9 (Eval regression guard — 全 AC の実装完了後に実施)
```

---

## 4. Implementation Order

| Order | AC(s) | 変更対象 | 理由 |
|-------|-------|---------|------|
| 1 | AC4 | discover SKILL.md: `Completion Criteria` を全箇所 `DoD` に置換 | 最小変更（用語置換のみ）。後続ステップのベースを作る。BATS negative テスト（AC4）が即座に検証可能。 |
| 2 | AC3 | discover SKILL.md: Documentation/Research フロー Step 3 を「DoD Derivation」に改名、テンプレート更新 | AC4 で用語を統一した後にフロー内容を変更。eval の documentation テスト (C1/C2) の assertion 更新も同時に行う。 |
| 3 | AC1 + AC5 | discover SKILL.md: Development フローに Step 2.5 挿入、全フローテンプレート先頭に DoD セクション追加 | Development フロー本体と全テンプレートの変更。AC5 はテンプレート変更の一部なので同一コミットで対応。 |
| 4 | AC6 | discover SKILL.md: Bug Flow DoD ステップ追加、Bug Flow テンプレート更新 | Bug フロー固有の変更。AC1 で確立したパターンを適用。 |
| 5 | AC7 | discover SKILL.md: Refactoring フロー説明に DoD 必須項目追記 | 最小変更（フロー説明への追記のみ）。 |
| 6 | AC2 | evals.json: dev-feature/bug-fix eval に DoD assertion 追加 | AC1/AC6 完了後に eval を拡張して三層構造を検証。 |
| 7 | AC8 | plan SKILL.md: Step 1 テキスト、description 更新 | discover 側の変更が確定した後に plan 側を更新。 |
| 8 | AC9 | BATS テスト更新 + bats 実行 + eval 実行 | 全変更完了後に BATS 全件 PASS を確認。auto-eval で pass_rate 検証。 |
| 9 | — | CHANGELOG.md + plugin.json バンプ | 最後に versioning ルールに従い更新。 |

### Commit Strategy

| Commit | AC(s) | Message |
|--------|-------|---------|
| 1 | AC4 | `refactor: AC4 -- discover Completion Criteria を DoD に用語統一 (#36)` |
| 2 | AC3 | `feat: AC3 -- discover Documentation/Research フローを DoD フォーマットに移行 (#36)` |
| 3 | AC1 + AC5 | `feat: AC1+AC5 -- discover Development フローに DoD 導出ステップ追加、全テンプレートに先頭 DoD セクション (#36)` |
| 4 | AC6 | `feat: AC6 -- discover Bug Flow に DoD セクション追加 (#36)` |
| 5 | AC7 | `feat: AC7 -- discover Refactoring フローに DoD 必須項目追記 (#36)` |
| 6 | AC2 + eval | `test: AC2 -- evals.json に DoD 三層構造 assertion 追加 (#36)` |
| 7 | AC8 | `feat: AC8 -- plan スキルを discover の新 DoD ヘッダに対応 (#36)` |
| 8 | AC9 + BATS | `test: AC9 -- BATS テスト更新、eval regression guard 確認 (#36)` |
| 9 | — | `chore: v1.8.0 CHANGELOG + plugin.json バンプ (#36)` |

---

## 5. Risks and Mitigations

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|------------|------------|
| R1 | eval pass_rate が 10% 以上低下（AC9 violation） | 高 | 中 | 変更前後で eval を実行して比較。evals.json の assertion 更新（C2, A8/A9, B6）と SKILL.md の変更が整合することを確認してから PR 提出。 |
| R2 | `plan` Step 1 が "DoD" ヘッダを含む doc/research コメントを "User Story + ACs" として誤判定する | 中 | 低 | plan Step 1 は "User Story + ACs (Given/When/Then)" vs "DoD (replaces completion criteria)" を区別するテキストを追加することで対応。AC8 の eval assertion でも検証。 |
| R3 | BATS の Step 番号依存テストが Step 2.5 挿入で誤検出 | 低 | 中 | `test_discover_autopilot_approval.bats` の sed 抽出は `### Step 7` / `### Step 8` ヘッダ名称に依存。Step 2.5 挿入後も Step 7/Step 8 の番号が変わらないことを確認する（DoD ステップが Step 2.5 なら繰り上げ不要）。 |
| R4 | Mandatory Checklist 更新漏れ | 低 | 低 | AC1 実装時にチェックリストへの DoD 項目追加を明示的なサブタスクとして含める。 |
| R5 | Bug Flow / Docs フローの eval が新フォーマットに対応していない | 中 | 低 | AC2/AC6 の eval assertion 更新を実装コミットと同一 PR に含める。 |

---

## 6. Verification Plan

実装完了後の検証手順（AC9 対応）:

1. `bats /Users/o3/github.com/o3-ozono/atdd-kit/.claude/worktrees/autopilot-36/tests/` — 全テスト PASS
2. `/atdd-kit:auto-eval` — pass_rate が baseline (1.0) から 10% 以上低下しないことを確認
3. `grep -n "Completion Criteria" skills/discover/SKILL.md` — 0 件（AC4 達成確認）
4. `grep -n "DoD\|Definition of Done" skills/discover/SKILL.md` — 各フローに DoD 導出ステップが存在することを確認

---

## 7. Files NOT Changed (with rationale)

| File | Reason |
|------|--------|
| `skills/atdd/SKILL.md` | atdd は discover 成果物の「AC リスト」を読むだけ。DoD セクションが追加されても AC Given/When/Then の読み取りには影響しない。 |
| `skills/verify/SKILL.md` | verify は AC に対する証拠確認を行う。DoD セクションが追加されても verify の動作は変わらない。 |
| `commands/autopilot.md` | autopilot は discover の成果物フォーマットに依存しない（Issue コメントの読み取りは plan が担当）。 |
| `tests/test_discover_approach_parity.bats` | Step 2 の equal-detail ルールのみテスト。今回の変更で影響を受けない。 |
| `.claude/rules/workflow-overrides.md` | DoD 構造変更に言及していない。 |
