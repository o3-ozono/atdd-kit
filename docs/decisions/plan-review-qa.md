# Plan Review: QA

**Issue:** #22 — bug: eval-guard.sh が main 側の SKILL.md 変更を誤検知する
**Reviewer:** QA Agent
**Date:** 2026-04-12

## Overall Verdict: PASS（1件の要修正指摘あり）

Plan は AC カバレッジ・テスト層選定・実装順序の全てにおいて妥当。ただし regex パターンにバグがあり、修正が必要。

## R1: テスト層の妥当性

**Verdict: PASS**

全 AC を BATS Unit 動的テストで検証する方針は適切。

- eval-guard.sh は stdin JSON → stdout JSON の純粋な変換スクリプトであり、Integration / E2E 層は不要
- 一時 git リポジトリ + bare remote で `origin/main...HEAD` の three-dot diff を正確に再現できる
- sim-pool-guard テストの確立済みパターン（`run_guard()` + `jq`）を踏襲しており、テスト基盤の一貫性がある

## R2: カバレッジ戦略の網羅性

**Verdict: PASS**

21 テストケースで以下をカバー:

| カテゴリ | カバレッジ |
|---------|-----------|
| 正常系（true positive） | AC2 (3), AC4 (4) = 7 テスト |
| 誤検知防止（false positive） | AC1 (2), AC3 (3) = 5 テスト |
| 境界条件 | B1-B6 = 6 テスト |
| 回帰 | REG.1-REG.3 = 3 テスト |

2行変更の両方が直接的にテストされている:
- **L34 (three-dot diff):** AC1.1-AC1.2 が false positive 排除、AC2.1-AC2.3 が true positive 確認
- **L20 (regex):** AC3.1-AC3.3 が false positive 排除、AC4.1-AC4.4 が true positive 確認

**テスト戦略で提案した全バリエーションが Plan に反映されている** — パイプコマンド (AC4.4)、detached HEAD (B2)、eval マーカー (B3)、origin 不在 (B4) を含む。

## R3: テストケース数と AC カバレッジの対応

**Verdict: PASS**

| AC | 要求テスト数 (テスト戦略) | Plan テスト数 | 差異 |
|----|-------------------------|-------------|------|
| AC1 | 2 | 2 | なし |
| AC2 | 3 | 3 | なし |
| AC3 | 3 | 3 | なし |
| AC4 | 4 | 4 | なし |
| 境界条件 | 6 | 6 | なし |
| Regression | 3 | 3 | なし |
| **合計** | **21** | **21** | **一致** |

## R4: ATDD Double Loop 順序

**Verdict: PASS**

1. **Red:** テスト先行 — 21 テストを作成し、AC1, AC3 が失敗することを確認
2. **Green:** 実装 — L34 three-dot diff → AC1 PASS、L20 regex → AC3/AC4 PASS
3. **Housekeeping:** README, CHANGELOG, version bump

正しい Red-Green-Refactor サイクル。テストが先に書かれるため、実装の正しさをテストが保証する。

## R5: 技術リスク分析

**Verdict: PASS（1件修正必要）**

### 修正必要: regex パターンのバグ

Plan の提案 regex:
```
grep -qE '(^|&&|;|\|\|)\s*git\s+push\b'
```

この regex は `\|\|`（`||` — OR チェーン）のみマッチし、単一の `|`（パイプ）にはマッチしない。

**検証結果:**
```
echo 'echo foo | git push origin main' | grep -qE '(^|&&|;|\|\|)\s*git\s+push\b'
→ NO MATCH（AC4.4 失敗）
```

**修正案:**
```
grep -qE '(^|&&|;|\|)\s*git\s+push\b'
```

単一の `|` でマッチさせれば、`||` も内包してマッチする（`||` は `|` を含むため）。

**検証結果（修正後）:**
```
echo 'echo foo | git push origin main'  → MATCH（パイプ OK）
echo 'git add . || git push'            → MATCH（OR チェーン OK）
echo 'git add . && git push'            → MATCH（AND チェーン OK）
echo 'git add . ; git push'             → MATCH（セミコロン OK）
echo 'git push origin main'             → MATCH（単独 OK）
echo 'git commit -m "fix: git push"'    → NO MATCH（引数 OK）
echo 'echo "git push"'                  → NO MATCH（引用符内 OK）
echo 'git pushforce'                    → NO MATCH（部分文字列 OK）
```

**重要度: 高。** このバグを修正しないと AC4.4（パイプコマンド検出）が失敗する。

### `\b` の BSD grep 互換性

Plan の記載通り、macOS の BSD `grep -E` は `\b` をサポートしている。実機で検証済み。フォールバック `(\s|$)` は不要。

### three-dot diff の shallow clone 挙動

`2>/dev/null || echo ""` による fail-open は適切。shallow clone 環境でも push がブロックされない。

## R6: 変更対象ファイルの網羅性

**Verdict: PASS**

| # | File | 必要性 |
|---|------|--------|
| 1 | `tests/test_eval_guard.bats` | 必須 — ATDD の Red フェーズ |
| 2 | `hooks/eval-guard.sh` | 必須 — バグ修正本体 |
| 3 | `hooks/README.md` | 必要 — DEVELOPMENT.md のディレクトリ README ルール |
| 4 | `CHANGELOG.md` | 必須 — DEVELOPMENT.md の Non-Negotiable Rules |
| 5 | `.claude-plugin/plugin.json` | 必須 — 同上 |

hooks/README.md L32 の `checks for SKILL.md changes vs origin/main` の記述を `checks for SKILL.md changes vs merge-base with origin/main` に更新すべき。

## Summary

| Check | Verdict | 備考 |
|-------|---------|------|
| R1: テスト層 | **PASS** | 全 AC が BATS Unit 動的テスト — 適切 |
| R2: カバレッジ | **PASS** | 2行変更の両方が直接カバー。テスト戦略の全バリエーション反映済み |
| R3: AC 対応 | **PASS** | テスト戦略の 21 テストと完全一致 |
| R4: ATDD 順序 | **PASS** | Red → Green → Housekeeping の正しいサイクル |
| R5: 技術リスク | **要修正** | regex `\|\|` → `\|` に修正必要（パイプ未検出バグ） |
| R6: ファイル網羅性 | **PASS** | DEVELOPMENT.md ルール準拠 |

**Blocking issue (1件):**
- regex パターンを `(^|&&|;|\|)\s*git\s+push\b` に修正すること（`\|\|` → `\|`）
