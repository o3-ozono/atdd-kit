# AC Review: QA Perspective

Issue #22: bug: eval-guard.sh が main 側の SKILL.md 変更を誤検知する

## Root Cause Summary

- **Bug 1 (line 34):** `git diff --name-only origin/main` は双方向 diff。main 側の SKILL.md 変更もブランチ側の変更として検出される。
- **Bug 2 (line 20):** `grep -q 'git push'` は部分文字列マッチ。コマンド引数中の "git push" 文字列にも反応する。

**Fix:** three-dot diff (`origin/main...HEAD`) + regex 強化（`^\s*git\s+push\b` 等）。`hooks/eval-guard.sh` の 2 行修正。

## Overall Testability Assessment

**高い。** eval-guard.sh は stdin から JSON を受け取り、stdout に JSON を返す純粋な入出力スクリプト。git 環境のセットアップが必要だが、BATS の `setup()` で一時 git リポジトリを作成し、ブランチ・リモート・diff 状態を制御すれば全 AC を自動検証可能。

既存テストに eval-guard 専用の BATS ファイルは存在しない。新規作成が必要（例: `tests/test_eval_guard.bats`）。

## Per-AC Feedback

### AC1: merge-base 基点の SKILL.md 変更検出（regression test）

> - Given: main から分岐したブランチで README のみを編集し、分岐後に main 側で skills/*/SKILL.md が更新されている
> - When: ブランチ上で git push を実行する
> - Then: eval-guard は push をブロックしない

**Testability:** 高。BATS で以下のセットアップが可能:
1. 一時 git リポジトリ作成、`skills/foo/SKILL.md` を含む initial commit
2. ブランチ作成・切替
3. ブランチで `README.md` のみ編集・commit
4. main に戻って `skills/foo/SKILL.md` を変更・commit
5. ブランチに戻って eval-guard を実行

**Feedback:**

1. **PASS — AC として十分。** regression の核心シナリオを正確に記述している。

2. **Minor: "git push を実行する" の表現を精密化すべき。** eval-guard は実際には `git push` コマンドそのものを実行するのではなく、PreToolUse hook として Bash ツールの入力 JSON を受け取る。When 節を以下に修正すると BATS テスト作成時に曖昧さがない:
   > When: `{"command": "git push origin branch"}` を含む JSON を eval-guard.sh の stdin に渡す

   ただし、AC としてのユーザー可読性を考慮すると現行表現でも許容範囲。テスト実装時に hook の入力形式に変換すればよい。

3. **Edge case 追加推奨: main 側で複数の SKILL.md が変更されたケース。** 単一 SKILL.md の変更検出で十分だが、`git diff --name-only origin/main...HEAD` の出力が空であることの検証として、main 側で 2-3 個の SKILL.md を変更するバリエーションがあるとより堅牢。これは AC 追加ではなく、テストケースのバリエーションとして実装すべき。

**Verdict: PASS**

### AC2: ブランチ導入の SKILL.md 変更は正しく検出

> - Given: ブランチ上で skills/session-start/SKILL.md を変更し、eval マーカーが存在しない
> - When: ブランチ上で git push を実行する
> - Then: eval-guard が push をブロックし、「SKILL.md changes detected (session-start)」を含むメッセージを表示する

**Testability:** 高。AC1 のセットアップにブランチ側の SKILL.md 変更を追加するだけ。

**Feedback:**

1. **PASS — 正常系のブロック動作を正確に記述している。**

2. **Then の出力検証が具体的で良い。** `"SKILL.md changes detected (session-start)"` という文字列を指定しているため、BATS で `[[ "$output" == *"SKILL.md changes detected (session-start)"* ]]` で検証可能。

3. **Minor: JSON 出力構造の検証も追加すべき。** eval-guard は `permissionDecision: "deny"` を含む JSON を返す。Then 節に以下を追加するとより厳密:
   > かつ、出力 JSON の `permissionDecision` が `"deny"` である

4. **Edge case 追加推奨: 複数の SKILL.md 変更。** 例えば `skills/session-start/SKILL.md` と `skills/discover/SKILL.md` の両方を変更した場合、メッセージに両方のスキル名が含まれるか。現行コード L54 の `tr '\n' ','` ロジックの検証になる。これもテストケースバリエーションとして実装すべき。

**Verdict: PASS**

### AC3: コマンド引数中の "git push" 文字列で誤検知しない

> - Given: ブランチ上で skills/*/SKILL.md を変更している
> - When: git commit -m "fix: remember to git push" のように引数に "git push" を含むコマンドを実行する
> - Then: eval-guard はそのコマンドをブロックしない

