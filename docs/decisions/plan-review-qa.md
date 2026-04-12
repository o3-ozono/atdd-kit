# Plan Review: QA

**Issue:** #21 — fix: sim-pool-guard.sh の allowlist を fail-closed → fail-open に設計転換
**Reviewer:** QA Agent
**Date:** 2026-04-12
**Prior Decisions:** `ac-review-qa.md`, `test-strategy-qa.md`, `impl-strategy-developer.md`

## Overall Verdict: CONDITIONAL PASS

Plan は 8 AC 全てをカバーしており、実装順序・テスト構成の骨格に大きな問題はない。ただし **2 つの Blocker** と **3 つの要修正事項** がある。これらを解決すれば実装着手可能。

---

## Checklist Results

### [x] Test coverage for all 8 ACs is maintained

| AC | Plan Step | Test Coverage | Status |
|----|-----------|--------------|--------|
| AC1 (fail-open) | 1.5, 2.2 (FO1.1-FO1.5) | 5 tests | OK |
| AC2a (`_sim` pattern) | 1.3, 2.2 (FO2.1-FO2.3) | 3 tests | OK |
| AC2b (individual tools) | 1.3, 2.2 (FO2.4-FO2.7) | 4 tests | OK |
| AC3 (ios-sim UDID) | 1.4, 2.3 | 既存テスト更新 | **要修正 (B1, B2)** |
| AC4 (DENY erase_sims) | 1.2, 2.2 (FO3.1-FO3.2) | 2 tests | OK |
| AC5 (DENY before session_id) | 1.2, 2.2 (FO3.3) | 1 test | OK |
| AC6 (READONLY removal) | 1.1, 2.2 (FO4.1-FO4.3) | 3 tests | OK |
| AC7 (persist:true) | unchanged, 2.4 | 既存 10 tests | OK |
| AC8 (BATS update) | 2.1-2.4, 4.2 | meta verification | OK |

### [NEEDS ADJUSTMENT] Test cases align with `*_sim` suffix-only pattern behavior

Suffix-only `*_sim` パターンの影響で、テスト戦略の以下のテストケースが実装と不整合:

| テストケース (test-strategy-qa.md) | 期待値 (テスト戦略) | 実際の動作 (`*_sim` suffix) | Action |
|-----------------------------------|-------------------|---------------------------|--------|
| AC2a.5: `record_sim_video` | DENY (guidance) | **ALLOW** (fail-open) | 期待値を ALLOW に変更 |
| AC2a.6: `start_sim_log_cap` | DENY (guidance) | **ALLOW** (fail-open) | 期待値を ALLOW に変更 |
| AC2a.EDGE.1: `boot_simulator` | 境界 (実装依存) | **ALLOW** (fail-open) | 期待値を ALLOW に確定 |

### [INCOMPLETE] Existing test file update list is complete

Plan の「Unchanged Files (verify-only)」に含まれる 5 テストファイルが実際にはツール名更新が必要 (B2)。

### [NEEDS ADJUSTMENT] Edge case tests correctly reflect the implementation design

`*_sim` suffix パターンの境界テストに追加が必要 (M1)。

### [x] No test gaps for the fail-open default path

---

## Blocker B1: CLONE_REQUIRED_IOS_SIM のツール名が旧名のまま

**Severity: Blocker**

実装戦略 Step 1.4 の `CLONE_REQUIRED_IOS_SIM` 配列には **旧 ios-simulator ツール名** (22 エントリ) が使われている:

