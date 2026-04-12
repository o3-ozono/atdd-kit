# Plan Review — Developer

**Issue:** #3 — bug: discover の autopilot モード検出が PO 直接呼び出しを認識しない
**Reviewer:** Developer
**Date:** 2026-04-12
**Reviewed artifact:** Unified Plan (PO 統合版)

## Overall Verdict: PASS

統合 Plan は AC セットと正確に対応しており、ファイル構成・実装順序・テスト戦略のいずれも妥当。スコープ逸脱なし。Minor 指摘 2 件は実装時に対応可能であり、Plan の承認をブロックしない。

## 1. AC との整合性

| AC | Plan の対応 | 整合性 |
|----|------------|--------|
| AC1: discover HARD-GATE/AUTOPILOT-GUARD/Step 7/Step 8 | discover SKILL.md 4 箇所（L15, L18-23, L230-232, L251） | OK — AC Review で指摘した HARD-GATE L15 が明示的に含まれている |
| AC2: discover Standalone 維持 | AC1 と同一コミット。Step 7/AUTOPILOT-GUARD の Standalone 分岐記述を維持 | OK — AC1 の変更が Standalone を壊さないことの検証は同一コミット内で可能 |
| AC3: plan AUTOPILOT-GUARD | plan SKILL.md 1 箇所（L16-21） | OK |
| AC4: atdd AUTOPILOT-GUARD | atdd SKILL.md 1 箇所（L12-17） | OK |
| AC5: autopilot.md 呼び出し | Phase 1（L124）+ Phase 3（L187） | OK — AC Review で指摘した Phase 3 の atdd 呼び出しが含まれている |
| AC6: テスト更新 | 更新 4 件 + 統合 1 件 + 新規 7 件 = 最終 24 テスト | OK |

**結論:** 全 6 AC が Plan に漏れなくマッピングされている。スコープ逸脱なし。

## 2. ファイル構成の妥当性

### 変更ファイル 5 件

| File | 変更の性質 | 妥当性 |
|------|-----------|--------|
| `skills/discover/SKILL.md` | 検出条件の置換（4 箇所） | OK — 最大 blast radius だが変更は機械的置換。HARD-GATE + AUTOPILOT-GUARD + Step 7 + Step 8 の 4 箇所を一つの AC（AC1）にまとめるのは、変更の原子性として妥当 |
| `skills/plan/SKILL.md` | AUTOPILOT-GUARD 置換（1 箇所） | OK — 最小変更 |
| `skills/atdd/SKILL.md` | AUTOPILOT-GUARD 置換（1 箇所） | OK — plan と同一パターン |
| `commands/autopilot.md` | 呼び出し引数追記（2 箇所） | OK — 判定側と呼び出し側の整合性を確保 |
| `tests/test_discover_autopilot_approval.bats` | テスト更新 + 新規 | OK — 変更内容を検証するテスト |

### 変更しないファイルの妥当性確認

| File | 理由 | 検証結果 |
|------|------|---------|
| Bug Flow Step 5 (discover L357) | "same as development flow Step 7" と記述。Step 7 の変更が自動波及 | OK — L357 を実ファイルで確認済み。明示的な `<teammate-message>` 参照なし |
| Docs/Investigation Flow Step 4 (discover L425-427) | 独自の承認フロー記述。`<teammate-message>` 参照なし | OK — L425-427 を実ファイルで確認済み |
| `.claude/rules/workflow-overrides.md` | autopilot 検出方式に言及していない | OK |
| Agent 定義（`agents/*.md`） | autopilot 検出ロジックを含まない | OK |

## 3. 実装順序のリスク評価

```
AC3 (plan) → AC4 (atdd) → AC1+AC2 (discover) → AC5 (autopilot.md) → AC6 (tests)
```