**Testability:** 高。stdin に `{"command": "git commit -m \"fix: remember to git push\""}` を渡して `{}` が返ることを検証。

**Feedback:**

1. **PASS — Bug 2 の regression テストとして的確。**

2. **Given 条件 "skills/*/SKILL.md を変更している" は必須。** SKILL.md 変更がなければそもそもブロックロジックに到達しないため、この Given は正しい。ただし、テスト実装時にこの前提条件を忘れると false positive（テストが通るが実際にはブロックロジックに到達していない）になるリスクがある。

3. **追加テストケース推奨（AC 追加は不要、テストバリエーションとして）:**
   - `git log --oneline | grep "git push"` — パイプ内の文字列
   - `echo "run git push later"` — echo 引数内
   - `GIT_PUSH_OPTS=foo git commit` — 環境変数名に PUSH を含む

**Verdict: PASS**

### AC4: チェーンコマンド中の git push を正しく検出

> - Given: ブランチ上で skills/*/SKILL.md を変更し、eval マーカーが存在しない
> - When: git add . && git push origin branch のようなチェーンコマンドを実行する
> - Then: eval-guard が push をブロックする

**Testability:** 高。stdin に `{"command": "git add . && git push origin branch"}` を渡して deny JSON が返ることを検証。

**Feedback:**

1. **PASS — チェーンコマンドのケースは重要。**

2. **追加テストケース推奨（AC 追加は不要、テストバリエーションとして）:**
   - `git add . ; git push origin branch` — セミコロン区切り
   - `git add . || git push origin branch` — OR チェーン
   - `git push origin branch && echo done` — git push が先頭
   - `(cd repo && git push)` — サブシェル内

3. **パイプコマンドの検討:**
   - `echo foo | git push` — パイプ経由の push。現行の regex fix がこのパターンをカバーするか要確認。regex が `git\s+push` を行頭/コマンド境界でマッチさせるなら、パイプの右辺もマッチすべき。
   - **Recommendation:** パイプコマンドのテストケースを AC4 のバリエーションとして追加するか、独立した AC5 として追加するか検討。現行 AC4 の scope が「チェーンコマンド」に限定されているため、パイプは別のテストケースとして扱うのが適切。

**Verdict: PASS（パイプケースはテストバリエーションとして追加推奨）**

## Boundary Conditions（AC に含まれていないエッジケース）

### B1: origin/main が存在しない場合

**Priority: 中**

現行コード L34 では `git diff --name-only origin/main ... 2>/dev/null || echo ""` で fallback している。origin/main が存在しない場合（例: fork リポジトリで origin が upstream を指している、または shallow clone で origin/main が未取得）、`CHANGED_SKILLS` は空になり push が許可される。

three-dot diff (`origin/main...HEAD`) でも origin/main が存在しなければ同様にエラー → 空文字 → push 許可。これは fail-open として正しい動作だが、意図的かどうかを AC で明示すべき。

**Recommendation:** 追加 AC は不要だが、テストケースとして「origin/main が存在しない環境で push が許可される」を含めるべき。

### B2: detached HEAD 状態

**Priority: 低**

現行コード L26-31 で detached HEAD（`BRANCH` が空）の場合は即 push 許可。three-dot diff の修正はこのパスに影響しない。既存動作の維持を確認するテストケースとして含めるべき。

### B3: eval マーカーが存在する場合

**Priority: 中**

AC1-AC4 は全て eval マーカーが「存在しない」前提。AC2 の逆パターンとして「SKILL.md を変更しているが eval マーカーが存在する → push 許可」のテストケースが必要。これは既存動作の regression テストとして重要。

**Recommendation:** 独立した AC は不要だが、テストケースとして必須。

### B4: main ブランチ上での push

**Priority: 低**

現行コード L27-30 で main ブランチでは即 push 許可。three-dot diff の修正はこのパスに影響しない。既存動作の維持を確認するテストケースとして含めるべき。

### B5: SKILL.md 以外のファイル変更のみ

**Priority: 低**

AC1 がこのケースをカバーしている（README のみ編集）。追加 AC は不要。

## Error Cases

### E1: git コマンド失敗

現行コード L34 の `2>/dev/null || echo ""` により、git diff が失敗しても空文字 → push 許可。fail-open 設計として正しい。three-dot diff でも同じ fallback パターンを維持すべき。

**Recommendation:** AC 追加は不要。テストケースとして「git diff が失敗する環境で push が許可される」を含めるべき。

### E2: stdin の JSON パース失敗

現行コード L17 の `sed` が `"command"` フィールドを抽出できない場合、`COMMAND` は空 → grep が false → push 許可。これも fail-open として正しい。

**Recommendation:** テストケースとして「不正な JSON 入力で push が許可される」を含めるべき。

## Coverage Gaps

### Gap 1: regex の具体的なパターンが AC に未記載

AC3/AC4 は「誤検知しない」「正しく検出する」と述べているが、具体的な regex パターンを規定していない。実装者が `grep -q '^git push'`（行頭のみ）にするか `grep -qE '(^|&&|\|\||;)\s*git\s+push'`（コマンド境界）にするかで、カバー範囲が大きく異なる。

**Recommendation:** AC に regex パターンを規定する必要はないが、AC4 のテストバリエーション（セミコロン、パイプ、サブシェル）を十分に含めることで、実装の regex がこれらのパターンを正しく処理することを保証すべき。

### Gap 2: `sed` による command 抽出の脆弱性

現行コード L17 の `sed` は JSON パースとして脆弱。`"command"` フィールドにエスケープされた引用符が含まれる場合（例: `"command": "git commit -m \"fix: \\\"git push\\\" issue\""`）、抽出が不正確になる可能性がある。

**Recommendation:** これは Issue #22 の scope 外（既存の技術的負債）。AC には含めないが、将来の改善 Issue として記録すべき。

## BATS テスト設計の推奨事項

### テストファイル構成

新規ファイル `tests/test_eval_guard.bats` を作成。

### setup() パターン

```bash
setup() {
  TEST_DIR=$(mktemp -d)
  # 一時 git リポジトリ作成
  git -C "$TEST_DIR" init
  git -C "$TEST_DIR" commit --allow-empty -m "initial"
  # skills/foo/SKILL.md を含む構造を作成
  mkdir -p "$TEST_DIR/skills/session-start"
  echo "test" > "$TEST_DIR/skills/session-start/SKILL.md"
  git -C "$TEST_DIR" add .
  git -C "$TEST_DIR" commit -m "add skill"
  # origin/main をシミュレート
  git -C "$TEST_DIR" branch -M main
  # ...ブランチ作成、リモート設定等
}
```

### テスト数の見積もり

| AC | 最小テスト数 | バリエーション含む |
|----|------------|-----------------|
| AC1 | 1 | 2（単一/複数 SKILL.md） |
| AC2 | 1 | 2（単一/複数スキル名） |
| AC3 | 1 | 3（commit -m、echo、log） |
| AC4 | 1 | 4（&&、;、パイプ、サブシェル） |
| 境界条件 | 4 | 4（B1-B4） |
| **合計** | **8** | **15** |

## Summary

| AC | Testability | Verdict | Key Issues |
|----|------------|---------|------------|
| AC1 | 高 | **PASS** | regression テストとして的確。When 節の表現は許容範囲。 |
| AC2 | 高 | **PASS** | 正常系ブロック動作を正確に記述。JSON 出力構造の検証を追加推奨。 |
| AC3 | 高 | **PASS** | Bug 2 の regression テストとして的確。追加バリエーション推奨。 |
| AC4 | 高 | **PASS** | チェーンコマンドをカバー。パイプケースをバリエーションに追加推奨。 |

**Overall Verdict: PASS（全 AC 承認）**

AC 自体の追加・修正は不要。以下はテスト実装時の推奨事項:

1. **パイプコマンド** (`echo foo | git push`) のテストバリエーションを AC4 に追加
2. **境界条件テスト** (B1-B4) をテストスイートに含める
3. **eval マーカー存在時の push 許可** を regression テストとして含める
4. **origin/main 不在時の fail-open 動作** をテストで確認
