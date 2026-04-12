# AC Review: Developer Perspective

**Issue:** #21 — fix: sim-pool-guard.sh の allowlist を現行 XcodeBuildMCP / ios-simulator ツール名に同期する
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Assessment

Fail-closed から fail-open への設計変更は、ガードの保守負担を根本的に解決する正しいアプローチである。現行の fail-closed 設計では MCP サーバーにツールが追加されるたびに allowlist 更新が必要で、未知ツールが一律 DENY されるため UX が悪化する。fail-open にすることで、明示的に管理が必要なツール（sim 操作・破壊操作）のみをリストし、それ以外は素通りさせる。

ただし、AC2 の 37 ツール列挙は保守性に課題があり、パターンマッチングへの移行を強く推奨する。また、debug ツール群の sim 限定性に関する懸念がある。

**Verdict: CONDITIONAL PASS** — AC2 のツールリスト管理方式について修正が必要（詳細は下記 M1）。

## Per-AC Feedback

### AC1: Fail-open default — PASS

**技術的妥当性:** 高い。現行コードの `main()` 関数（370-416行目）では、READONLY -> PERSIST_CHECK -> CLONE_REQUIRED -> DENY（unknown）の順で処理している。fail-open への変更は、最終段の DENY を ALLOW に書き換えるだけで実現可能。

**アーキテクチャ整合性:** fail-open はフックの設計意図と合致する。`addon.yml` の hook matcher（24-29行目）は `mcp__XcodeBuildMCP__.*` と `mcp__ios-simulator__.*` で全ツールを捕捉しているが、これは「ガードを通過させる」ためであり「全ツールを制限する」ためではない。fail-open にすることで matcher の意味がより明確になる。

**実装の簡潔さ:** `main()` の最終分岐（412行目）を `emit_deny` から `emit_allow` に変更し、READONLY_TOOLS 配列を削除するだけ。READONLY_TOOLS に含まれていたツールは fail-open のデフォルトパスで自動的に ALLOW される。

### AC2: CLONE_REQUIRED — XcodeBuildMCP 37 tools — CONDITIONAL PASS

**技術的妥当性:** ロジックは正しい。clone 確保 -> session_set_defaults ガイダンス -> ALLOW のフローは現行の `handle_xcodebuildmcp`（308-347行目）がそのまま使える。

**重大な懸念 — 37 ツール列挙の保守性:**

現行の CLONE_REQUIRED_TOOLS は 6 個の XcodeBuildMCP ツール（53-60行目）と 21 個の ios-simulator ツール（61-83行目）。AC2 はこれを XcodeBuildMCP だけで 37 個に拡大する。

問題点:
1. XcodeBuildMCP の更新で新しい `*_sim` ツールが追加されるたびに allowlist 漏れが再発する（Issue #21 と同じ問題）
2. 37 個のツール名を手動管理するのはエラーが起きやすい
3. AC の記述で「12 tools, 9 tools, 8 tools, 4 tools, 2 tools, screenshot, snapshot_ui」と内訳を示しているが、実装時にカウントミスが生じやすい

**推奨（M1 参照）:** パターンマッチングで sim 操作ツールを捕捉する方式に変更すべき。

**debug ツール群の sim 限定性への懸念:**

AC2 が含める debug ツール（`debug_breakpoint_add`, `debug_continue`, `debug_step_over`, `debug_step_into`, `debug_step_out`, `debug_pause`, `debug_print_variable`, `debug_evaluate_expression`）はツール名に `_sim` を含まない。これらは:
- macOS アプリのデバッグにも使用される可能性がある
- Xcode の LLDB 連携であれば、sim/device/macOS を問わず動作する

これらを CLONE_REQUIRED に含めると、macOS ターゲットのデバッグ時に不要なクローン作成が発生する。**ただし fail-open 設計であれば、リストに含めなくても ALLOW になる。** debug ツールを CLONE_REQUIRED から除外し、fail-open のデフォルトで通す方が安全。

### AC3: CLONE_REQUIRED — ios-simulator 11 tools — PASS

**技術的妥当性:** 高い。現行の CLONE_REQUIRED_TOOLS（61-83行目）には既に 21 個の ios-simulator ツールが含まれている。`get_booted_simulators`（現: `get_booted_sim_id`）と `stop_recording` を除外する設計は正しい — これらは UDID 注入が不要か、既に進行中の録画を止めるだけで副作用がない。

**UDID 注入の実装:** `handle_ios_simulator`（349-366行目）の `jq --arg udid "$clone_udid" '. + {udid: $udid}'` がそのまま使える。変更不要。

