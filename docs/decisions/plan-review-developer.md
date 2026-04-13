# Plan Review — Developer Perspective

**Issue:** #36 — feat: discover スキルに DoD + AC の二層構造を導入する
**Reviewer:** Developer
**Date:** 2026-04-12
**Reviewed artifact:** `docs/decisions/unified-plan.md`

## File Composition Validity

**Target Files（6ファイル）の評価:**

| File | 妥当性 |
|------|--------|
| `skills/discover/SKILL.md` | OK — 主要変更対象として正しい |
| `skills/plan/SKILL.md` | OK — AC8 対応として必要 |
| `skills/discover/evals/evals.json` | OK — AC9 eval assertion 更新として必要 |
| `tests/test_discover_dod_structure.bats` | OK — 新規 BATS テストとして必要 |
| `CHANGELOG.md` | OK — versioning rule に従い必須 |
| `.claude-plugin/plugin.json` | OK — v1.8.0 バンプとして必須 |

**漏れているファイル（3件）:**

1. `docs/issue-ready-flow.md` (L45): `"Define completion criteria"` という表記が残存している。AC4（Completion Criteria 廃止）の対象となるはずだが Target Files に含まれていない。
2. `commands/autopilot.md` (L267): `"completion criteria"` という表記が研究フロー完了確認の文脈で使われている。用語統一の対象。
3. `commands/maintenance.md` (L94): `### Completion Criteria` というセクションヘッダが存在する。スキル固有の内容ではないため影響は小さいが確認が必要。

**過剰追加:** なし。6ファイルはいずれも変更理由を持つ。

**判定:** MINOR — 3ファイルの漏れあり。AC4 の BATS grep assertion（AC4: `grep` で "Completion Criteria" が 0 件）で実装後に検出可能だが、事前に Target Files に追加することで実装手戻りを防げる。

---

## Implementation Order Risk

**Commit 順序と依存関係の評価:**

```
Commit 1: AC4 (用語置換)
  ↓ 前提条件なし — 最初に実施するのは正しい
Commit 2: AC3 (Docs フロー改名)
  ↓ AC4 の用語統一後に実施 — 依存関係OK
Commit 3: AC1 + AC5 (Development フロー DoD ステップ挿入 + テンプレート更新)
  ↓ AC4 の用語統一後 — OK
Commit 4: AC6 (Bug Flow DoD)
  ↓ AC1 のパターン確立後 — OK
Commit 5: AC7 (Refactoring 必須項目)
  ↓ AC1 のパターン確立後 — OK
Commit 6: AC2 (evals assertion 追加)
  ↓ AC1/AC3/AC6 完了後に eval を拡張 — OK
Commit 7: AC8 (plan SKILL.md 更新)
  ↓ AC1/AC3/AC4 完了後 — OK
Commit 8: AC9 (BATS + eval 実行)
  ↓ 全変更完了後 — OK
Commit 9: CHANGELOG + version bump
  ↓ 最後 — versioning rule に従い正しい
```

**潜在的リスク:**

- Commit 6 (AC2 — evals.json) の前に Commit 8 (BATS テスト) が来ると、新規 BATS テストが evals.json 更新前に実行されて意図しない状態をテストすることになる。現行の順序（Commit 6 が先、Commit 8 が後）は正しい。
- Commit 3 が AC1 + AC5 を同一コミットに含めている。Development フローへの DoD ステップ挿入（AC1）と全フローテンプレートの先頭 DoD セクション追加（AC5）は相互依存があり、同一コミットとするのは合理的。ただし Commit 3 は `skills/discover/SKILL.md` の複数箇所を大規模に変更するため、レビュアーへの説明コストが高い。

**判定:** OK — 依存関係を満たしている。リスクは低い。

---

## Technical Risk Assessment

**R1 — eval pass_rate が 10% 以上低下（AC9 violation）: HIGH impact**

評価: **適切に識別されている。ただし baseline 比較の有効性に注意が必要。**

evals.json の assertion 文言を変更した場合（C2 の更新、C5 の追加など）、baseline.json に記録された pass_rate は「旧 assertion でのパス」を意味する。新 assertion で pass_rate が 0.7 になっても baseline との差分は -0.3 であり 10% 超となる。しかし assertion 変更自体が仕様変更であるため、「旧 assertion のベースラインを新 assertion の結果と比較する」ことに意味がない。unified-plan の AC9 手順 Step 5「PASS 後に baseline.json を更新」は正しい方針だが、Commit 8 に `skills/discover/evals/baseline.json` の更新が含まれることを Target Files に明示すべき（現行では `baseline.json` が Target Files に含まれていない）。

**R2 — plan Step 1 の誤判定: MEDIUM impact**

評価: **適切に識別されており、解決策も正しい。** plan SKILL.md Step 1 の検出テキストを `"Documentation/research: DoD"` に更新し、AC8 の BATS で検証する計画は正しい。問題なし。

**R3 — Step 番号依存テストが Step 2.5 挿入で誤検出: LOW impact**