```bash
# impl-strategy Step 1.4 (旧名 — 問題あり)
CLONE_REQUIRED_IOS_SIM=(
  "mcp__ios-simulator__launch_app"        # OK (名称変更なし)
  "mcp__ios-simulator__terminate_app"     # DEAD: 廃止
  "mcp__ios-simulator__tap"              # DEAD: → ui_tap
  "mcp__ios-simulator__swipe"            # DEAD: → ui_swipe
  "mcp__ios-simulator__long_press"       # DEAD: 廃止
  "mcp__ios-simulator__type_text"        # DEAD: → ui_type
  "mcp__ios-simulator__press_button"     # DEAD: 廃止
  "mcp__ios-simulator__open_url"         # DEAD: 廃止
  "mcp__ios-simulator__take_screenshot"  # DEAD: → screenshot
  "mcp__ios-simulator__list_apps"        # DEAD: 廃止
  "mcp__ios-simulator__get_ui_hierarchy" # DEAD: → ui_describe_all
  "mcp__ios-simulator__start_recording"  # DEAD: → record_video
  ...22 entries total
)
```

承認済み AC3 では **新ツール名 11 エントリ** が明確に列挙されている:

```
install_app, launch_app, open_simulator, record_video, screenshot,
ui_describe_all, ui_describe_point, ui_swipe, ui_tap, ui_type, ui_view
```

**22 エントリ (旧名) vs 11 エントリ (新名)** — 数も名前も不一致。

**Impact:**
- 旧名でデプロイすると、旧名ツールは現行 MCP で呼ばれないため dead entry になる
- 新名ツールは CLONE_REQUIRED にマッチせず fail-open ALLOW (UDID 注入なし)
- ios-simulator の全ツールが UDID 注入なしで動作 → ゴールデンイメージを直接操作するリスク

**Required fix:** Step 1.4 を AC3 の 11 新ツール名に置き換える:

```bash
CLONE_REQUIRED_IOS_SIM=(
  "mcp__ios-simulator__install_app"
  "mcp__ios-simulator__launch_app"
  "mcp__ios-simulator__open_simulator"
  "mcp__ios-simulator__record_video"
  "mcp__ios-simulator__screenshot"
  "mcp__ios-simulator__ui_describe_all"
  "mcp__ios-simulator__ui_describe_point"
  "mcp__ios-simulator__ui_swipe"
  "mcp__ios-simulator__ui_tap"
  "mcp__ios-simulator__ui_type"
  "mcp__ios-simulator__ui_view"
)
```

### B1 の波及影響

- **Step 2.3** (test_sim_clone_required_variants.bats): 静的 grep テストで新配列名 `CLONE_REQUIRED_IOS_SIM` + 新ツール名に対応
- **テスト戦略 Section 3.3**: ios-simulator テストのツール名を全て新名に更新

---

## Blocker B2: 既存テスト 5 ファイルのツール名更新が Plan から欠落

**Severity: Blocker**

Plan の「Unchanged Files (verify-only)」セクションで以下が「untouched」とされている:

| ファイル | Plan の判定 | 実際の影響 |
|---------|-----------|----------|
| test_sim_auto_inject.bats | "UDID injection logic untouched" | `mcp__ios-simulator__tap` (旧名) で UDID 注入テスト → 新 CLONE_REQUIRED_IOS_SIM にマッチしなくなり **FAIL** |
| test_sim_ephemeral_clone.bats | "Clone lifecycle untouched" | `mcp__ios-simulator__tap`, `take_screenshot` → 同上 |
| test_sim_golden_init.bats | "Golden init logic untouched" | `mcp__ios-simulator__tap` → 同上 |
| test_sim_golden_set_fallback.bats | "Golden set logic untouched" | `mcp__ios-simulator__tap` → 同上 |
| test_sim_orphan_cleanup.bats | "Cleanup logic untouched" | `mcp__ios-simulator__tap` → 同上 |

これらのテストは `run_guard "mcp__ios-simulator__tap"` を呼んでいるが、新 `CLONE_REQUIRED_IOS_SIM` には `ui_tap` が含まれるため、旧名 `tap` は fail-open ALLOW (UDID 注入なし) になる。UDID 検証 (`updatedInput.udid == "CLONE-UUID-5678"`) が FAIL する。

**Required fix:** Plan に Step 2.5 を追加:

