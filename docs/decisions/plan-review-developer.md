# Plan Review: Developer

**Issue:** #21 — fix: sim-pool-guard.sh の allowlist を fail-closed → fail-open に設計転換
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Verdict: CONDITIONAL PASS

Plan のアーキテクチャと実装順序は正しい。ただし以下の 3 点の修正が必要:

1. **[BLOCKER] バージョン番号の誤り** — 現在のバージョンは 1.4.0（1.3.0 ではない）。bump は 1.4.0 → 1.5.0
2. **[BLOCKER] QA テスト戦略の `*_sim` パターン境界テストに誤り** — `record_sim_video` と `start_sim_log_cap` は `*_sim` glob にマッチしない
3. **[WARNING] ios-simulator 新ツール名の実在性が未検証** — `ui_tap`, `ui_swipe` 等の新名称の根拠を確認すべき

## Checklist Review

### [x] ファイル変更順序に依存関係の問題がないか

**PASS。** 依存チェーン:

```
Step 1 (READONLY 削除) → Step 2 (DENY_TOOLS) → Step 3 (is_xcode_clone_required) → Step 4 (CLONE_REQUIRED_IOS_SIM) → Step 5 (main() rewrite)
```

Step 1-5 は全て `sim-pool-guard.sh` 内の変更で、この順序は論理的に正しい:
- Step 1 で READONLY_TOOLS を消さないと Step 5 の `main()` rewrite で参照残りが発生する
- Step 2 の DENY_TOOLS は Step 5 の `main()` で参照されるため先に定義が必要
- Step 3 の `is_xcode_clone_required()` も同様
- Step 4 の配列リネームは Step 5 の `main()` で参照される

Step 6-8（テスト）は Step 1-5 完了後に実行。テストが本体より後なので問題なし。

Step 9（CHANGELOG + version）は最後。正しい。

### [x] `case` glob `*_sim` パターンのカバレッジ

**CONDITIONAL PASS — QA テストの境界ケースに矛盾あり。**

Implementation Strategy で定義した `case` glob `*_sim` は **末尾一致のみ**:

```bash
case "$tool" in
  mcp__XcodeBuildMCP__*_sim) return 0 ;;
```

これは以下のように動作する:

| ツール名（接尾部分） | `*_sim` マッチ | 理由 |
|---|---|---|
| `build_sim` | Yes | 末尾が `_sim` |
| `test_sim` | Yes | 末尾が `_sim` |
| `build_run_sim` | Yes | 末尾が `_sim` |
| `boot_sim` | Yes | 末尾が `_sim` |
| `record_sim_video` | **No** | 末尾が `_video` |
| `start_sim_log_cap` | **No** | 末尾が `_log_cap` |
| `boot_simulator` | **No** | 末尾が `_simulator` |
| `sim_config` | **No** | `_sim` を含まない |
| `build_device` | **No** | `_sim` を含まない |

**QA テスト戦略 AC2a.5 (`record_sim_video`) と AC2a.6 (`start_sim_log_cap`) は「CLONE_REQUIRED に分類される」と期待しているが、`*_sim` glob ではマッチしない。** これらのテストは ALLOW（fail-open デフォルト）を期待値にすべき。

**対応案:**
- (A) テスト期待値を修正: `record_sim_video` と `start_sim_log_cap` → fail-open ALLOW（パターンにマッチしないため）
- (B) パターンを `*_sim*` に変更: `_sim` を含む全ツールをキャッチ。ただし `boot_simulator` もマッチする副作用あり
- (C) パターンを `*_sim|*_sim_*` に変更: 末尾 `_sim` と中間 `_sim_` の両方をキャッチ

**推奨: (A)。** fail-open 設計では、`record_sim_video` のようなツールが CLONE_REQUIRED に分類されなくても ALLOW になるだけで実害はない。パターンを複雑にする (B)(C) は保守性を下げる。`*_sim` の末尾一致のみというシンプルなルールを維持すべき。

もし `record_sim_video` が実際にシミュレーターとの対話を必要とするツールであれば、AC2b の個別指定リストに追加する方が明確。

