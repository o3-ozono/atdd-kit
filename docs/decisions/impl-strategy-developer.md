# Implementation Strategy: Developer

**Issue:** #11 — bug: Autonomy Rules に Agent tool 再生成禁止規則が欠落
**Author:** Developer Agent
**Date:** 2026-04-12

## 1. 変更箇所の一覧

対象ファイルは `commands/autopilot.md` のみ。全 6 箇所の変更。

| # | セクション | 行番号 | AC | 変更内容 |
|---|-----------|--------|-----|---------|
| C1 | Autonomy Rules | L110 の後（L111 の前） | AC1 | Rule 5 追加 |
| C2 | Phase 2: plan | L148 の後 | AC2 | SendMessage 専用ガード注意書き |
| C3 | Plan Review Round | L162 の後 | AC2 | SendMessage 専用ガード注意書き |
| C4 | Phase 3: Implementation | L177 の後 | AC2 | SendMessage 専用ガード注意書き |
| C5 | Phase 4: PR Review | L189 の後 | AC2 | SendMessage 専用ガード注意書き |
| C6 | Phase 0.9 Mid-phase resume | L100 の後 | AC3 | Autonomy Rule 5 への逆参照 |

## 2. 各変更の具体的な内容

### C1: Autonomy Rules — Rule 5 追加 (AC1)

**挿入位置:** L110（Rule 4）の直後、L111（空行）の前

**追加テキスト:**
```markdown
5. **Agent re-generation** — Once Developer and QA are spawned in AC Review Round, do not create new instances of these agents in Phase 2–4. Communicate with existing agents exclusively via SendMessage. Exception: Phase 0.9 Mid-phase resume handles session-restart re-creation only.
```

**設計判断:**
- "Agent tool" という文字列を使わず "create new instances" で表現。理由: 既存テスト `#165-AC1` (L230-231) が `grep -q 'Use Agent tool.*Developer'` で Phase 2/3 内の否定検査をしている。Autonomy Rules セクションは Phase 2/3 の `grep -A 15` 範囲外なのでテスト上は問題ないが、将来のテスト拡張に備えて安全な表現を採用
- Phase 0.9 例外を同一文中に明記し、例外の根拠を自明にする

### C2: Phase 2 — SendMessage 専用ガード (AC2)

**挿入位置:** L148（既存の説明文）の直後、L150（手順 1）の前

**追加テキスト:**
```markdown
> **Constraint:** New agent creation is prohibited in this phase. Communicate with existing Developer/QA agents via SendMessage only (see Autonomy Rule 5).
```

**設計判断:**
- blockquote (`>`) で視覚的に目立たせる
- "Use Agent tool" は使わず "New agent creation is prohibited" で表現 — テスト `#165-AC1` L230 の `! grep -A 15 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'Use Agent tool.*Developer'` に抵触しない
- "see Autonomy Rule 5" で根拠を参照可能にする

### C3: Plan Review Round — SendMessage 専用ガード (AC2)

**挿入位置:** L162（既存の説明文）の直後、L164（手順 1）の前

**追加テキスト:**
```markdown
> **Constraint:** New agent creation is prohibited in this phase. Communicate with existing Developer/QA agents via SendMessage only (see Autonomy Rule 5).
```

### C4: Phase 3 — SendMessage 専用ガード (AC2)

**挿入位置:** L177（既存の説明文）の直後、L179（手順 1）の前

**追加テキスト:**
```markdown
> **Constraint:** New agent creation is prohibited in this phase. Communicate with existing Developer agent via SendMessage only (see Autonomy Rule 5).
```

**注意:** Phase 3 は Developer のみ。QA への言及は不要。

### C5: Phase 4 — SendMessage 専用ガード (AC2)

**挿入位置:** L189（既存の説明文）の直後、L191（手順 1）の前

**追加テキスト:**
```markdown
> **Constraint:** New agent creation is prohibited in this phase. Communicate with existing QA agent via SendMessage only (see Autonomy Rule 5).
```

**注意:** Phase 4 は QA のみ。Developer への言及は不要。

### C6: Phase 0.9 Mid-phase resume — 逆参照追加 (AC3)

**挿入位置:** L100（`Then proceed to the determined phase using SendMessage.`）の直後

