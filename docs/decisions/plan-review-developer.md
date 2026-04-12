# Plan Review: Developer

**Issue:** #22 — bug: eval-guard.sh が main 側の SKILL.md 変更を誤検知する
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Verdict: PASS

Plan のファイル構成、実装順序、技術リスク評価すべて妥当。BLOCKER なし。実装着手可能。

## Checklist Review

### [x] ファイル構成の妥当性

**PASS。** 5ファイルの変更リスト:

| # | File | 妥当性 |
|---|------|--------|
| 1 | `tests/test_eval_guard.bats` (新規) | 必要。eval-guard.sh のテストは現在存在しない。21テストケースは4つのACを十分にカバー |
| 2 | `hooks/eval-guard.sh` | 必要。バグの原因がある2行 (L20, L34) |
| 3 | `hooks/README.md` | 必要。DEVELOPMENT.md のルール「Directory READMEs: update in the same PR」に準拠 |
| 4 | `CHANGELOG.md` | 必要。DEVELOPMENT.md のルール「every feature PR must update the changelog」に準拠 |
| 5 | `.claude-plugin/plugin.json` | 必要。PATCH bump (1.5.0 → 1.5.1)。バグ修正のため PATCH が正しい |

**不足ファイルなし。** `.claude/settings.json` は hook 登録が変更なし（同じ matcher, 同じ command）のため修正不要。

### [x] 実装順序のリスク

**PASS。** ATDD Double Loop の正しい順序:

```
Phase 1 (Red): tests/test_eval_guard.bats 作成
    ↓ AC1, AC3 テストが失敗することを確認
Phase 2 (Green): hooks/eval-guard.sh L34, L20 修正
    ↓ 全テスト PASS を確認
Phase 3 (Housekeeping): README, CHANGELOG, version
```

**リスク評価:**

1. **Phase 1 → Phase 2 の順序:** テストファーストは正しい。AC2, AC4 のテストが Phase 1 時点で既に PASS することも確認すべき（既存の正しい動作の regression guard として機能する）
2. **Phase 2 内の順序:** L34 (three-dot diff) → L20 (regex) の順序は正しい。L34 の変更は L20 に影響しない。逆順でも問題ないが、primary bug (AC1) を先に修正する方が自然
3. **Phase 3 の位置:** housekeeping は実装完了後。正しい

**唯一の注意点:** Phase 1 で BATS テストが一時 git リポジトリを `setup()` で作成する設計。`teardown()` で確実にクリーンアップすること。BATS の `BATS_TMPDIR` を使えば問題ない。

### [x] テスト設計の技術的実現性

**PASS。** bare remote 方式で three-dot diff の正確な再現を実機検証済み:

```
Two-dot diff (buggy):  skills/test-skill/SKILL.md  ← 誤検出
Three-dot diff (fixed): (空)                        ← 正しい
```

bare remote (`git init --bare`) + `git clone` + `git fetch` で `origin/main` が正しく参照される。`git update-ref` 方式よりも実環境に近い。

**テスト infrastructure の設計ポイント:**

- `setup()` で bare remote + clone + branch + fetch を毎テスト実行
- `run_guard()` ヘルパーで eval-guard.sh を当該リポジトリの context で実行
- `teardown()` で一時ディレクトリをクリーンアップ
- eval-guard.sh の `git branch --show-current` と `git diff` はテストリポジトリの `cd` コンテキストに依存するため、`cd "$WORK"` した状態で guard を実行する必要がある

**AC3 テストの重要な前提条件:**
Plan が「SKILL.md 変更ありの状態で実行」と指定しているのは正しい。AC3 は「コマンド引数中の "git push" で誤検知しない」だが、そもそも `git push` として検出されなければテストが成立する。SKILL.md 変更がある状態で "git push" が引数に含まれるコマンドを実行し、eval-guard がブロックしないことを確認する必要がある。

### [x] 技術リスク評価

**PASS。** Plan の2つのリスクに対する追加検証結果:

#### R1: `\b` の BSD grep 互換性

**実機検証済み — 問題なし。**

macOS の `grep -E` で `\b` をテスト:

| 入力 | 期待 | 結果 |
|------|------|------|
| `git push origin main` | MATCH | MATCH |
| `git commit -m "remember to git push"` | NO MATCH | NO MATCH |
| `git add . && git push origin branch` | MATCH | MATCH |
| `git add . ; git push` | MATCH | MATCH |
| `git add . \|\| git push` | MATCH | MATCH |
| `git pushall` | NO MATCH | NO MATCH |
| `echo "run git push later"` | NO MATCH | NO MATCH |