**エッジケース確認済み:**
- `get_booted_sim_id`（旧 `get_booted_simulators`）: ツール名変更が必要。fail-open なので名前が変わっても ALLOW される。問題なし。
- `stop_recording`: 録画中の sim の UDID を必要とするが、録画開始時に注入済み。fail-open で通しても問題ない。

### AC4: DENY — erase_sims — PASS

**技術的妥当性:** 高い。新しい DENY_TOOLS 配列を追加し、`main()` の早期段階でチェックするだけ。

**実装:**
```bash
DENY_TOOLS=(
  "mcp__XcodeBuildMCP__erase_sims"
)
```

`main()` のフローに DENY_TOOLS チェックを CLONE_REQUIRED の前に挿入:
```bash
# DENY_TOOLS — unconditional DENY
if in_array "$tool_name" "${DENY_TOOLS[@]}"; then
  emit_deny "sim-pool: '${tool_name}' is denied to protect the golden image."
  exit 0
fi
```

**ゴールデンイメージ保護の妥当性:** `erase_sims` は全シミュレーターを消去するため、ゴールデンイメージも破壊される。DENY は正しい判断。

### AC5: READONLY_TOOLS 削除 + set -u 安全性 — PASS

**技術的妥当性:** 高い。現行コードは `set -euo pipefail`（18行目）で `set -u`（未定義変数エラー）が有効。

**潜在的な問題箇所:**
- `in_array "$tool_name" "${READONLY_TOOLS[@]}"` — READONLY_TOOLS 配列を削除すると、この参照で `unbound variable` エラーが発生する
- 解決策: READONLY_TOOLS を参照するコードも同時に削除する（fail-open では不要）

**PERSIST_CHECK_TOOLS への影響:** PERSIST_CHECK_TOOLS（86-89行目）は残す必要がある。`session_set_defaults` と `session_use_defaults_profile` の persist チェックは fail-open でも必要。`set -u` との互換性は現状維持で問題なし（配列は空ではない）。

**テスト実装の注意:** `test_sim_failclosed_guard.bats` の AC3.15（154行目）は `READONLY_TOOLS=` の存在を確認するテスト。このテストは削除が必要。

### AC6: persist:true ブロック維持 — PASS

**技術的妥当性:** 変更なし。`handle_persist_check`（298-306行目）と `PERSIST_CHECK_TOOLS`（86-89行目）はそのまま残す。

**フロー確認:** `main()` の PERSIST_CHECK（394-396行目）は CLONE_REQUIRED チェック（399行目）の前に実行される。fail-open でもこの順序は維持される。persist:true の `session_set_defaults` は PERSIST_CHECK で DENY され、CLONE_REQUIRED まで到達しない。正常。

### AC7: BATS テスト更新 — PASS

**技術的妥当性:** 高い。以下のテストファイルに影響:

| テストファイル | 影響 | 必要な変更 |
|---|---|---|
| `test_sim_failclosed_guard.bats` | **大幅書き換え** | AC3.9-3.11（unknown tool DENY）→ unknown tool ALLOW に変更。AC3.15（READONLY_TOOLS 存在確認）→ 削除。ファイル名も `test_sim_failopen_guard.bats` に変更推奨 |
| `test_sim_clone_required_variants.bats` | **軽微** | AC2（READONLY_TOOLS 不在確認）→ 削除（READONLY_TOOLS 自体がない） |
| `test_sim_auto_inject.bats` | **変更なし** | ios-simulator の UDID 注入ロジックは変更なし |
| `test_sim_ephemeral_clone.bats` | **変更なし** | クローンライフサイクルは変更なし |
| `test_sim_persist_block.bats` | **変更なし** | persist チェックは維持 |
| `test_sim_golden_*.bats` | **変更なし** | ゴールデンイメージ管理は変更なし |
| `test_sim_orphan_cleanup.bats` | **変更なし** | クリーンアップロジックは変更なし |
| `test_sim_pool_docs.bats` | **軽微** | ドキュメント更新に追従 |
| `test_sim_init_guidance.bats` | **変更なし** | addon.yml guidance は変更なし |

**新規テストの追加:**
- fail-open デフォルト ALLOW テスト（unknown tool → ALLOW）
- DENY_TOOLS テスト（`erase_sims` → DENY with golden image protection reason）
- 新規 CLONE_REQUIRED ツールのテスト（追加されたツール群の経路確認）

## Suggested Modifications

### M1: パターンマッチングによる CLONE_REQUIRED 管理（重要）

37 ツールの個別列挙ではなく、パターンマッチングを推奨する。

**提案するアプローチ:**