> **Step 2.5 — Update ios-simulator tool names in 5 existing test files**
>
> | 旧名 | 新名 | 対象ファイル数 |
> |------|------|------------|
> | `mcp__ios-simulator__tap` | `mcp__ios-simulator__ui_tap` | 5 files |
> | `mcp__ios-simulator__take_screenshot` | `mcp__ios-simulator__screenshot` | 1 file (ephemeral_clone) |
> | `mcp__XcodeBuildMCP__build` | `mcp__XcodeBuildMCP__build_sim` | 2 files (auto_inject, clone_required_variants) — see M2 |

---

## 要修正事項 M1: `*_sim` パターンの境界テスト調整

**Severity: Medium**

テスト戦略の以下のテストが `*_sim` suffix-only パターンと不整合:

**修正が必要なテストケース:**

| Test ID | ツール名 | テスト戦略の期待値 | `*_sim` suffix での実際 | 修正後の期待値 |
|---------|---------|-----------------|----------------------|-------------|
| AC2a.5 | `record_sim_video` | DENY (guidance) | ALLOW (fail-open) | ALLOW |
| AC2a.6 | `start_sim_log_cap` | DENY (guidance) | ALLOW (fail-open) | ALLOW |
| AC2a.EDGE.1 | `boot_simulator` | 境界 (実装依存) | ALLOW (fail-open) | ALLOW |

**追加すべきテストケース:**

| Test ID | ツール名 | 期待値 | 検証目的 |
|---------|---------|--------|---------|
| AC2a.EDGE.3 | `record_sim_video` | ALLOW | `_sim` substring が suffix でないツールの fail-open 検証 |
| AC2a.EDGE.4 | `start_sim_log_cap` | ALLOW | 同上 |
| AC2a.8 | `debug_attach_sim` | DENY (guidance) | `_sim` suffix のデバッグツールが CLONE_REQUIRED になることを検証 |

## 要修正事項 M2: `mcp__XcodeBuildMCP__build` (suffix なし) の扱い

**Severity: Medium**

テスト戦略のリスク 4 で指摘済みだが、Plan で明確な対応がない。

**Current state:** 現行コードでは `build` が `CLONE_REQUIRED_TOOLS` に含まれる。
**After change:** `build` は `*_sim` パターンにも `is_xcode_clone_required()` の個別リストにも含まれない → fail-open ALLOW。

**影響するテスト:**

| ファイル | テスト | 現在の動作 | 変更後の動作 |
|---------|--------|----------|------------|
| test_sim_auto_inject.bats AC5.1 | `run_guard "mcp__XcodeBuildMCP__build"` | DENY (guidance) | ALLOW (fail-open) → **FAIL** |
| test_sim_auto_inject.bats AC5.2 | `session_set_defaults` 後の `build` | ALLOW | ALLOW (ただしテストの前提が変わる) |
| test_sim_clone_required_variants.bats AC4.1-4.3 | `build` を使って clone を作成 | clone 作成 → DENY | ALLOW (clone 作成されない) → **FAIL** |

**Required fix:** これらのテストの `mcp__XcodeBuildMCP__build` を `mcp__XcodeBuildMCP__build_sim` に置換。Plan Step 2.5 に含める。

## 要修正事項 M3: DENY メッセージの文言統一

**Severity: Low**

実装戦略 Step 1.2 の DENY メッセージ:
```
"sim-pool: '${tool_name}' is denied to protect the golden image."
```

承認済み AC4 の Then:
```
"golden image protection: use Xcode to manage simulators directly"
```

文言が異なる。テスト FO3.2 (`reason contains "golden image"`) は両方にマッチするが、AC4 の Then 文言と正確に一致するか要確認。

**Recommendation:** テスト FO3.2 は `"golden image"` の部分一致で検証し、正確な文言は実装者に委ねる。

---

## Plan Step 別レビュー

### Step 1.1: READONLY_TOOLS 削除 (AC6) — PASS

