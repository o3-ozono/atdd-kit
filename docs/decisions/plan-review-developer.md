# Plan Review: Developer

**Issue:** #1 — bug: sim-pool-guard.sh が build_sim / build_run_sim / test_sim を CLONE_REQUIRED_TOOLS から除外している
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Verdict: PASS

Plan は承認済み AC (1-5) をすべてカバーしており、ファイル構成・実装順序・テスト設計に問題なし。変更は `CLONE_REQUIRED_TOOLS` 配列への 3 行追加が本質であり、ロジック変更がないため技術リスクは極めて低い。以下の軽微な指摘を確認の上、実装着手可能。

## R1: ファイル構成の妥当性

### 漏れチェック

| Check | Result | Note |
|-------|--------|------|
| `sim-pool-guard.sh` の CLONE_REQUIRED_TOOLS 修正 | OK | AC1 カバー。配列に 3 行追加。 |
| 新規テストファイル作成 | OK | AC1-4 カバー。12 テストケース。 |
| 既存テストスイートで AC5 回帰検証 | OK | 新規テスト不要。9 テストファイルの全パスで検証。 |
| CHANGELOG.md | OK | DEVELOPMENT.md ルール準拠。Fixed エントリ。 |
| plugin.json version bump | OK | DEVELOPMENT.md ルール準拠。1.1.0 → 1.1.1 (patch)。 |

### 不要ファイルチェック

不要なファイルは含まれていない。4 ファイル (3 modified + 1 new) はすべて必要最小限。

### Directory READMEs ルール

DEVELOPMENT.md の「Directory READMEs」ルールは「When adding, removing, or modifying files in these directories, update the corresponding README.md in the same PR」と規定している。

- `addons/ios/tests/` には README.md が存在しない（`addons/ios/README.md` は存在するがテストファイルの一覧は含んでいない）
- 新規テストファイル `test_sim_clone_required_variants.bats` を `addons/ios/tests/` に追加するが、このディレクトリは DEVELOPMENT.md が列挙する「top-level directories」（`skills/`, `commands/`, `hooks/`, `rules/`, `scripts/`, `templates/`, `tests/`）に含まれない
- `tests/` (トップレベル) には `README.md` があるが、`addons/ios/tests/` はこれとは別ディレクトリ

**結論:** Directory READMEs ルールの適用対象外。README 更新は不要。

## R2: 実装順序のリスク

### 依存関係の確認

```
Step 1: sim-pool-guard.sh  -- no dependency, standalone
   ↓ (テスト対象のスクリプトが確定)
Step 2: test_sim_clone_required_variants.bats  -- depends on Step 1
   ↓ (テストファイルが存在)
Step 3: テスト実行 + 既存テスト回帰確認  -- depends on Step 1 + 2
   ↓ (修正とテスト両方が完了)
Step 4: CHANGELOG.md || plugin.json  -- no code dependency
```

**依存関係は正しい。** Step 2 の静的検証テスト (AC1/AC2) は Step 1 の配列修正を `grep` で検証するため、Step 1 完了後に書くべき。Step 3 は Step 1-2 の両方に依存。Step 4 は独立。

**リスクなし。** 順序は妥当。4 ステップは直線的な依存で、並列化の余地はないが、変更量が極めて少ないため問題にならない。

## R3: 技術リスク評価

### AC Review 指摘事項の反映状況

| AC Review 指摘 | Plan 反映 | Status |
|---------------|----------|--------|
| Developer M1: AC5 Then 節の明確化 | 承認済み AC で AC3 (初回 DENY) と AC4 (ALLOW) に分離済み | OK |
| Developer M2: 配列内の配置位置 | impl-strategy で `build`/`test` 直後に配置と明記 | OK |
| QA: 静的検証 (配列メンバーシップ) 追加 | AC1 として統合済み。テスト設計に `sed -n` + `grep` パターン含む。 | OK |
| QA: 否定テスト (READONLY 非含有) 追加 | AC2 として統合済み。テスト設計に `! grep -q` パターン含む。 | OK |
| QA: session_id 分離設計 | テスト戦略で 6 つの独立 session_id を定義 | OK |
| QA: setup_flag 自動生成の仕様注記 | テスト戦略 Section 7 で記述済み | OK |

**全指摘事項が Plan に反映されている。**

### コード変更のリスク分析

