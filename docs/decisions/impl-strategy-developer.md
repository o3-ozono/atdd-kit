# Implementation Strategy — Developer

**Issue:** #41 — feat: エージェント構成を plan の成果物に含め、plan 承認時にまとめて承認する
**Author:** Developer
**Date:** 2026-04-13
**Prior Decisions:** `docs/decisions/ac-review-developer.md`, `docs/decisions/ac-review-qa.md`

## 1. Target Files and Changes

### File 1: `skills/plan/SKILL.md` — 主要変更対象

**変更セクション:**

#### 1a — Step 4: Implementation Strategy に Agent Composition 導出ステップを追加（AC2 対応）

Step 4 の末尾（Implementation Strategy の最後の項目として）に Agent Composition 導出ステップを追加:

```markdown
5. **Agent Composition** — Variable-Count Agents（Reviewer, Researcher）の人数と観点/テーマを決定する

タスクタイプに応じて以下の観点で具体化する:

| Task Type | Variable-Count Agents | 決定基準 |
|-----------|----------------------|---------|
| development / refactoring / bug | Reviewer x N | PR の変更規模・技術リスクに応じて観点別に決定 |
| research | Researcher x N (min 2 per theme) | テーマ数に応じて 1 テーマ 1 エージェント以上 |
| documentation | Reviewer x N | ドキュメント規模・対象読者の観点で決定 |

人数・観点の具体化基準:
- 変更範囲が 1 ファイル・単一機能 → Reviewer x 1
- 複数コンポーネントにまたがる / セキュリティ・パフォーマンス影響あり → Reviewer x 2+
- テーマが明確に分離できる → Researcher x テーマ数
```

#### 1b — Step 5: Readiness Check に Agent Composition チェック項目を追加（AC3 対応）

既存の Readiness Check テーブルに新行を追加:

```
| Variable-Count Agents の人数・観点が具体化されている | "Reviewer x N"（人数未定） | "Reviewer x 2: (1) セキュリティ観点 (2) パフォーマンス観点" |
```

#### 1c — Step 6: Issue コメントフォーマットに `### Agent Composition` セクションを追加（AC2 対応）

Implementation Strategy と Readiness Check の間に `### Agent Composition` セクションを追加:

```markdown
### Agent Composition

| Phase | Role | Count | Focus |
|-------|------|-------|-------|
| Phase 3 | [Reviewer / Researcher / Writer] | [N] | [観点またはテーマ] |
| Phase 4 | [Reviewer] | [N] | [観点] |
```

Variable-Count Agents を使わない Phase は「該当なし」と明示する。

#### 1d — Readiness Check のコメントフォーマット内にも追加（Step 6 テンプレート整合）

Step 6 の Readiness Check 出力テンプレートブロックにも Agent Composition チェック行を追加:

```
| Variable-Count Agents の人数・観点が具体化されている | OK / NG: [reason] |
```

---

### File 2: `commands/autopilot.md` — 変更対象

**変更箇所 1: Variable-Count Agents セクション改訂（AC4 対応）**

現行の承認ステップ（4 ステップの承認手順）を削除し、plan-based 起動に変更:

```markdown
### Variable-Count Agents (Reviewer, Researcher)

Reviewer and Researcher agents have variable count (x N). The composition (count and focus/themes)
is determined and approved at plan time as part of the `### Agent Composition` section.

When spawning Variable-Count Agents in Phase 3/4:
1. Read the `### Agent Composition` section from the plan comment in the Issue
2. Spawn agents according to the approved composition directly — no additional user approval required
3. If the plan comment does not contain an `### Agent Composition` section: report error and STOP
   (see Autonomy Rules — failure mode)
