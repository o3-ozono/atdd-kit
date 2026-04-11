# Implementation Strategy: Developer

**Issue:** #1 — bug: sim-pool-guard.sh が build_sim / build_run_sim / test_sim を CLONE_REQUIRED_TOOLS から除外している
**Author:** Developer Agent
**Date:** 2026-04-12

## 1. 変更ファイル一覧と変更内容

### 1-A. `addons/ios/scripts/sim-pool-guard.sh` — CLONE_REQUIRED_TOOLS 配列修正

**変更内容:** `CLONE_REQUIRED_TOOLS` 配列に 3 エントリを追加する。

**現在の配列 (L51-79):**
```bash
CLONE_REQUIRED_TOOLS=(
  "mcp__XcodeBuildMCP__build"          # L52
  "mcp__XcodeBuildMCP__test"           # L53
  "mcp__XcodeBuildMCP__run"            # L54
  "mcp__XcodeBuildMCP__session_set_defaults"   # L55
  ...
)
```

**修正後の配列 (L52-57 付近):**
```bash
CLONE_REQUIRED_TOOLS=(
  "mcp__XcodeBuildMCP__build"
  "mcp__XcodeBuildMCP__build_sim"           # NEW
  "mcp__XcodeBuildMCP__build_run_sim"       # NEW
  "mcp__XcodeBuildMCP__test"
  "mcp__XcodeBuildMCP__test_sim"            # NEW
  "mcp__XcodeBuildMCP__run"
  "mcp__XcodeBuildMCP__session_set_defaults"
  ...
)
```

**配置位置の根拠:** AC Review (M2) の提案に従い、関連ツールの直後に配置して可読性を確保する。
- `build_sim` と `build_run_sim` は `build` の直後
- `test_sim` は `test` の直後

**ロジック変更: なし。** `in_array` 関数は線形探索のため、配列内の位置に依存しない。`handle_xcodebuildmcp` と `main()` のフロー、case 文のパターンマッチングに変更不要。

### 1-B. `addons/ios/tests/test_sim_clone_required_variants.bats` — 新規テストファイル

**変更内容:** QA レビューで提案されたテスト構成に基づき、新規テストファイルを作成。12 テストケース。

**テスト構成:**

| AC | テスト名 | 検証タイプ |
|----|---------|-----------|
| AC1 | AC1.1-1.3: CLONE_REQUIRED_TOOLS contains build_sim / build_run_sim / test_sim | 静的: `grep -q` + `sed -n` |
| AC2 | AC2.1-2.3: build_sim / build_run_sim / test_sim NOT in READONLY_TOOLS | 静的: `! grep -q` + `sed -n` |
| AC3 | AC3.1-3.3: first call is DENY with session_set_defaults instruction | 動的: `jq -e` + additionalContext 検証 |
| AC4 | AC4.1-4.3: ALLOW after session_set_defaults | 動的: `jq -e` permissionDecision == "allow" |

**setup/teardown:** `test_sim_auto_inject.bats` のパターンをそのまま流用。
- mock `xcrun` でゴールデンイメージとクローン応答をスタブ
- 環境変数（`SIM_SESSION_DIR`, `SIM_MARKER_DIR`, `SIM_GOLDEN_NAME`）を設定
- ゴールデンマーカー `atdd-kit-golden-initialized-iOS-18-0` を事前作成（golden init スキップ）

**AC3 テストの注意点:** 各テストケースは独立したセッション ID を使用する。`handle_xcodebuildmcp` は初回呼び出し時に `setup_flag` を touch するため（L334）、同一セッション ID で複数ツールをテストすると 2 番目以降が ALLOW になる。

**AC4 テストの手順:** `test_sim_auto_inject.bats` AC5.2 のパターンに従う:
1. `build` 等で初回呼び出し（クローン作成 + setup_flag 作成）
2. `session_set_defaults` を呼び出し（setup_flag セット）
3. `_sim` バリアントを呼び出し → ALLOW を確認

### 1-C. `CHANGELOG.md` — バグフィックスエントリ追加

**変更内容:** `[Unreleased]` セクションに `Fixed` エントリを追加。

```markdown
## [Unreleased]

### Fixed
- sim-pool-guard.sh: add `build_sim`, `build_run_sim`, `test_sim` to `CLONE_REQUIRED_TOOLS` — previously denied by fail-closed guard (#1)
```

