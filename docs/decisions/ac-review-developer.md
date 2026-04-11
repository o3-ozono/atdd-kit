# AC Review: Developer Perspective

**Issue:** #1 — bug: sim-pool-guard.sh が build_sim / build_run_sim / test_sim を CLONE_REQUIRED_TOOLS から除外している
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Assessment

Draft AC set は技術的に正確で、修正範囲も最小限に抑えられている。`CLONE_REQUIRED_TOOLS` 配列に 3 エントリを追加するだけで完結する変更であり、fail-closed 設計を維持したまま allowlist gap を塞ぐ正しいアプローチである。

`handle_xcodebuildmcp` のルーティングパスを精査した結果、`_sim` バリアント 3 ツールは既存の `build` / `test` / `run` と全く同じ制御フローを辿ることを確認した。特別な分岐や追加ロジックは不要。

**Verdict: PASS** — 軽微な改善提案あり（下記参照）。

## Per-AC Feedback

### AC1: build_sim の ALLOW — PASS

**実現性:** 高い。`CLONE_REQUIRED_TOOLS` 配列に `"mcp__XcodeBuildMCP__build_sim"` を 1 行追加するのみ。

**ルーティング確認:** `main()` の case 文（396行目）で `mcp__XcodeBuildMCP__*` にマッチし、`handle_xcodebuildmcp` にルーティングされる。`handle_xcodebuildmcp` 内では:
- 320行目の `session_set_defaults` チェックにはマッチしない（正常）
- 326行目の `session_use_defaults_profile` チェックにはマッチしない（正常）
- 332-338行目の `setup_flag` チェックが適用される（`build` と同じ挙動）
- `setup_flag` 存在時は 341行目で ALLOW される

**エッジケースなし。** 既存の `build` と全く同じパスを辿る。

### AC2: build_run_sim の ALLOW — PASS

**実現性:** AC1 と同一のメカニズム。配列に 1 行追加。

**補足:** `build_run_sim` は `build` + `run` の複合ツールだが、guard の観点では単一のツール名として扱われる。`handle_xcodebuildmcp` は個別の `build` や `run` とは独立して `build_run_sim` を処理する。ルーティングは正常。

### AC3: test_sim の ALLOW — PASS

**実現性:** AC1 と同一のメカニズム。配列に 1 行追加。

**ルーティング確認:** `test` と `test_sim` は異なるツール名だが、両方とも `mcp__XcodeBuildMCP__*` パターンに一致し、同じ `handle_xcodebuildmcp` ハンドラで処理される。問題なし。

### AC4: 既存ツールの動作維持 — PASS

**実現性:** 高い。`CLONE_REQUIRED_TOOLS` への追加は配列末尾への append であり、既存エントリの順序や内容に影響しない。`in_array` 関数は線形探索なので、要素追加で既存マッチに影響なし。

**テスト方針:** 既存テスト（`test_sim_failclosed_guard.bats`、`test_sim_ephemeral_clone.bats` 等）がリグレッションガードとして機能する。新規テストに加え、既存テストの全パスを確認すれば十分。

### AC5: handle_xcodebuildmcp ルーティング — PASS（AC1-3 と統合可能）

**実現性:** 高い。前述の通り、`_sim` バリアントは `mcp__XcodeBuildMCP__*` パターンにマッチし、`handle_xcodebuildmcp` に正しくルーティングされる。

**懸念点なし。** ただし、この AC は AC1-3 の Then 節で暗黙的にカバーされている（「クローン確保後に ALLOW」されるには `handle_xcodebuildmcp` を経由する必要がある）。独立した AC として持つことは、`session_set_defaults` 事前チェックの適用を明示的に検証する点で価値がある。

**テスト実装の補足:** AC5 のテストでは、`setup_flag` が存在しない状態で `_sim` ツールを呼んだ際に `session_set_defaults` を促す DENY メッセージが返ることを検証すべき。これにより `handle_xcodebuildmcp` のルーティングと事前チェックの両方が確認できる。

## Suggested Modifications

### M1: AC5 のテスト条件を明確化

AC5 の Then 節は「session_set_defaults 事前チェックが適用される」と記述しているが、テスト可能な条件に変換すると以下の 2 つになる:

1. **setup_flag なし:** `_sim` ツール呼び出し → DENY with context（「session_set_defaults を先に実行」メッセージ）
2. **setup_flag あり:** `_sim` ツール呼び出し → ALLOW

この 2 条件を AC5 の Then 節に明記することを推奨。

### M2: CLONE_REQUIRED_TOOLS 内の配置位置

機能的に影響はないが、可読性のため `build_sim` / `build_run_sim` / `test_sim` は既存の `build` / `test` / `run` の直後に配置することを推奨。関連ツールが近接していると保守性が向上する。

```bash
CLONE_REQUIRED_TOOLS=(
  "mcp__XcodeBuildMCP__build"
  "mcp__XcodeBuildMCP__build_sim"        # NEW
  "mcp__XcodeBuildMCP__build_run_sim"    # NEW
  "mcp__XcodeBuildMCP__test"
  "mcp__XcodeBuildMCP__test_sim"         # NEW
  "mcp__XcodeBuildMCP__run"
  ...
)
```

現在の配列（51-79行目）では `build` → `test` → `run` の順で並んでいるため、各ツールの直後にバリアントを挿入するのが自然。

## Implementation Complexity Estimate

### 変更ファイル

| File | Change | Complexity |
|------|--------|------------|
| `addons/ios/scripts/sim-pool-guard.sh` | `CLONE_REQUIRED_TOOLS` に 3 エントリ追加 | Minimal — 3 行追加 |
| `addons/ios/tests/` | 新規テストファイルまたは既存テストに追加 | Low — 既存パターン踏襲 |

**Total: 2 ファイル、最小限の変更。**

### テストアプローチ

既存の `test_sim_failclosed_guard.bats` のパターンを踏襲:

1. **AC1-3 テスト:** `run_guard "mcp__XcodeBuildMCP__build_sim"` 等を呼び出し、`setup_flag` 存在下で ALLOW が返ることを確認
2. **AC4 テスト:** 既存テストスイートの全パスで回帰がないことを確認（追加テスト不要、既存テストがカバー）
3. **AC5 テスト:** `setup_flag` なし状態で `_sim` ツールを呼び出し、DENY with context（`session_set_defaults` 促進メッセージ）が返ることを確認
4. **fail-closed テスト:** 追加後も `mcp__XcodeBuildMCP__unknown_tool` が DENY されることを確認（AC3.9 既存テストがカバー）

テストの mock 設定は `test_sim_ephemeral_clone.bats` の `setup()` をそのまま流用可能。

### リスク評価

**極めて低い。** 変更は配列への 3 要素追加のみ。既存のロジック（`in_array`、`handle_xcodebuildmcp`、`main()` のフロー）に一切手を加えない。fail-closed 設計は維持され、新ツールは既存ツールと完全に同じ制御パスを辿る。