| 順序 | リスク | 評価 |
|------|--------|------|
| AC3 → AC4 を先行 | plan/atdd の AUTOPILOT-GUARD は独立しており、先行変更しても他に影響なし | LOW — パターン確立として合理的 |
| AC1+AC2 を 3 番目 | discover は 4 箇所変更で最大の blast radius。AC3/AC4 のパターンを適用するので手順が確立済み | LOW — AC3/AC4 の経験が安全弁として機能 |
| AC5 を AC1 の後 | autopilot.md は呼び出し側。判定側（SKILL.md）の変更が完了してから呼び出し側を更新するのは正しい依存順序 | LOW |
| AC6 を最後 | テストは全変更完了後に一括更新。途中でテストを更新すると後続 AC の変更でテストが再び壊れるリスクあり | LOW — 全変更完了後の一括更新が最も効率的 |

**代替案の検討:** テストファーストで AC6 を先に RED にし、AC3-AC5 で GREEN にする ATDD アプローチも可能だが、本件は全変更がマークダウンの文字列置換であり、テストも grep ベースの文字列存在チェックであるため、テストファーストのメリットが薄い。Plan の順序で問題なし。

## 4. フラグ検出仕様の評価

| 観点 | 評価 |
|------|------|
| Contains チェック | LLM 向けマークダウン指示として適切。プログラム的パースは不要 |
| 全スキル共通パターン | 一貫性あり。将来のスキル追加にも適用可能 |
| 引数順序非依存 | `"3 --autopilot"` でも `"--autopilot 3"` でも機能 |
| `<teammate-message>` からの移行 | 明示的フラグへの移行により、コンテキスト依存の不確実性を排除 |

**懸念なし。**

## 5. テスト戦略の評価

| 観点 | 評価 |
|------|------|
| カバレッジ | AC1-AC6 全てにテストがマッピングされている。Negative tests（残骸チェック）も含む |
| テスト数推移 | 18 → 24（更新 4 件 + 統合 1 件 + 新規 7 件）。適切な増加量 |
| テスト種別 | 全て BATS content-based assertions。既存パターンと一致 |
| 実行可能性 | grep/sed ベースの文字列チェック。外部依存なし |
| Negative tests | 3 スキルの AUTOPILOT-GUARD から `teammate-message` 完全除去を確認。重要な安全弁 |

## 6. Minor 指摘（ブロックしない）

### M1: コミットメッセージの prefix

Plan のコミット戦略では AC3-AC5 が `fix:` で AC6 が `test:`。既存コミット履歴（`git log --oneline`）を見ると `refactor:`, `feat:`, `fix:`, `docs:` が使われているが `test:` は確認できない。[Conventional Commits](https://www.conventionalcommits.org/) では `test:` は有効な prefix だが、プロジェクト慣行と合わせるべき。

**推奨:** 実装時に `test:` が許容されるか確認し、そうでなければ `fix:` に統一する。

### M2: CHANGELOG.md / plugin.json の更新コミット

Plan のコミット戦略（5 コミット）に CHANGELOG.md と `.claude-plugin/plugin.json` の更新が含まれていない。DEVELOPMENT.md の非交渉ルール（"Every feature PR merged to main must update the version and changelog"）に従い、PR 内で更新が必要。

**推奨:** AC6 のコミット後に 6 番目のコミット `chore: バージョンバンプ + CHANGELOG 更新 (#3)` を追加する。

## Summary

| # | Item | Status |
|---|------|--------|
| 1 | AC との整合性 | PASS — 全 6 AC が漏れなくマッピング |
| 2 | ファイル構成 | PASS — 5 ファイル 8 箇所、スコープ逸脱なし |
| 3 | 実装順序 | PASS — 依存順序が正しく、リスクは LOW |
| 4 | フラグ検出仕様 | PASS — contains チェックで十分 |
| 5 | テスト戦略 | PASS — 24 テスト、Negative tests 含む |
| M1 | コミット prefix | Minor — 実装時確認 |
| M2 | CHANGELOG/version | Minor — 6 番目のコミット追加を推奨 |

**BLOCKER: 0 件。実装着手可能。**