```

**変更箇所 2: Plan Review Round の Developer への SendMessage 指示に Agent Composition レビュー観点を追加（AC5 対応）**

Plan Review Round の Developer レビュー指示に以下を追加:

```
- **Developer:** ファイル構成の妥当性、実装順序のリスク、技術リスク評価、**Agent Composition の妥当性（人数・観点の具体性）** — write results to `docs/decisions/plan-review-developer.md`
```

**変更箇所 3: Phase 0.9 Mid-phase resume に plan 不在時の安全停止処理を追加（AC7 対応）**

Phase 0.9 の Step 6（Mid-phase resume）に以下の注記を追加:

```
- Phase 3/4 への resume 時は plan コメント（`## Implementation Plan` + `### Agent Composition` セクション）が
  Issue に存在することを確認する。存在しない場合は「plan が未完了です。Phase 2 から再実行してください」と
  報告して STOP する。
```

---

### File 3: `docs/workflow-detail.md` — ドキュメント整合確認（AC6 対応）

Variable-Count Agents の承認フローに関する記述を確認し、旧フロー（spawn 時承認）への言及があれば plan 承認ベースに更新する。

現時点では `docs/workflow-detail.md` には Variable-Count Agents の spawn 時承認への直接言及は見当たらないが、atdd フェーズで grep 確認を実施する:

```bash
grep -n "user.*approval\|承認.*spawn\|spawn.*approval\|Variable-Count\|variable-count" docs/workflow-detail.md docs/issue-ready-flow.md
```

残存する旧フロー記述があれば plan-based 承認に合わせて更新する。

---

### File 4: `CHANGELOG.md` — 必須更新

```markdown
## [Unreleased]
### Changed
- plan: Agent Composition section added to plan deliverables (Step 4, Step 6, Readiness Check)
- autopilot: Variable-Count Agents now spawned from plan-approved composition without additional user approval
- autopilot: Plan Review Round now includes Agent Composition review by Developer
- autopilot: Mid-phase resume includes safety check for missing plan/Agent Composition
```

---

### File 5: `.claude-plugin/plugin.json` — バージョンバンプ

`version` を minor バンプ（機能追加のため）。具体的な現行バージョンは atdd フェーズで `plugin.json` を読んで確認する。

---

## 2. Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Agent Composition を `### Agent Composition` として独立セクション（Step 6 テンプレートの最上位 h3）にする | Issue 本文の採用 Approach A と一致。Implementation Strategy のサブセクションではなく独立セクションにすることでレビュー視認性が高まり、autopilot が grep で特定しやすい。 |
| Step 4 に Agent Composition 導出ステップを「5番目の項目」として追加する | Step 4 は既に Target Files / Architecture Decisions / Dependencies / Risks の 4 項目。Agent Composition は "どう実装するか" の一部（誰が実装・レビューするかの決定）であり Step 4 に含める方が自然。独立した Step にすると Step 番号が繰り上がり BATS テストへの影響が大きい。 |
| Variable-Count Agents セクションの 4 ステップ承認手順を完全削除（変更ではなく削除）する | 旧フロー（承認要求）と新フロー（plan-based）が共存すると混乱を招く。AC4 は「承認要求が消えている」ことを静的検証で確認するため、記述を削除して新フローに置き換える。 |
| mid-phase resume の安全停止を Phase 0.9 に追加する（新規 Phase は作らない） | Phase 0.9 は既に mid-phase resume の処理を記述している。そこに plan 不在チェックを追加するのが最小変更。 |
| docs/ の整合確認を atdd フェーズで grep で実施する | `docs/workflow-detail.md` を今回読んだ結果、Variable-Count Agents の spawn 時承認への直接言及は確認されていない。ただし AC6 の DoD で「既存ドキュメントと矛盾しない」が要求されているため atdd フェーズで明示的に確認する。 |

---

## 3. AC Dependencies

```
AC2 (SKILL.md Step 4 + Step 6 へのテンプレート追加)
  ↓
AC3 (SKILL.md Step 5 Readiness Check 項目追加 — AC2 のテンプレートに依存)
  ↓
AC1 (plan 成果物コメントに Agent Composition セクション存在 — AC2/AC3 の実装で実現)

AC4 (autopilot.md Variable-Count Agents セクション改訂 — AC2 と並列実装可能)
  ↓
AC5 (autopilot.md Plan Review Round 改訂 — AC4 と同ファイル、順序任意)
  ↓
AC7 (autopilot.md mid-phase resume 安全停止 — AC4 の前提チェックとして追加)

AC6 (docs/ 整合確認 — AC4/AC5 完了後に grep で確認)
```