### 1-D. `.claude-plugin/plugin.json` — バージョンバンプ

**変更内容:** `1.1.0` → `1.1.1` (patch bump — バグフィックス)

```json
"version": "1.1.1"
```

**根拠:** SemVer patch increment。機能追加なし、既存 API の breaking change なし。fail-closed guard の allowlist gap を修正するバグフィックス。

## 2. 実装順序

依存関係を考慮した実装順序:

```
Step 1: addons/ios/scripts/sim-pool-guard.sh
   |     -- 本体修正。テストの前提。
   |
Step 2: addons/ios/tests/test_sim_clone_required_variants.bats
   |     -- 修正後のスクリプトに対するテスト。Step 1 に依存。
   |
Step 3: テスト実行・既存テストの回帰確認
   |     -- Step 1-2 に依存。AC5 の検証。
   |
Step 4: CHANGELOG.md  ||  .claude-plugin/plugin.json
         -- Housekeeping。Step 1-3 完了後。同一 PR に含める。
```

**Per-AC mapping:**

| AC | Primary file | Step |
|----|-------------|------|
| AC1 | `sim-pool-guard.sh` (CLONE_REQUIRED_TOOLS) | 1 |
| AC2 | `sim-pool-guard.sh` (READONLY_TOOLS に追加しないことの検証) | 2 (テスト) |
| AC3 | `sim-pool-guard.sh` (handle_xcodebuildmcp ルーティング) | 1 (暗黙) + 2 (テスト) |
| AC4 | `sim-pool-guard.sh` (handle_xcodebuildmcp + setup_flag) | 1 (暗黙) + 2 (テスト) |
| AC5 | 既存テストスイート | 3 (回帰テスト) |

## 3. 配置位置の詳細

`sim-pool-guard.sh` L51-79 の `CLONE_REQUIRED_TOOLS` 配列を以下の順序に変更:

```bash
CLONE_REQUIRED_TOOLS=(
  "mcp__XcodeBuildMCP__build"
  "mcp__XcodeBuildMCP__build_sim"              # NEW — build の直後
  "mcp__XcodeBuildMCP__build_run_sim"          # NEW — build_sim の直後
  "mcp__XcodeBuildMCP__test"
  "mcp__XcodeBuildMCP__test_sim"               # NEW — test の直後
  "mcp__XcodeBuildMCP__run"
  "mcp__XcodeBuildMCP__session_set_defaults"
  "mcp__XcodeBuildMCP__session_use_defaults_profile"
  "mcp__ios-simulator__launch_app"
  "mcp__ios-simulator__terminate_app"
  "mcp__ios-simulator__tap"
  "mcp__ios-simulator__swipe"
  "mcp__ios-simulator__long_press"
  "mcp__ios-simulator__type_text"
  "mcp__ios-simulator__press_button"
  "mcp__ios-simulator__open_url"
  "mcp__ios-simulator__take_screenshot"
  "mcp__ios-simulator__list_apps"
  "mcp__ios-simulator__get_ui_hierarchy"
  "mcp__ios-simulator__start_recording"
  "mcp__ios-simulator__add_media"
  "mcp__ios-simulator__set_location"
  "mcp__ios-simulator__clear_keychain"
  "mcp__ios-simulator__get_app_container"
  "mcp__ios-simulator__push_notification"
  "mcp__ios-simulator__set_permission"
  "mcp__ios-simulator__uninstall_app"
  "mcp__ios-simulator__boot_simulator"
  "mcp__ios-simulator__shutdown_simulator"
  "mcp__ios-simulator__erase_simulator"
)
```

XcodeBuildMCP ツールのグループ順序: `build` → `build_sim` → `build_run_sim` → `test` → `test_sim` → `run` → `session_*`

## 4. テストファイル構成の詳細

### ファイル: `addons/ios/tests/test_sim_clone_required_variants.bats`

setup/teardown は `test_sim_auto_inject.bats` と同一パターン。mock `xcrun`、環境変数設定、ゴールデンマーカー事前作成の 3 点セット。

#### 静的検証テスト (AC1, AC2)

| テスト | パターン | 参考テスト |
|--------|---------|-----------|
| AC1.1-1.3: 配列含有 | `grep -q '"mcp__XcodeBuildMCP__build_sim"' <(sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD")` | `test_sim_failclosed_guard.bats` AC3.12-AC3.13 |
| AC2.1-2.3: 配列非含有 | `! grep -q '"mcp__XcodeBuildMCP__build_sim"' <(sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD")` | `test_sim_failclosed_guard.bats` AC3.12 |

