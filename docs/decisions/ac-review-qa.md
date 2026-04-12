# AC Review -- QA

## Summary

**PASS (with modifications)**

Draft AC は全体として正しい方向性であり、`--autopilot` フラグ方式は `<teammate-message>` 依存の根本原因を解消する。ただし、境界条件のカバレッジ、Bug Flow のパス、旧方式除去の確認、既存テスト更新に関して抜けがある。以下の修正を適用した上で承認を推奨する。

## Per-AC Testability Analysis

### AC1: discover が --autopilot フラグで autopilot モードを検出する

**テスト可能性:** 高い。BATS で SKILL.md のテキストパターンを検証可能。

**テスト設計:**
```bash
@test "AC1: HARD-GATE contains --autopilot flag detection" {
  local hard_gate
  hard_gate=$(sed -n '/<HARD-GATE>/,/<\/HARD-GATE>/p' "$DISCOVER")
  echo "$hard_gate" | grep -q '\-\-autopilot'
}

@test "AC1: AUTOPILOT-GUARD uses --autopilot flag" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  echo "$guard" | grep -q '\-\-autopilot'
}

@test "AC1: Step 7 autopilot branch uses --autopilot flag" {
  local step7
  step7=$(sed -n '/### Step 7/,/### Step 8/p' "$DISCOVER")
  echo "$step7" | grep -q '\-\-autopilot'
}

@test "AC1: Step 8 autopilot skip uses --autopilot flag" {
  local step8
  step8=$(sed -n '/### Step 8/,/^---$/p' "$DISCOVER")
  echo "$step8" | grep -q '\-\-autopilot'
}
```

**境界条件の懸念:**
- `--autopilot` が引数の先頭にある場合（Issue 番号なし）: `Skill(atdd-kit:discover, args: "--autopilot")` -- Issue 番号欠落時の処理が未定義
- `--autopilot` と Issue 番号の順序: `"3 --autopilot"` vs `"--autopilot 3"` -- 仕様が必要
- typo ケース: `--auto-pilot`, `--Autopilot`, `-autopilot` -- 拒否するのか無視するのかの仕様が必要

### AC2: discover が Standalone モードで従来通り動作する

**テスト可能性:** 高い。既存テストの assertion パターンの更新で対応可能。

**テスト設計:** 既存テスト `test_discover_autopilot_approval.bats` の AC2 系テストが standalone モードの動作を検証済み。新方式でも AUTOPILOT-GUARD のテキストが変わるだけで、standalone 分岐（承認要求・Issue コメント投稿・inline plan 実行）自体は変わらないため、既存テストは内容的に継続利用可能。

**懸念:** AUTOPILOT-GUARD 内のテキストが `<teammate-message>` から `--autopilot` に変わるため、guard 内部の grep パターンに依存するテストは更新が必要。

### AC3: plan が --autopilot フラグで autopilot モードを検出する

**テスト可能性:** 高い。

**テスト設計:**
```bash
@test "AC3: plan AUTOPILOT-GUARD uses --autopilot flag" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$PLAN")
  echo "$guard" | grep -q '\-\-autopilot'
}
```

**懸念:** plan は AUTOPILOT-GUARD のみが対象。plan の Step 7/8 には autopilot 分岐がないため、GUARD のみで十分。問題なし。

### AC4: atdd が --autopilot フラグで autopilot モードを検出する

**テスト可能性:** 高い。

**テスト設計:**
```bash
@test "AC4: atdd AUTOPILOT-GUARD uses --autopilot flag" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$ATDD")
  echo "$guard" | grep -q '\-\-autopilot'
}
```

**懸念:** なし。

### AC5: autopilot.md が Skill 呼び出し時に --autopilot フラグを付与する

**テスト可能性:** 中程度。現行 autopilot.md の Phase 1 は `Use Skill tool to invoke atdd-kit:discover for the Issue` とだけ記載しており、具体的な args 指定がない。修正後のテキストに `--autopilot` が含まれることを検証可能。

**テスト設計:**
```bash
@test "AC5: autopilot Phase 1 discover call includes --autopilot" {
  local phase1
  phase1=$(sed -n '/## Phase 1/,/## AC Review Round/p' "$AUTOPILOT")
  echo "$phase1" | grep -q '\-\-autopilot'
}
```

**懸念:** AC5 は Phase 1 の discover のみ言及しているが、autopilot.md Phase 3 では Developer が `atdd-kit:atdd` を Skill tool で呼び出す。ここにも `--autopilot` が必要。AC5 のスコープを全 Skill 呼び出し箇所に拡張すべき。

## Coverage Gap Analysis

### Gap 1: Bug Flow Step 5 の autopilot 分岐が未カバー

discover SKILL.md の Bug Flow Step 5 は「Present the full AC set (same as development flow Step 7)」と記載されている。Step 7 の autopilot 分岐ロジックを参照するため、`--autopilot` 方式に変更すると Bug Flow にも影響する。

Step 5 は Step 7 を参照する形式なので、Step 7 の修正が自動的に Step 5 に波及する。ただし、テストで Bug Flow のパスも検証すべき。

**推奨:** AC1 の Then に Bug Flow Step 5 への波及を明記するか、テストケースで Bug Flow パスの動作も検証する。

### Gap 2: `<teammate-message>` 参照の完全除去の確認

3つの SKILL.md すべてから `<teammate-message>` による検出ロジックを除去し、`--autopilot` に置き換える必要があるが、「旧方式を除去する」ことを明示した AC がない。旧検出ロジックが残ったままだと、2つの検出パスが共存し混乱の原因になる。

