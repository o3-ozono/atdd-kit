# AC Review — Developer

**Issue:** #3 — bug: discover の autopilot モード検出が PO 直接呼び出しを認識しない
**Reviewer:** Developer
**Date:** 2026-04-12

## Summary

**Verdict: PASS with modifications** — `--autopilot` フラグ方式はアーキテクチャ的に妥当であり、全 AC は技術的に実現可能。ただし、HARD-GATE の autopilot exception（discover SKILL.md L15）の更新が AC に含まれていない点と、既存テストファイルの更新方針について補足が必要。

## Per-AC Analysis

### AC1: discover が --autopilot フラグで autopilot モードを検出する

**Verdict: PASS**

**実現性:** 高い。discover SKILL.md の以下 3 箇所を `<teammate-message>` 検出から `--autopilot` フラグ検出に書き換えるだけで実現可能:

| 箇所 | 行 | 現在の条件 | 変更後 |
|------|-----|-----------|--------|
| AUTOPILOT-GUARD (L18-23) | 19, 22 | `<teammate-message>` の有無 | ARGUMENTS に `--autopilot` が含まれるか |
| Step 7 (L230-232) | 230, 232 | `<teammate-message>` from team-lead | ARGUMENTS に `--autopilot` が含まれるか |
| Step 8 (L251) | 251 | `<teammate-message>` from team-lead | ARGUMENTS に `--autopilot` が含まれるか |

**懸念:** なし。SKILL.md はマークダウン指示であり、ARGUMENTS は Skill tool の `args` パラメータとして渡されるため、フラグ文字列の存在チェックは確実に機能する。

### AC2: discover が Standalone モードで従来通り動作する

**Verdict: PASS**

**実現性:** 高い。`--autopilot` フラグなしの場合は Standalone モードとして動作する。フラグベースの条件分岐なので、フラグがなければ自動的に従来動作になる。既存の Standalone 動作が壊れるリスクは低い。

**テスト可能性:** BATS テストで SKILL.md の文言を検証可能（既存テストパターンと同様）。

### AC3: plan が --autopilot フラグで autopilot モードを検出する

**Verdict: PASS**

**実現性:** 高い。plan SKILL.md の AUTOPILOT-GUARD (L16-21) を同様に書き換える。plan には Step 7 のような autopilot 条件分岐は他にないため、AUTOPILOT-GUARD のみの変更で済む。

**補足:** autopilot.md では plan は Skill tool で直接呼ばれるのではなく、SendMessage 経由で Developer に指示される（L154）。Developer が Skill tool で plan を呼ぶ際に `--autopilot` を付与する必要がある。ただし現行の autopilot.md Phase 2 (L149-160) では plan の Skill tool 呼び出しの記述がなく、Developer が SendMessage 経由で戦略を策定する流れになっている。plan SKILL.md の AUTOPILOT-GUARD が発火するのは、Developer が明示的に `Skill(atdd-kit:plan, args: "3 --autopilot")` を呼んだ場合のみ。現行アーキテクチャでは plan は Skill tool 経由ではなく SendMessage ベースで実行されるため、AC3 の Given の前提が現行のワークフローと若干ずれている可能性がある。ただし、将来的に Skill tool 経由で呼ばれる場合への対応として有効であり、AUTOPILOT-GUARD の一貫性を保つ意味で AC として妥当。

### AC4: atdd が --autopilot フラグで autopilot モードを検出する

**Verdict: PASS**

**実現性:** 高い。atdd SKILL.md の AUTOPILOT-GUARD (L12-17) を同様に書き換える。

**補足:** autopilot.md Phase 3 (L187) では「Developer uses Skill tool to invoke `atdd-kit:atdd`」と明記されている。Developer が `--autopilot` 付きで呼び出す必要があるが、これは AC5 の autopilot.md 側の変更でカバーされる。

### AC5: autopilot.md が Skill 呼び出し時に --autopilot フラグを付与する

**Verdict: PASS with clarification needed**

**実現性:** 高い。autopilot.md の以下箇所を更新:

| 箇所 | 行 | 変更内容 |
|------|-----|---------|
| Phase 1 (L124) | 124 | `atdd-kit:discover` → `atdd-kit:discover <number> --autopilot` |
| Phase 3 (L187) | 187 | Developer への指示に `--autopilot` フラグ付与を明記 |

**懸念:** Phase 2 の plan について、autopilot.md には plan の Skill tool 呼び出し記述がない（SendMessage ベース）。AC5 の Given は「Phase 1 で discover を呼び出す箇所」に限定されているが、Phase 3 の atdd 呼び出し箇所（Developer への SendMessage 指示）も同様に更新が必要。AC5 のスコープを「全 Skill 呼び出し箇所」に拡大するか、atdd 用の AC を別途追加すべき。

## Edge Cases Identified

### 1. HARD-GATE の autopilot exception が未更新（AC 追加推奨）