全ケースで正しく動作。`\b` は GNU grep と BSD grep (macOS) の両方でサポート。フォールバック (`git\s+push(\s|$)`) は不要だが、Plan に記載があるのは prudent。

#### R2: Three-dot diff の shallow clone 挙動

**PASS。** `2>/dev/null || echo ""` のエラーハンドリングが維持される。shallow clone で `git merge-base` が失敗しても、空文字列が返り CHANGED_SKILLS が空になる → push を許可（fail-open）。atdd-kit 開発者は full clone を使用するため実際にはこのパスに入らない。

### [x] 具体的なコード変更の正確性

**PASS。**

#### L34: Three-dot diff

```bash
# Before:
CHANGED_SKILLS=$(git diff --name-only origin/main -- 'skills/*/SKILL.md' 2>/dev/null || echo "")
# After:
CHANGED_SKILLS=$(git diff --name-only origin/main...HEAD -- 'skills/*/SKILL.md' 2>/dev/null || echo "")
```

- `origin/main...HEAD` = `$(git merge-base origin/main HEAD)..HEAD` — merge-base 基点
- path filter `'skills/*/SKILL.md'` は維持 — SKILL.md 以外のファイルは無視
- error handling `2>/dev/null || echo ""` は維持 — fail-open

#### L20: Regex 強化

```bash
# Before:
if ! echo "$COMMAND" | grep -q 'git push'; then
# After:
if ! echo "$COMMAND" | grep -qE '(^|&&|;|\|\|)\s*git\s+push\b'; then
```

- `(^|&&|;|\|\|)` — コマンド先頭 or チェーン演算子の後
- `\s*` — 演算子後の任意空白
- `git\s+push` — `git` と `push` の間に1つ以上の空白（`git  push` も対応）
- `\b` — word boundary（`git pushall` を除外）

**既存コードとの整合性:** `grep -q` → `grep -qE` への変更。`-E` は extended regex を有効にする。既存の他の grep 呼び出し（L17 の `sed`）には影響しない。

### [x] バージョンバンプの妥当性

**PASS。** 現在のバージョンは `1.5.0`（`.claude-plugin/plugin.json` で確認済み）。バグ修正のため PATCH bump: `1.5.0 → 1.5.1`。

- PATCH が正しい理由: hook の外部インターフェース（stdin JSON → stdout JSON）は変更なし。内部の検出ロジックのバグ修正のみ。
- MINOR ではない理由: 新機能の追加なし。observable behavior の「正しい方向への修正」は breaking change ではない。

## Additional Observations

### O1: テストケース 21 の内訳妥当性

| カテゴリ | テスト数 | 評価 |
|----------|---------|------|
| AC1 (merge-base diff) | 2 | 適切。primary bug のメインシナリオ |
| AC2 (branch SKILL.md detection) | 3 | 適切。正常検出 + eval marker + メッセージ内容 |
| AC3 (argument false positive) | 3 | 適切。commit message + echo + 他のパターン |
| AC4 (chain commands) | 4 | 適切。`&&`, `;`, `\|\|` + 複合ケース |
| 境界条件 | 6 | 適切。detached HEAD, main branch, no origin, empty command 等 |
| Regression | 3 | 適切。既存の正常動作が維持されることの確認 |

21 テストは 2 行変更に対してやや多いが、eval-guard.sh にはこれまでテストが存在しなかったため、この機会に包括的なテストカバレッジを確立するのは合理的。

### O2: `sed` コマンド (L17) の制限

```bash
COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)
```

この `sed` は単純な JSON パース。複数行の JSON やエスケープされた引用符を含むコマンドでは壊れる可能性がある。ただしこれは **pre-existing issue** であり、Issue #22 のスコープ外。Plan もこれを変更対象にしていない。正しい。

## Summary

| # | Severity | Item | Status |
|---|----------|------|--------|
| — | — | ファイル構成 | PASS |
| — | — | 実装順序 | PASS |
| — | — | テスト設計 | PASS (bare remote 方式で実機検証済み) |
| — | — | 技術リスク `\b` | PASS (macOS で実機検証済み) |
| — | — | 技術リスク shallow clone | PASS (fail-open 維持) |
| — | — | L34 コード変更 | PASS |
| — | — | L20 コード変更 | PASS |
| — | — | バージョンバンプ | PASS (1.5.0 → 1.5.1 PATCH) |

**BLOCKER: 0 件。実装着手可能。**