---

## 4. Implementation Order

| Order | AC(s) | 変更対象 | 理由 |
|-------|-------|---------|------|
| 1 | AC2 | `skills/plan/SKILL.md`: Step 4 Agent Composition 導出ステップ追加 | 成果物フォーマットの中核。Step 6 テンプレートはここが確定してから変更する。 |
| 2 | AC2 続き | `skills/plan/SKILL.md`: Step 6 コメントテンプレートに `### Agent Composition` 追加 | Order 1 と同一コミット可（同一 AC、同一ファイル）。 |
| 3 | AC3 | `skills/plan/SKILL.md`: Step 5 Readiness Check に Agent Composition 行追加 | Order 1/2 で確定したテンプレートを Readiness Check が確認できる状態にする。 |
| 4 | AC4 | `commands/autopilot.md`: Variable-Count Agents セクション改訂（旧承認手順削除、plan-based 起動に変更） | SKILL.md 側が確定してから autopilot.md を変更する順序が安全。 |
| 5 | AC5 | `commands/autopilot.md`: Plan Review Round Developer 指示に Agent Composition レビュー追加 | AC4 と同一ファイル、同一コミット可。 |
| 6 | AC7 | `commands/autopilot.md`: Phase 0.9 mid-phase resume に plan 不在時 STOP 追加 | AC4/AC5 と同一ファイル、同一コミット可。 |
| 7 | AC6 | `docs/` 整合確認 + 必要に応じて更新 | 全変更完了後に grep で確認し、残存する旧フロー記述を修正する。 |
| 8 | AC1 | verify で plan コメントフォーマット確認 | AC1 は AC2/AC3 の実装が正しければ自動的に達成される。verify フェーズで確認。 |
| 9 | — | CHANGELOG.md + plugin.json バンプ | 最後に versioning ルールに従い更新。 |

### Commit Strategy

| Commit | AC(s) | Message |
|--------|-------|---------|
| 1 | AC2 + AC3 | `feat: AC2+AC3 -- plan スキルに Agent Composition 導出ステップ・テンプレート・Readiness Check 追加 (#41)` |
| 2 | AC4 + AC5 + AC7 | `feat: AC4+AC5+AC7 -- autopilot Variable-Count Agents を plan-based 起動に変更、mid-phase resume 安全停止追加 (#41)` |
| 3 | AC6 | `fix: AC6 -- docs/ の Variable-Count Agents 旧承認フロー記述を plan-based に更新 (#41)` |
| 4 | — | `chore: v[N+1].0 CHANGELOG + plugin.json バンプ (#41)` |

---

## 5. Risks and Mitigations

| # | Risk | Impact | Likelihood | Mitigation |
|---|------|--------|------------|------------|
| R1 | autopilot.md の Variable-Count Agents セクション削除で Phase 3/4 の Reviewer spawn が壊れる | 高 | 低 | 削除対象は承認手順の 4 ステップのみ。spawn コマンド自体（Agent tool call）は Phase 3/4 の実装手順に残す。変更後の autopilot.md を読み返して spawn 命令の欠落がないことを確認。 |
| R2 | SKILL.md の Step 6 テンプレートに Agent Composition を追加することで既存の plan コメントが旧フォーマットのまま残り、autopilot の parse が失敗する | 中 | 低 | 今回の変更は新規 Issue への適用のみ。既存の plan コメントは再 plan することで更新される。旧フォーマット parse 失敗時は AC7 の安全停止が機能する。 |
| R3 | docs/ の grep で旧フロー記述が想定外の多数ファイルに存在し、変更スコープが肥大化する | 低 | 低 | `docs/workflow-detail.md` の確認済み範囲では直接言及は 1 件（「Agent Lifecycle」）のみ。追加言及が見つかった場合は PO に報告してスコープを調整する。 |
| R4 | Plan Review Round の Developer SendMessage 指示に Agent Composition を追加した結果、Developer が plan-review-developer.md に Agent Composition 評価を書かず QA が書く誤動作が発生する | 低 | 低 | AC5 の Then 条件が「Developer only。QA の指示には含めない」と明記しているため、Developer/QA 両方の SendMessage 指示を確認して QA 側には含めないことを保証する。 |