削除対象の行番号（L33-49, L387-390）が正確。`set -u` 対応は参照ごと全削除で解決。DENY_TOOLS / CLONE_REQUIRED_IOS_SIM は少なくとも 1 エントリを持つため `${array[@]}` 展開で `set -u` エラーなし。

### Step 1.2: DENY_TOOLS + check (AC4, AC5) — PASS

DENY check を session_id check より先に配置する設計は AC5 を正確に満たす。

### Step 1.3: `is_xcode_clone_required()` (AC2a, AC2b) — PASS

`case` glob `*_sim` は POSIX 互換で安全。個別指定 4 ツールは承認済み AC2b と一致。

**confirm:** `session_set_defaults` / `session_use_defaults_profile` は `PERSIST_CHECK_TOOLS` にも含まれるが、main() で persist check (step 3) が clone check (step 4) より先に実行されるため、`persist:true` は clone routing に到達前にブロックされる。正しい。

### Step 1.4: CLONE_REQUIRED_IOS_SIM (AC3) — **BLOCKER B1**

旧ツール名 22 エントリ → 新ツール名 11 エントリへの置き換えが必要。

### Step 1.5: main() 書き換え (AC1) — PASS

DENY → session_id → persist → xcode_clone → ios_sim → ALLOW の順序は正しい。

### Step 1.6: ヘッダーコメント更新 — PASS

### Step 2.1: failclosed 削除 — PASS

### Step 2.2: failopen 新規作成 (23 tests) — PASS

テスト戦略の 17 テスト + Plan 追加テスト。カバレッジ良好。

### Step 2.3: clone_required_variants 更新 — **B1 連動で修正必要**

### Step 2.4: persist_block 検証 — PASS

### Step 2.5: (欠落) 既存テスト 5 ファイルのツール名更新 — **BLOCKER B2**

### Step 3.1: CHANGELOG — PASS

### Step 3.2: Version bump — PASS

実装戦略では `1.2.0` (MINOR)。fail-closed → fail-open は observable behavior change なので MINOR が妥当。

### Step 4: Verification — PASS

---

## Decision Trail 整合性

| ドキュメント | 統合 Plan との整合 | 注意点 |
|------------|------------------|--------|
| ac-review-qa.md | 空 session_id + DENY (Gap 2) → AC5 で対応済み。clone 失敗時 DENY (Gap 3) → AC2a/AC3 の Then に含まれている。37 ツール列挙 → 27 ツール (16 XcodeBuildMCP + 11 ios-sim) に修正済み。ツール名不整合 → **B1 で未解決** | B1 解決必要 |
| test-strategy-qa.md | テスト構成は Plan と整合。ただし `*_sim` suffix パターンとの不整合 (M1) あり | M1 解決必要 |
| impl-strategy-developer.md | 実装順序・flow diagram は正確。**Step 1.4 のツール名が B1** | B1 解決必要 |

---

## Summary

| # | Severity | Item | Status | Required Action |
|---|----------|------|--------|----------------|
| B1 | **Blocker** | CLONE_REQUIRED_IOS_SIM に旧ツール名 (22 entries) が使用されている | FAIL | AC3 の 11 新ツール名に置き換え |
| B2 | **Blocker** | 既存テスト 5 ファイルのツール名更新が Plan から欠落 | FAIL | Step 2.5 追加: `tap`→`ui_tap`, `take_screenshot`→`screenshot`, `build`→`build_sim` |
| M1 | Medium | `*_sim` suffix パターンとテスト期待値の不整合 | WARN | 3 テスト修正 + 3 テスト追加 |
| M2 | Medium | `build` (suffix なし) の扱いがテストに反映されていない | WARN | `build` → `build_sim` 置換 (B2 に含める) |
| M3 | Low | DENY メッセージ文言が AC4 と実装で異なる | INFO | テストは部分一致で検証 (影響なし) |

**B1 + B2 を解決すれば PASS。M1 + M2 は実装中に修正可能。**
