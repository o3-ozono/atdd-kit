# Plan Review: QA

Issue #1: bug: sim-pool-guard.sh が build_sim / build_run_sim / test_sim を CLONE_REQUIRED_TOOLS から除外している

## Review Summary

**Verdict: PASS with 2 recommendations**

統合 Plan は QA の観点から問題ない。テスト設計、カバレッジ戦略、実装順序のいずれも `docs/decisions/test-strategy-qa.md` の設計と整合しており、AC Review で指摘した全項目が反映されている。変更は全て additive で、既存テストスイートへの影響はゼロ。

## R1: テスト層の妥当性

**PASS**

静的検証（AC1/AC2）と動的検証（AC3/AC4）の二層構造は適切。

| テスト層 | 対象 AC | 妥当性 |
|---------|--------|--------|
| 静的: `sed -n` + `grep` | AC1 (配列含有), AC2 (配列非含有) | 根本原因（配列追加漏れ）を直接検証。`test_sim_failclosed_guard.bats` AC3.12-AC3.13 と同一の確立済みパターン。 |
| 動的: `run_guard` + `jq` | AC3 (初回 DENY), AC4 (ALLOW) | ルーティングの正しさを end-to-end で検証。`test_sim_auto_inject.bats` AC5.1-AC5.2 と同一の確立済みパターン。 |
| 既存スイート全パス | AC5 (回帰) | 新規テスト不要。9 ファイルの既存テストが回帰ガードとして機能。 |

二層構造の相互補完:
- 静的検証のみでは「配列に追加したが main() のルーティングで処理されない」ケースを検出できない
- 動的検証のみでは「たまたま別のコードパスで ALLOW されている」ケースを検出できない
- 二層構造にすることで両方をカバーしている

## R2: カバレッジ戦略の網羅性

**PASS**

| コードパス | カバー元 |
|-----------|---------|
| `CLONE_REQUIRED_TOOLS` 配列定義 (L51-79) | AC1 静的検証 |
| `READONLY_TOOLS` 配列定義 (L33-48) | AC2 否定テスト |
| `main()` CLONE_REQUIRED 分岐 (L394-404) | AC3/AC4 動的検証 |
| `handle_xcodebuildmcp()` setup_flag なし (L333-339) | AC3 動的検証 |
| `handle_xcodebuildmcp()` setup_flag あり (L341) | AC4 動的検証 |
| `handle_xcodebuildmcp()` session_set_defaults (L320-324) | AC4 動的検証（Step 2） |
| `in_array()` (L97-105) | AC3/AC4 動的検証（暗黙） |
| `main()` fail-closed DENY (L407-408) | AC5 既存テスト（AC3.9-AC3.11） |
| `main()` READONLY 分岐 (L383-386) | AC5 既存テスト（AC3.4-AC3.8） |

impl-strategy の「壊れる可能性があるもの」5 項目すべてがテストでカバーされている。不足なし。

## R3: テストファイル構成の適切さ

**PASS**

- ファイル名 `test_sim_clone_required_variants.bats` は既存の命名パターン（`test_sim_*.bats`）に準拠
- `addons/ios/tests/` ディレクトリに配置（iOS addon のテストは全てここ）
- 12 テストは 1 ファイルに集約 -- 変更が単一テーマ（3 ツールの追加）であるため分割不要
- setup/teardown は `test_sim_auto_inject.bats` からの流用で、新たなテスト基盤の導入なし

## R4: セッション ID 分離設計

**PASS**

impl-strategy で AC3 の各テストに独立したセッション ID（`session-ac3-1`, `session-ac3-2`, `session-ac3-3`）を使用する設計は正しい。

`handle_xcodebuildmcp` L333-334 で初回 DENY 時に `setup_flag` が自動生成されるため、同一セッション ID を使い回すと 2 番目以降のテストが ALLOW になってしまう。この仕様は `test-strategy-qa.md` のセクション 7 で明示的に記録されており、impl-strategy がこれに対応していることを確認。