**追加テキスト:**
```markdown
   Note: This mid-phase resume is the sole exception to Autonomy Rule 5 (Agent re-generation prohibition). It applies only when agents do not exist in the current session due to a session restart.
```

**設計判断:**
- インデント（3 スペース）で Mid-phase resume のサブ項目として配置
- "sole exception" で例外が唯一であることを明示
- "session restart" で適用条件を限定

## 3. 実装順序

依存関係: C1（Rule 5 定義）→ C2〜C5（Rule 5 参照）、C6（Rule 5 逆参照）

```
Step 1: C1 — Autonomy Rules に Rule 5 追加 (AC1)
  └── 他の全変更が "Autonomy Rule 5" を参照するため、最初に実施

Step 2: C2, C3, C4, C5 — Phase 2〜4 注意書き追加 (AC2)
  └── 互いに独立。上から順に実施（ファイル内の行番号順）

Step 3: C6 — Phase 0.9 逆参照追加 (AC3)
  └── Rule 5 の存在に依存

Step 4: 既存テスト全パス確認 (AC4)
  └── bats tests/test_autopilot_agent_teams_setup.bats を実行
```

**AC → Step マッピング:**

| AC | Step | 変更 |
|----|------|------|
| AC1 | Step 1 | C1 |
| AC2 | Step 2 | C2, C3, C4, C5 |
| AC3 | Step 3 | C6 |
| AC4 | Step 4 | テスト実行（コード変更なし） |

## 4. 技術リスクと対策

### Risk 1: 既存テスト `#165-AC1`, `#165-AC2` との衝突 (High priority)

**リスク:** 注意書きに "Use Agent tool" を含めると、以下の既存テストが失敗する:
- L230: `! grep -A 15 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'Use Agent tool.*Developer'`
- L231: `! grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q 'Use Agent tool.*Developer'`
- L253: `! grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'Use Agent tool.*QA'`
- L254: `! grep -A 15 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q 'Use Agent tool.*QA'`

**対策:** 注意書きでは "New agent creation is prohibited" を使い、"Use Agent tool" を回避。Autonomy Rules セクションの Rule 5 も "create new instances" で表現。

**検証方法:** 各変更後に `grep -A 15 "## Phase 2: plan" commands/autopilot.md | grep -q 'Use Agent tool.*Developer'` が false を返すことを確認。

### Risk 2: Autonomy Rules の `grep -A 20` 範囲 (Low)

**リスク:** 既存テスト AC-6 (L60-82) は `grep -A 20 "## Autonomy Rules"` で既存ルールを検証。Rule 5 追加で行数が増えると、`-A 20` では新ルールまで到達しない可能性。

**対策:** 現在 Autonomy Rules セクションは L103-L112 の 10 行。Rule 5 追加で 11〜12 行。`-A 20` で十分到達する。ただし、Issue #11 用の新テストケースでは `-A 25` 以上を推奨。

### Risk 3: blockquote がテストパターンに干渉 (Low)

**リスク:** `> **Constraint:**` の blockquote 記法が既存テストの grep パターンにマッチしないか。

**対策:** 既存テストは `SendMessage.*Developer` や `SendMessage.*QA` のパターンで肯定検査をしている (L103, L107, L111-112, L116, L120)。blockquote 内にも "SendMessage" が含まれるが、これは肯定検査に追加マッチするだけで、テスト結果に影響しない（肯定テストなので追加マッチは無害）。

### Risk 4: Phase 0.9 の逆参照がテスト `#165-AC6` に影響 (None)

**リスク:** C6 の追加テキストが Phase 0.9 関連テスト (L329-343) に影響しないか。

**対策:** 影響なし。`#165-AC6` テストは `resume`, `re-spawn`, `Phase 4.*QA`, `Phase 3.*Developer`, `Phase 2.*Developer.*QA` を検索しており、追加テキストはこれらに新たなマッチを生まない。

## 5. 変更量サマリ

| 指標 | 値 |
|------|-----|
| 対象ファイル数 | 1 (`commands/autopilot.md`) |
| 追加行数 | 約 10 行 |
| 削除行数 | 0 行 |
| 変更箇所数 | 6 箇所 (C1〜C6) |
| 既存テスト影響 | なし（AC4 で全パス確認） |