### [x] CLONE_REQUIRED_IOS_SIM 11 ツールリストの完全性と新名称の正確性

**WARNING — 新ツール名の実在性が未検証。**

Plan が提示する 11 ツール:

| # | 新ツール名 | 推定される旧ツール名 |
|---|---|---|
| 1 | `ui_tap` | `tap` |
| 2 | `ui_swipe` | `swipe` |
| 3 | `ui_type` | `type_text` |
| 4 | `ui_describe_all` | `get_ui_hierarchy` |
| 5 | `ui_describe_point` | (新規?) |
| 6 | `ui_view` | (新規?) |
| 7 | `screenshot` | `take_screenshot` |
| 8 | `record_video` | `start_recording` |
| 9 | `install_app` | (旧名と同一?) |
| 10 | `launch_app` | (旧名と同一?) |
| 11 | `open_simulator` | `boot_simulator` |

**確認すべき点:**

1. これら 11 ツールは `ios-simulator-mcp` の最新バージョンで実際に存在するか？ → `npx ios-simulator-mcp --help` またはツールリスト取得で検証すべき
2. 旧名ツール（`tap`, `swipe`, `long_press` 等）は完全に廃止されたか？ → 旧名で MCP 呼び出しが成功しないことの確認
3. 新たに追加されたツール（`ui_describe_point`, `ui_view`）の挙動と UDID 注入の必要性

**現行コード（sim-pool-guard.sh L61-83）の ios-simulator ツール: 22 個。**
Plan の新リスト: 11 個（`get_booted_sim_id` と `stop_recording` 除外で 9 個 + 除外 2 個 = 11 個）。

22 個 → 11 個は大幅な削減。これが正しいなら、ios-simulator MCP サーバーの API が根本的にリデザインされたことになる。以下のツールが新リストから消えている:

- `terminate_app` — アプリ終了。UDID 注入不要になった?
- `long_press` — `ui_tap` に統合?
- `press_button` — 廃止?
- `open_url` — 廃止?
- `list_apps` — 廃止?
- `add_media` — 廃止?
- `set_location` — 廃止?
- `clear_keychain` — 廃止?
- `get_app_container` — 廃止?
- `push_notification` — 廃止?
- `set_permission` — 廃止?
- `uninstall_app` — 廃止?
- `shutdown_simulator` — `open_simulator` に統合?
- `erase_simulator` — 廃止?

**実装着手前に、ios-simulator MCP サーバーの最新ツールリストを取得して、この 11 ツールリストを検証することを強く推奨。** 誤ったツール名で CLONE_REQUIRED_IOS_SIM を定義すると、実際のツールが fail-open ALLOW になり UDID 注入が行われない。これは silent failure になる。

### [x] `main()` フローの全ルーティングパス

**PASS。** Plan の `main()` フロー:

```
DENY_TOOLS → session_id → persist → xcode_clone → ios_sim → ALLOW
```

全パスの検証:

| 入力 | 経路 | 結果 |
|------|------|------|
| `erase_sims`, session_id="" | DENY_TOOLS hit | DENY |
| `erase_sims`, session_id="s1" | DENY_TOOLS hit | DENY |
| `list_schemes`, session_id="" | DENY miss → session_id empty | ALLOW |
| `session_set_defaults`, persist:true, session_id="s1" | DENY miss → session_id ok → persist hit | DENY |
| `session_set_defaults`, persist:false, session_id="s1" | DENY miss → session_id ok → persist pass → xcode_clone hit | handle_xcodebuildmcp → ALLOW |
| `build_sim`, session_id="s1" | DENY miss → session_id ok → persist miss → xcode_clone hit | handle_xcodebuildmcp → DENY (guidance) or ALLOW |
| `ui_tap`, session_id="s1" | DENY miss → session_id ok → persist miss → xcode_clone miss → ios_sim hit | handle_ios_simulator → ALLOW with UDID |
| `list_schemes`, session_id="s1" | DENY miss → session_id ok → persist miss → xcode_clone miss → ios_sim miss | ALLOW (fail-open) |