## R5: AC4 テストの 3 ステップ手順

**PASS**

impl-strategy の AC4 テスト手順:
1. `build` で初回呼び出し（クローン作成 + setup_flag 作成）
2. `session_set_defaults` を呼び出し
3. `_sim` バリアントを呼び出し → ALLOW を確認

この手順は `test_sim_auto_inject.bats` AC5.2 と同一パターン。Step 1 で `build` を使う設計判断は妥当 -- `_sim` バリアント自体で初回呼び出しを行っても `setup_flag` が自動生成されて ALLOW になるが、「`session_set_defaults` を経由する正しいフロー」の検証としては `build` → `session_set_defaults` → `_sim` の手順の方が明確。

## R6: DEVELOPMENT.md 準拠

**PASS**

| ルール | 準拠状況 |
|--------|---------|
| Version bump in same PR | `.claude-plugin/plugin.json` 1.1.0 → 1.1.1（Step 4） |
| CHANGELOG.md update | `[Unreleased]` に Fixed エントリ追加（Step 4） |
| SemVer | PATCH increment（バグフィックス）-- 正しい |
| Keep a Changelog format | `### Fixed` セクション -- 正しい |
| Zero Dependencies | 新規依存なし -- 準拠 |

**確認ポイント（ブロッカーではない）:** DEVELOPMENT.md の「Directory READMEs」ルールにより、`addons/ios/tests/` に README.md が存在しテストファイル一覧を含む場合は、新規テストファイルの追加を反映する必要がある。impl-strategy にこの点の記載がないが、実装時に確認すれば問題ない。

## R7: 実装順序の妥当性

**PASS**

```
Step 1: guard 修正 → Step 2: テスト作成 → Step 3: テスト実行・回帰確認 → Step 4: version/changelog
```

依存関係が正しく反映されている:
- Step 2 は Step 1 に依存（修正後のスクリプトに対してテストを実行）
- Step 3 は Step 1-2 に依存（新規テスト + 既存テストの全パス）
- Step 4 は Step 1-3 に依存（テスト全パス確認後に housekeeping）

## R8: Decision Trail 整合性

| ドキュメント | 統合 Plan との整合 |
|------------|------------------|
| `ac-review-qa.md` | AC1-AC3 の Then 節修正が反映済み。静的検証 + 否定テストの追加が反映済み。AC5 統合提案は採用されず独立 AC として維持（妥当 -- 既存テストスイートで検証という明確な方針）。 |
| `ac-review-developer.md` | M1（AC5 テスト条件明確化）が AC3/AC4 として反映済み。M2（配置位置）が impl-strategy に反映済み（`build` → `build_sim` → `build_run_sim` → `test` → `test_sim` → `run`）。 |
| `test-strategy-qa.md` | 12 テストケース、session_id 分離、setup/teardown 流用、カバレッジマトリクスがすべて impl-strategy に反映済み。 |
| `impl-strategy-developer.md` | テスト構成、実装順序、リスク評価が統合 Plan と一致。 |

全ドキュメント間の整合性に問題なし。

## Summary

| 項目 | 評価 |
|------|------|
| R1: テスト層の妥当性 | PASS |
| R2: カバレッジ網羅性 | PASS |
| R3: テストファイル構成 | PASS |
| R4: セッション ID 分離 | PASS |
| R5: AC4 テスト手順 | PASS |
| R6: DEVELOPMENT.md 準拠 | PASS |
| R7: 実装順序 | PASS |
| R8: Decision Trail 整合性 | PASS |

**Overall: PASS** -- 統合 Plan は実装に進んでよい。

**実装時の確認事項（ブロッカーではない）:**
1. `addons/ios/tests/README.md` が存在しテストファイル一覧を含む場合、`test_sim_clone_required_variants.bats` の追加を反映すること