評価: **適切に識別されており、解決策も正しい。** Step 2.5 挿入により既存の `### Step 7` / `### Step 8` ヘッダが変わらないため、`test_discover_autopilot_approval.bats` の sed 抽出パターンは継続して機能する。ただし Bug フローと Docs フローにも DoD ステップを挿入する場合（AC6/AC3）、それぞれのフローの内部ステップ番号が増える。Bug フロー（現行 Step 1-6）に DoD ステップを挿入すると内部的に Step 1-7 になる。現行の BATS テストは Development フローの Step 7/8 のみを grep しており Bug フローのステップ番号を参照していないため影響は限定的だが、新規 BATS テスト（`test_discover_dod_structure.bats`）でどのステップ番号を参照するかは実装時に確認が必要。

**R4 — Mandatory Checklist 更新漏れ: LOW impact**

評価: 適切に識別されている。AC1 コミットにサブタスクとして明示しているため管理可能。

**未識別リスク R5 — baseline.json が Target Files に含まれていない**

Commit 8（AC9）で eval を実行して pass_rate を確認した後、`skills/discover/evals/baseline.json` を新しい pass_rate で更新する必要がある。この更新がコミットに含まれないと、次回の eval 実行時に古い baseline で比較されてしまう。`baseline.json` を Commit 8 または Commit 9 の Target Files に追加することを推奨。

**未識別リスク R6 — 「Completion Criteria」が discover 以外のファイルに残存**

`docs/issue-ready-flow.md`, `commands/autopilot.md`, `commands/maintenance.md` に "Completion Criteria" / "completion criteria" の表記が残存しているが Target Files に含まれていない（File Composition Validity セクション参照）。AC4 の BATS assertion が `skills/discover/SKILL.md` のみを対象にしている場合、これらのファイルは検証対象から漏れる。assertion を「SKILL.md 全体」に限定するのか「リポジトリ全体」に広げるのかを明確化すべき。

---

## Architecture Decisions

**1. DoD 導出ステップを Step 2.5 として挿入（繰り上げしない）**

評価: **妥当。** Step 7/8 に依存する BATS テスト（`test_discover_autopilot_approval.bats`）への影響を最小化できる。"Step 2.5" というラベルは SKILL.md のマークダウン構造として若干の不自然さがあるが、LLM はステップ番号よりも見出し名とコンテンツを読むため動作への影響はない。実装上の問題なし。

**2. Bug Flow の DoD をテンプレート先頭（Root Cause の前）に配置**

評価: **妥当。** AC6 の Then 条件に合致。フローの一貫性（全タスクタイプで DoD が先頭）を保てる。

**3. Refactoring フロー固有の DoD 必須項目はフロー説明に追記（フロー本体は変更しない）**

評価: **妥当だが、追記場所の明確化が必要。** Refactoring フローのセクション説明への追記は最小変更として正しい。ただし unified-plan には「どの見出しの下に何行追記するか」が明示されていない。実装者の判断余地が残っており、追記場所が不一致になるリスクがある。実装コミット時に確認が必要。

**4. plan SKILL.md は Step 1 テキストのみ変更（State Gate は変更しない）**

評価: **妥当。** plan の State Gate は `startswith("## discover Deliverables")` でコメントを検出しており、このヘッダは変更しないため State Gate への影響はない。

**5. evals.json の既存 eval を更新（新規 eval は追加しない）**

評価: **妥当。** baseline.json のリセット不要。ただし R5 で指摘したとおり、assertion 変更後の baseline.json 更新は Commit 8 または Commit 9 に明示的に含める必要がある。

---

## Commit Strategy Granularity

| Commit | 粒度評価 |
|--------|---------|
| 1 (AC4 — 用語置換のみ) | 適切。単一の機械的変更 |
| 2 (AC3 — Docs フロー改名) | 適切。単一フローの変更 |
| 3 (AC1+AC5) | やや大きい。`skills/discover/SKILL.md` の複数箇所を同時変更（Step 2.5 挿入 + 全フローテンプレート更新）。分割するとしたら AC1（Step 2.5 挿入）と AC5（テンプレート先頭配置）を別 commit にする方法があるが、両者は実質的に同一変更セットなので同一 commit でも許容範囲。 |
| 4 (AC6 — Bug Flow) | 適切。単一フローの変更 |
| 5 (AC7 — Refactoring) | 適切。最小変更 |
| 6 (AC2 — evals) | 適切。`test:` プレフィックスが正しい |
| 7 (AC8 — plan) | 適切。別ファイルの小規模変更 |
| 8 (AC9 — BATS + eval) | **baseline.json の扱いが不明瞭。** BATS テストファイル新規作成（`test_discover_dod_structure.bats`）は commit に含まれるが、eval 実行後の `baseline.json` 更新が含まれるかどうかが不明。Commit 8 または Commit 9 に `baseline.json` の更新を明示的に含めること。 |
| 9 (CHANGELOG + バンプ) | 適切。versioning rule に従う |

---

## Verdict

APPROVE WITH CHANGES

Target Files に `docs/issue-ready-flow.md`、`commands/autopilot.md`、`commands/maintenance.md`（AC4 の Completion Criteria 廃止対象）と `skills/discover/evals/baseline.json`（AC9 の eval 実行後更新対象）が含まれていない。いずれも BLOCKER ではなく実装中に対処可能だが、事前に Target Files へ追加することを推奨する。