全パスが正しくルーティングされる。`session_set_defaults` の persist check → clone_required の二段階処理も正常。

### [x] バージョンバンプの妥当性

**BLOCKER — 現在のバージョンが異なる。**

- Plan 記載: 1.3.0 → 1.4.0
- 実際の `plugin.json`: **1.4.0** (既にリリース済み)
- CHANGELOG.md: `[1.4.0] - 2026-04-12` が最新リリース

**正しい bump: 1.4.0 → 1.5.0 (MINOR)**

MINOR bump の理由は Plan と同じ — observable behavior change (unknown tools: DENY → ALLOW)。

## Additional Technical Observations

### O1: `handle_xcodebuildmcp` の `session_use_defaults_profile` 処理

現行コード（L331-335）:

```bash
if [ "$tool_name" = "mcp__XcodeBuildMCP__session_use_defaults_profile" ]; then
  rm -f "$setup_flag"
  emit_allow
  exit 0
fi
```

`session_use_defaults_profile` は `setup_flag` を **削除** する。これは「プロファイル切り替え後に再度 `session_set_defaults` を要求する」ための仕様。Plan の AC2b テスト（AC2b.4）の Note "resets setup_flag" はこの仕様を正しく理解している。問題なし。

### O2: `is_xcode_clone_required` と `PERSIST_CHECK_TOOLS` の交差

`session_set_defaults` と `session_use_defaults_profile` は `PERSIST_CHECK_TOOLS` と `is_xcode_clone_required` の両方に含まれる。`main()` のフローで persist check が先に実行されるため:

1. `persist:true` → DENY（persist check で exit）→ `is_xcode_clone_required` に到達しない
2. `persist:false` → persist check 通過 → `is_xcode_clone_required` でマッチ → `handle_xcodebuildmcp` 実行

この二段階は正常。ただし `handle_persist_check` は `exit 0` で終了する（L305）ため、persist:true の場合は確実に `is_xcode_clone_required` に到達しない。問題なし。

### O3: `set -u` 安全性の確認ポイント

READONLY_TOOLS 削除後に `set -u` でクラッシュする可能性がある箇所:

| 箇所 | コード | 影響 |
|------|------|------|
| L388 | `in_array "$tool_name" "${READONLY_TOOLS[@]}"` | **削除対象** — Step 1.1 で消す |
| L34-49 | `READONLY_TOOLS=(...)` | **削除対象** — Step 1.1 で消す |

CLONE_REQUIRED_TOOLS → CLONE_REQUIRED_IOS_SIM のリネームで影響を受ける箇所:

| 箇所 | コード | 影響 |
|------|------|------|
| L399 | `in_array "$tool_name" "${CLONE_REQUIRED_TOOLS[@]}"` | **リネーム対象** — Step 1.5 で更新 |

他に READONLY_TOOLS や CLONE_REQUIRED_TOOLS を参照する箇所はない（`grep` で確認済み）。

## Summary

| # | Severity | Item | Status | Action |
|---|----------|------|--------|--------|
| B1 | **BLOCKER** | バージョン番号: 1.3.0 → 1.4.0 は誤り | FAIL | 1.4.0 → 1.5.0 に修正 |
| B2 | **BLOCKER** | QA テスト AC2a.5, AC2a.6: `*_sim` は `record_sim_video`, `start_sim_log_cap` にマッチしない | FAIL | テスト期待値を ALLOW に修正、またはテスト削除 |
| W1 | **WARNING** | ios-simulator 新ツール名 11 個の実在性が未検証 | 要確認 | 実装着手前に `ios-simulator-mcp` のツールリストを取得して検証 |
| — | INFO | ファイル変更順序 | PASS | 依存関係に問題なし |
| — | INFO | `main()` フロー | PASS | 全ルーティングパス正常 |
| — | INFO | `case` glob `*_sim` パターン | PASS | 末尾一致でシンプル、forward-compatible |
| — | INFO | persist + clone_required の交差 | PASS | 二段階処理が正常に動作 |

**BLOCKER 2 件の修正後、実装着手可能。**