discover SKILL.md L15 の HARD-GATE 内 autopilot exception:

```
Both conditions must hold: (1) `<teammate-message>` from team-lead is present, AND (2) the AC Review Round completes with user approval.
```

この条件 (1) も `--autopilot` フラグに更新する必要がある。現在のどの AC にもこの箇所の変更が明示されていない。AC1 の暗黙のスコープに含まれると解釈できるが、HARD-GATE は安全装置であり、明示的にカバーすべき。

**推奨:** AC1 の Then に「HARD-GATE の autopilot exception 条件も `--autopilot` フラグベースに更新される」を追記するか、独立した AC を追加。

### 2. 既存テスト `test_discover_autopilot_approval.bats` の更新

既存テスト (L14, L22, L32) は `teammate-message` 文字列の存在をアサートしている。`--autopilot` フラグ方式に移行すると、これらのテストは以下のいずれかになる:

- **FAIL になる:** `teammate-message` が SKILL.md から除去される場合
- **PASS のまま:** `teammate-message` が残る場合（ただし検出ロジックとしては使われない残骸になる）

テストの更新方針を AC に含めるか、実装計画（plan）で扱うべき。

### 3. `--autopilot` と他の引数の混在

`Skill(atdd-kit:discover, args: "3 --autopilot")` の場合、ARGUMENTS は `"3 --autopilot"` という文字列になる。Issue 番号とフラグの解析は単純な文字列 contains チェック（`--autopilot` が含まれるか）で十分だが、以下のエッジケースがある:

- `args: "--autopilot 3"` — 順序逆転。contains チェックなら問題なし。
- `args: "3"` — フラグなし。Standalone モード。正常。
- `args: "3 --autopilot --verbose"` — 将来のフラグ追加。contains チェックなら問題なし。

これらは実装上のリスクが低く、AC 追加は不要。

### 4. Bug Flow (Step 5) と Docs/Investigation Flow (Step 4) の autopilot 対応

discover SKILL.md の Bug Flow Step 5 (L357) と Docs/Investigation Flow Step 4 (L428) にも「Present deliverables and get approval」がある。これらは Development Flow の Step 7 を参照する形式（"same as development flow Step 7"）なので、Step 7 の修正が波及する。ただし、明示的な `<teammate-message>` 条件分岐はこれらのステップには書かれていないため、暗黙的に修正が反映される。追加 AC は不要だが、実装時に確認すべきポイント。

## File Impact Assessment

| File | 変更内容 | 影響度 |
|------|---------|--------|
| `skills/discover/SKILL.md` | HARD-GATE (L15), AUTOPILOT-GUARD (L18-23), Step 7 (L230-232), Step 8 (L251) の `<teammate-message>` 条件を `--autopilot` フラグに置換 | **高** — 4 箇所の条件分岐を変更 |
| `skills/plan/SKILL.md` | AUTOPILOT-GUARD (L16-21) の `<teammate-message>` 条件を `--autopilot` フラグに置換 | **中** — 1 箇所 |
| `skills/atdd/SKILL.md` | AUTOPILOT-GUARD (L12-17) の `<teammate-message>` 条件を `--autopilot` フラグに置換 | **中** — 1 箇所 |
| `commands/autopilot.md` | Phase 1 (L124) の discover 呼び出しに `--autopilot` 追記、Phase 3 (L187) の Developer 指示に `--autopilot` 追記 | **中** — 2 箇所 |
| `tests/test_discover_autopilot_approval.bats` | `teammate-message` アサーションを `--autopilot` ベースに更新。テスト名の AC 番号も新 AC 体系に合わせて更新が必要 | **中** — テスト更新 |

**変更しないファイル:**
- `commands/autopilot.md` の Phase 2 (plan)：plan は SendMessage ベースであり、Skill tool 呼び出し記述がないため変更不要（ただし Developer への指示に `--autopilot` フラグ付与を含めるなら変更必要）
- `.claude/rules/workflow-overrides.md`：autopilot 検出方式には言及していないため変更不要

## Recommendation

**Accept with modifications:**

1. **HARD-GATE 更新の明示化:** AC1 の Then に HARD-GATE autopilot exception (L15) の更新を含めるか、独立 AC を追加する。HARD-GATE は安全装置であり、暗黙的なカバーではなく明示的にすべき。

2. **テスト更新方針の明示化:** `test_discover_autopilot_approval.bats` の更新を AC として含めるか、plan フェーズで扱うことを明記する。

3. **AC5 のスコープ拡大:** AC5 の Given を「Phase 1 の discover 呼び出し箇所」だけでなく「全 Skill 呼び出し箇所（Phase 1 discover + Phase 3 atdd の Developer 指示）」に拡大する。

上記 3 点は実装の正確性に影響するため、AC の微修正として対応すべき。全体のアプローチは妥当であり、根本原因（`<teammate-message>` が PO 直接呼び出しで注入されない）に対する正しい修正方向である。