```bash
# XcodeBuildMCP sim-interacting tools: pattern-based matching
is_xcode_clone_required() {
  local tool="$1"
  case "$tool" in
    mcp__XcodeBuildMCP__*_sim)       return 0 ;;  # *_sim variants (12 tools)
    mcp__XcodeBuildMCP__session_set_defaults) return 0 ;;
    mcp__XcodeBuildMCP__session_use_defaults_profile) return 0 ;;
    mcp__XcodeBuildMCP__screenshot)  return 0 ;;
    mcp__XcodeBuildMCP__snapshot_ui) return 0 ;;
    *)                               return 1 ;;
  esac
}
```

**利点:**
- `*_sim` パターンで将来の `*_sim` ツール追加を自動捕捉
- UI 操作ツール（`tap_sim`, `swipe_sim` 等）も `*_sim` パターンでカバー
- 個別列挙が必要なのは `session_set_defaults`, `session_use_defaults_profile`, `screenshot`, `snapshot_ui` の 4 つだけ
- debug ツールは含めない（fail-open で ALLOW）

**ios-simulator は引き続き配列管理:** ios-simulator のツール数は 11 個で安定しており、全ツールに UDID 注入が必要なため、パターンマッチングのメリットが薄い。配列管理を維持。

### M2: debug ツールは CLONE_REQUIRED から除外すべき

debug ツール群（8 個）はツール名に `_sim` を含まず、macOS ターゲットでも使用される可能性がある。fail-open 設計であれば CLONE_REQUIRED に含めなくても ALLOW になる。

**除外すべきツール:**
- `debug_breakpoint_add`, `debug_continue`, `debug_step_over`, `debug_step_into`
- `debug_step_out`, `debug_pause`, `debug_print_variable`, `debug_evaluate_expression`

**理由:** これらを CLONE_REQUIRED に含めると、macOS アプリのデバッグ時にも不要な simulator clone が作成される。debug セッションがどのターゲット向けかはガードスクリプトからは判別できない。fail-open で通すのが最も安全。

### M3: AC2 の記述を分割

AC2 は 37 ツールを一つの AC にまとめているが、実際には以下の 2 つの異なるメカニズムが含まれる:
1. `*_sim` パターンで捕捉されるツール群（パターンマッチ）
2. `screenshot`, `snapshot_ui`, `session_*` の個別指定ツール（明示リスト）

これらを分離すると、テスト設計が明確になる:
- AC2a: `*_sim` パターンマッチのテスト（代表ツールで確認）
- AC2b: 個別指定ツールのテスト（全ツール確認）

## Edge Cases Identified

### E1: XcodeBuildMCP ツール名変更への耐性

M1 のパターンマッチング採用で `*_sim` ツールは自動追従する。ただし `screenshot` や `snapshot_ui` が名前変更された場合、fail-open で ALLOW になるだけで DENY にはならない。シミュレーター操作なしの screenshot 取得は破壊的ではないため、リスクは許容可能。

### E2: ios-simulator の `get_booted_sim_id` vs `get_booted_simulators`

現行コード（47行目）では `get_booted_simulators` が READONLY_TOOLS に含まれている。AC3 では `get_booted_sim_id` を除外対象として記述。ツール名が変更されている可能性がある。fail-open ではどちらの名前でも ALLOW になるため、実害はない。ただし CLONE_REQUIRED リストとの整合性確認は必要。

### E3: 新 MCP サーバー追加時

`addon.yml` の hook matcher は `mcp__XcodeBuildMCP__.*` と `mcp__ios-simulator__.*` のみ。将来 `xcode` MCP サーバー（addon.yml 19-20行目に定義済み）や `apple-docs`（15-17行目）のツールが追加されても、matcher に引っかからないためガードを通過しない（そもそもガードが起動しない）。fail-open/fail-closed に関わらず、これらは影響外。問題なし。

## Implementation Complexity Estimate

| File | Change | Complexity |
|---|---|---|
| `sim-pool-guard.sh` | READONLY_TOOLS 削除、DENY_TOOLS 追加、CLONE_REQUIRED 更新（パターンマッチ化）、main() 最終分岐を ALLOW に | Medium — ロジック変更あり |
| `test_sim_failclosed_guard.bats` | fail-open 用に大幅書き換え → `test_sim_failopen_guard.bats` | Medium |
| `test_sim_clone_required_variants.bats` | READONLY_TOOLS 参照削除、新ツールのテスト追加 | Low |
| 新規: DENY_TOOLS テスト | `erase_sims` の DENY テスト | Low |
| その他テスト | 軽微な修正 | Minimal |

**Total: 中規模。** ロジック変更は限定的だが、テストの書き換え量が多い。