#### 動的検証テスト (AC3, AC4)

| テスト | パターン | 参考テスト |
|--------|---------|-----------|
| AC3.1-3.3: 初回 DENY | `jq -e '.hookSpecificOutput.permissionDecision == "deny"'` + additionalContext に `session_set_defaults` 含有 | `test_sim_auto_inject.bats` AC5.1 |
| AC4.1-4.3: ALLOW | `jq -e '.hookSpecificOutput.permissionDecision == "allow"'` | `test_sim_auto_inject.bats` AC5.2 |

#### AC3 のセッション ID 分離

各 AC3 テストは独立したセッション ID を使用:
- AC3.1: `session-ac3-1`
- AC3.2: `session-ac3-2`
- AC3.3: `session-ac3-3`

これにより、`handle_xcodebuildmcp` L334 の `touch "$setup_flag"` が他テストに影響しない。

#### AC4 の 3 ステップ手順

```bash
# Step 1: 初回呼び出しでクローン作成 + setup_flag 作成
run_guard "mcp__XcodeBuildMCP__build" '{}' "session-ac4-1" > /dev/null 2>&1 || true

# Step 2: session_set_defaults でセットアップ完了
run_guard "mcp__XcodeBuildMCP__session_set_defaults" \
  '{"simulatorName":"atdd-kit-clone","persist":false}' "session-ac4-1"

# Step 3: _sim バリアントが ALLOW されることを確認
result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "session-ac4-1")
echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "allow"'
```

### AC5 (既存ツール動作維持) のテスト方針

AC5 は新規テストを作成しない。以下の既存テストスイート全パスで検証:
- `test_sim_failclosed_guard.bats` (17 テスト)
- `test_sim_auto_inject.bats` (6 テスト)
- `test_sim_ephemeral_clone.bats` (7 テスト)
- `test_sim_persist_block.bats`
- その他の `addons/ios/tests/test_sim_*.bats`

## 5. リスク評価

### 壊れる可能性があるもの

| リスク | 可能性 | 影響 | 軽減策 |
|--------|--------|------|--------|
| 既存テストの回帰 | 極低 | 高 | 既存テストスイート全パスを確認 |
| タイポによる配列エントリ不一致 | 低 | 中 | 静的検証テスト (AC1) で防止 |
| 配列順序変更による副作用 | なし | - | `in_array` は線形探索で順序非依存 |
| `handle_xcodebuildmcp` の予期しない分岐 | なし | - | L320, L326 の条件は完全一致比較で `_sim` バリアントにマッチしない |
| `PERSIST_CHECK_TOOLS` への影響 | なし | - | `_sim` バリアントは persist check 対象外（正しい挙動） |

**総合リスク: 極めて低い。** 変更は配列への 3 要素追加のみで、ロジック変更なし。

## 6. CHANGELOG / バージョン更新

### CHANGELOG.md

```markdown
## [Unreleased]

### Fixed
- sim-pool-guard.sh: add `build_sim`, `build_run_sim`, `test_sim` to `CLONE_REQUIRED_TOOLS` — previously denied by fail-closed guard (#1)
```

### .claude-plugin/plugin.json

```json
"version": "1.1.1"
```

**バージョン選択の根拠:**
- MAJOR: 変更なし（breaking change なし）
- MINOR: 変更なし（新機能追加なし）
- PATCH: +1（バグフィックス — allowlist gap の修正）

DEVELOPMENT.md のルール「Every feature PR merged to main must update the version and changelog」に従い、同一 PR に含める。

## Summary

| # | File | Action | Lines changed |
|---|------|--------|---------------|
| 1 | `addons/ios/scripts/sim-pool-guard.sh` | 配列に 3 行追加 | +3 |
| 2 | `addons/ios/tests/test_sim_clone_required_variants.bats` | 新規作成 (12 テスト) | +~120 |
| 3 | `CHANGELOG.md` | Fixed エントリ追加 | +3 |
| 4 | `.claude-plugin/plugin.json` | version bump 1.1.0 → 1.1.1 | +1 -1 |

**Total: 4 ファイル (3 modified, 1 new)。全変更は additive。削除やリファクタリングなし。**