**推奨:** AC1/3/4 の Then に「かつ `<teammate-message>` による旧検出ロジックは存在しない」を追加するか、negative test を追加:

```bash
@test "REGRESSION: discover AUTOPILOT-GUARD does not reference teammate-message" {
  local guard
  guard=$(sed -n '/<AUTOPILOT-GUARD>/,/<\/AUTOPILOT-GUARD>/p' "$DISCOVER")
  ! echo "$guard" | grep -q 'teammate-message'
}
```

### Gap 3: Phase 3 (atdd) の Skill 呼び出し箇所が AC5 に含まれていない

AC5 は Phase 1 の discover のみ言及している。しかし autopilot.md Phase 3 で Developer が `atdd-kit:atdd` を Skill tool で呼ぶ箇所にも `--autopilot` が必要。

**推奨:** AC5 の scope を「autopilot.md 内の全 Skill 呼び出し箇所」に拡張する。

### Gap 4: --autopilot フラグの解析仕様が未定義

引数解析の具体仕様が AC に含まれていない:
- 引数の position: `"3 --autopilot"` のみか、`"--autopilot 3"` も許容か
- フラグの大文字小文字: case-sensitive か
- 類似フラグの扱い: `--auto-pilot` 等の typo 時の挙動

SKILL.md はプロンプト記述なので厳密な引数パーサーではないが、LLM の解釈の曖昧さを減らすために AC の Given に明記すべき。

**推奨:** AC1 の Given に `"<number> --autopilot"` 形式であることを明記（現行で記載済みだが、逆順のケースについて NOTE を追加）。

### Gap 5: Standalone モードで --autopilot が渡された場合

ユーザーが手動で `/atdd-kit:discover 3 --autopilot` と呼んだ場合の挙動が未定義。`<teammate-message>` 方式ではユーザーが偽装できなかったが、`--autopilot` はユーザーが自由に付けられる。

承認フローのスキップに関わるため、セキュリティ/ガバナンスの観点から考慮が必要。ただし「ユーザー自身が意図的にフラグを付ける」ケースなので、ユーザーが自身の承認ステップをスキップする権利があるとも解釈できる。

**推奨:** AC 追加は不要だが、SKILL.md に NOTE として「ユーザーが手動で --autopilot を付けた場合は autopilot モードとして動作する（ブロックしない）」を明記することを推奨。

### Gap 6: 既存テスト更新の AC が欠落

既存テスト `test_discover_autopilot_approval.bats` の複数テストが `teammate-message` を grep しているため、修正後に FAIL する。テスト更新を保証する AC がない。

**推奨:** AC6 として追加:
> **AC6: 既存テストが新方式に更新されている**
> - Given: `tests/test_discover_autopilot_approval.bats` が存在する
> - When: `bats tests/` を実行する
> - Then: 全テストが PASS する

## Regression Risk Assessment

### 既存テスト `test_discover_autopilot_approval.bats` への影響

全18テストケースのうち、FAIL が見込まれるテスト:

| テスト | 依存パターン | 影響 |
|--------|-------------|------|
| AC5: HARD-GATE contains autopilot exception clause | `teammate-message` を grep | **FAIL** |
| AC5: HARD-GATE exception requires BOTH conditions | HARD-GATE 内で `teammate-message` を grep | **FAIL** |
| Cross-file: discover autopilot exception is documented in HARD-GATE | HARD-GATE 内で `autopilot\|AC Review Round` を grep | PASS (autopilot でマッチ) |
| AC1: Step 7 has autopilot-mode conditional branch | `teammate-message\|autopilot` で grep | PASS (autopilot でマッチ) |

**FAIL が確実なテスト: 2件**（`teammate-message` を直接 grep しているもの）
**FAIL の可能性があるテスト: 1-2件**（HARD-GATE の内容変更により assertion が不一致になる可能性）

### AUTOPILOT-GUARD テキスト変更による影響

3つの SKILL.md の AUTOPILOT-GUARD テキストが変更されるため、AUTOPILOT-GUARD のテキストパターンに依存する他のテストにも影響する可能性がある。現時点では `test_discover_autopilot_approval.bats` 以外に AUTOPILOT-GUARD をテストするファイルは確認されていないが、追加テストファイルがないことを確認すべき。

### autopilot.md Phase 1 テキスト変更

Phase 1 の Skill 呼び出し記述が変更されるため、Phase 1 を参照するテスト（AC4 系: autopilot Issue comment テスト等）への影響を確認すべき。AC4 系テストは AC Review Round セクションを対象としているため、Phase 1 の変更には影響しない見込み。

## Recommendation

**Accept with modifications (条件付き承認)**

以下の修正を推奨:

1. **AC1 の Then を拡張:** 「かつ HARD-GATE/AUTOPILOT-GUARD/Step 7/Step 8 内の `<teammate-message>` による旧検出ロジックは `--autopilot` フラグ検出に置き換えられている」を追加
2. **AC5 の scope 拡張:** Phase 1 (discover) だけでなく、autopilot.md 内の全 Skill 呼び出し箇所（Phase 3 の atdd を含む）をカバー
3. **AC6 の追加:** 既存テスト `test_discover_autopilot_approval.bats` が新方式に更新され、`bats tests/` で全テスト PASS
4. **AC1 の Given にフラグ位置の仕様を明記:** `"<number> --autopilot"` 形式であること
5. **(Optional) Gap 5 の NOTE 追加:** ユーザーが手動で `--autopilot` を付けた場合は autopilot モードとして動作する旨の注記