---

## 6. Verification Plan

実装完了後の確認手順:

```bash
# AC2 確認: SKILL.md に Agent Composition テンプレートが存在する
grep -n "Agent Composition" skills/plan/SKILL.md

# AC3 確認: Readiness Check に Variable-Count Agents 行が存在する
grep -n "Variable-Count Agents" skills/plan/SKILL.md

# AC4 確認: autopilot.md から旧承認手順が削除されている
grep -n "presents the proposed composition to the user for approval" commands/autopilot.md
# → 0 件であること

# AC5 確認: Plan Review Round に Agent Composition レビュー観点が存在する（Developer のみ）
grep -n "Agent Composition" commands/autopilot.md

# AC6 確認: docs/ に旧フロー記述が残存しない
grep -rn "user.*approval.*spawn\|spawn.*approval\|presents the proposed composition" docs/

# AC7 確認: mid-phase resume に plan 不在時 STOP 記述が存在する
grep -n "plan.*未完了\|plan.*not.*found\|Agent Composition.*STOP" commands/autopilot.md
```

---

## 7. Files NOT Changed (with rationale)

| File | Reason |
|------|--------|
| `skills/atdd/SKILL.md` | atdd は AC を実装するだけ。plan 成果物フォーマットへの依存なし。 |
| `skills/discover/SKILL.md` | discover は plan の前段。Agent Composition は plan フェーズで決定される。 |
| `skills/verify/SKILL.md` | verify は AC 証拠確認。Agent Composition の spawn 手順とは無関係。 |
| `agents/` 配下のエージェント定義 | agent の役割・system_prompt の変更は不要。spawn 呼び出し方法（plan-based）を autopilot.md で制御するのみ。 |
| `tests/` 配下の BATS テスト | 現時点で plan/autopilot の SKILL.md を直接テストする BATS は存在しない（discover eval が中心）。atdd フェーズで確認し、影響があれば更新する。 |

---

## 8. Agent Composition for Phase 3/4

本 Issue の変更成果物自身が「Agent Composition を plan に含める機能」の初回適用対象となる。

### Phase 3

| Role | Count | Focus |
|------|-------|-------|
| Developer | 1 | ATDD 実装（SKILL.md 変更、autopilot.md 変更、docs/ 整合修正） |

**理由:** 変更対象は Markdown ファイル 2〜3 本のみ（`skills/plan/SKILL.md`、`commands/autopilot.md`、`docs/workflow-detail.md` の軽微な更新）。単一コンポーネント、セキュリティ/パフォーマンス影響なし → Developer x 1 で十分。

### Phase 4

| Role | Count | Focus |
|------|-------|-------|
| Reviewer | 1 | 機能整合性 — AC1〜AC7 の達成確認、SKILL.md と autopilot.md の変更が互いに整合していること、旧承認手順の完全削除確認 |
| Reviewer | 2 | ドキュメント品質 — `### Agent Composition` テンプレートの記述が明確で PO が実際に使えるレベルか、Bad/Good 例が分かりやすいか |

**理由:** 今回の変更は「ワークフロー手順の変更」であり、動作ロジックのバグよりもドキュメント品質・整合性の問題が発生しやすい。AC 達成の静的検証（grep ベース）が主なので、レビュー観点は機能整合性とドキュメント品質の 2 軸で分担するのが適切。Reviewer x 2 で十分。