| 変更箇所 | リスク | 根拠 |
|---------|--------|------|
| `CLONE_REQUIRED_TOOLS` に 3 行追加 | なし | `in_array` は線形探索。配列の順序・サイズに副作用なし。 |
| 既存エントリの順序変更なし | なし | 新エントリは `build`/`test` の直後に挿入。他のエントリの相対順序は不変。 |
| `handle_xcodebuildmcp` のロジック変更なし | なし | L320 (`session_set_defaults`), L326 (`session_use_defaults_profile`) の完全一致比較は `_sim` バリアントにマッチしない。 |
| `main()` のフロー変更なし | なし | case 文 `mcp__XcodeBuildMCP__*` は既存パターンで `_sim` バリアントを自然にルーティングする。 |
| `PERSIST_CHECK_TOOLS` への影響 | なし | `_sim` バリアントは persist check 対象外。これは正しい — `build_sim` 等に `persist` パラメータは存在しない。 |

**総合リスク: 極めて低い。**

### バージョンバンプの妥当性

`1.1.0` → `1.1.1` (patch) は正しい選択。理由:
- Breaking change なし (MAJOR 不変)
- 新機能追加なし (MINOR 不変)
- バグフィックス (PATCH +1) — allowlist gap の修正

## R4: テスト設計の妥当性

### 静的 + 動的二層構造

QA テスト戦略の「静的検証 + 動的検証の二層構造」は根本原因（配列への追加漏れ）に対して適切。

- **静的検証 (AC1/AC2):** 配列の内容を直接確認。ルーティングロジックの変更に影響されない。
- **動的検証 (AC3/AC4):** エンドツーエンドで guard スクリプトを実行。`main()` → `in_array` → `handle_xcodebuildmcp` の全パスを通しで検証。

### session_id 分離の検証

テスト戦略 Section 6 で 6 つの独立 session_id を定義している。これにより:
- AC3 の各テストが互いの `setup_flag` に干渉しない
- AC4 の各テストが AC3 の状態を引き継がない
- BATS は `@test` ごとに `setup()` を実行するが、`$$` は同一プロセスで不変のため `SIM_SESSION_DIR` は共有される点が正しく考慮されている

### テスト戦略 Section 7 の仕様注記

`handle_xcodebuildmcp` L333-334 の `touch "$setup_flag"` が初回 DENY 時にも実行される仕様を正しく認識している。AC4 テストの Step 1 (初回 DENY) で `setup_flag` が自動生成されるため、Step 2 (`session_set_defaults`) は `setup_flag` の存在には影響しない。この仕様理解は正確。

### カバレッジマトリクス

テスト戦略のカバレッジマトリクス (Section 4) で、すべての主要コードパスが少なくとも 1 つの AC でカバーされていることを確認:

- `CLONE_REQUIRED_TOOLS` 定義: AC1
- `READONLY_TOOLS` 定義: AC2
- `main()` CLONE_REQUIRED 分岐: AC3, AC4, AC5
- `handle_xcodebuildmcp()` setup_flag なし: AC3
- `handle_xcodebuildmcp()` setup_flag あり: AC4
- `in_array()`: AC3, AC4, AC5

**カバレッジに穴はない。**

## R5: Decision Trail の整合性

4 つの Decision Trail ドキュメント間の整合性を確認:

| 項目 | ac-review-developer | ac-review-qa | impl-strategy-developer | test-strategy-qa |
|------|-------------------|-------------|------------------------|-----------------|
| 変更ファイル数 | 2 (guard + tests) | — | 4 (guard + tests + changelog + version) | 1 (tests のみ) |
| テスト数 | 12 提案 | 12 提案 | 12 | 12 |
| session_id 分離 | 言及 | 暗黙 | 明示 (6 ID) | 明示 (6 ID) |
| 配置位置 | `build`/`test` 直後 | — | `build`/`test` 直後 | — |
| バージョン | — | — | 1.1.1 (patch) | — |

**不整合なし。** impl-strategy が changelog + version を含む 4 ファイルとしているのは正しい。ac-review は実装対象の 2 ファイルのみに言及しており、これは AC Review の責務として妥当（バージョニングは AC Review の範囲外）。

## R6: 懸念事項

### 懸念なし

この Plan は極めてシンプルなバグフィックスに対する最小変更である。ロジック変更がなく、配列への追加のみで完結する。テスト設計も既存パターンの完全踏襲であり、新しい技術的判断が必要な箇所はない。

## Summary

| # | Severity | Item | Status |
|---|----------|------|--------|
| — | — | ファイル構成 | OK — 4 ファイル、すべて必要最小限 |
| — | — | 実装順序 | OK — 直線的依存、リスクなし |
| — | — | 技術リスク | OK — 配列追加のみ、ロジック変更なし |
| — | — | テスト設計 | OK — 静的+動的二層、session_id 分離、カバレッジ完全 |
| — | — | AC Review 指摘の反映 | OK — 全指摘が Plan に反映済み |
| — | — | Decision Trail 整合性 | OK — 4 ドキュメント間の不整合なし |

**ブロッカーなし。実装着手可能。**
