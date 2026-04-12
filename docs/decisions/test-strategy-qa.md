# Test Strategy: QA

Issue #21: fix: sim-pool-guard.sh の allowlist を現行 XcodeBuildMCP / ios-simulator ツール名に同期する (fail-closed → fail-open)

## 1. AC ごとのテスト層選定

| AC | テスト層 | 理由 |
|----|---------|------|
| AC1: Fail-open デフォルト | 動的テスト (BATS/run_guard+jq) | 未登録ツール → ALLOW を実行時に検証。現行 fail-closed テスト（AC3.9-AC3.11）の反転版。 |
| AC2a: CLONE_REQUIRED `_sim` パターンマッチ | 動的テスト + 構造テスト | パターンマッチ実装の動的検証 + 境界ケース（`_sim` vs `_simulator` vs `_sim_`）の検証。 |
| AC2b: CLONE_REQUIRED 個別指定 | 動的テスト + 構造テスト | 4 ツール（screenshot, snapshot_ui, session_set_defaults, session_use_defaults_profile）の配列含有と動的ルーティングの検証。 |
| AC3: ios-simulator UDID 注入 | 動的テスト | 11 ツールの UDID 注入を検証。既存 `test_sim_auto_inject.bats` パターンの拡張。 |
| AC4: DENY erase_sims | 動的テスト | 単一ツールの DENY + メッセージ内容検証。 |
| AC5: DENY は session_id 判定より先 | 動的テスト | 空 session_id + erase_sims で DENY が返ることを検証。 |
| AC6: READONLY_TOOLS 廃止 + set -u | 構造テスト + 動的テスト | READONLY_TOOLS 参照がないことの静的検証 + 全ルーティングパスで unbound variable なしの動的検証。 |
| AC7: persist:true ブロック維持 | 既存テスト継続利用 | `test_sim_persist_block.bats` がそのままカバー。新規テスト不要。 |
| AC8: BATS テスト更新 | メタ検証 | `bats addons/ios/tests/` 全パスで判定。 |

## 2. 既存テスト影響分析（壊れるテストの特定）

### test_sim_failclosed_guard.bats (17 tests)

| テスト | 現在の期待値 | fail-open 後 | Action |
|--------|------------|-------------|--------|
| AC3.4-AC3.8: READONLY ツール ALLOW | ALLOW | ALLOW（fail-open 経由で同じ結果） | **書き換え**: コメント/テスト名を「fail-open default」に変更。`READONLY_TOOLS` 参照の文言を削除 |
| AC3.9: unknown XcodeBuildMCP → DENY | DENY | **ALLOW** | **反転書き換え**: `permissionDecision == "allow"` に変更 |
| AC3.10: unknown ios-simulator → DENY | DENY | **ALLOW** | **反転書き換え**: 同上 |
| AC3.11: DENY message includes tool name | DENY reason 検証 | **削除**: ALLOW なので reason なし | **削除** |
| AC3.12-AC3.13: session_set_defaults/profile in CLONE_REQUIRED | CLONE_REQUIRED 含有 | 変更なし | **維持** |
| AC3.14: no regex negative lookahead in addon.yml | 負パターンなし | **addon.yml に negative lookahead 追加予定** | **削除または反転**: Issue 本文では matcher 変更が記載されているが、承認済み AC には matcher 変更が含まれていない。実装判断次第。 |
| AC3.15: guard contains READONLY_TOOLS= | 存在確認 | **配列削除で FAIL** | **削除** |
| AC3.16: empty session_id → ALLOW | ALLOW | ALLOW（AC5 により DENY ツールは先に弾かれるが、非 DENY ツールは変わらず ALLOW） | **維持**（ただしテストで使用しているツール名 `mcp__XcodeBuildMCP__build` が CLONE_REQUIRED に残るか確認必要） |
| AC3.17: guard is executable | ファイル存在 | 変更なし | **維持** |

**Summary: 5 tests require rewrite, 2 tests require deletion, 10 tests maintained as-is or minor comment update.**

### test_sim_clone_required_variants.bats (12 tests)

| テスト | 影響 | Action |
|--------|------|--------|
| AC1.1-AC1.3: CLONE_REQUIRED contains build_sim/build_run_sim/test_sim | これらのツール名が `_sim` パターンマッチ経由で CLONE_REQUIRED に含まれるなら維持。ただし静的検証の手法（`sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p'`）はパターンマッチ実装では使えなくなる可能性あり | **書き換え**: パターンマッチ実装に合わせて動的テストに変更 |
| AC2.1-AC2.3: NOT in READONLY_TOOLS | READONLY_TOOLS 配列削除で FAIL | **削除** |
| AC3.1-AC3.3: first call DENY + guidance | 変更なし（CLONE_REQUIRED ルーティングは維持） | **維持** |
| AC4.1-AC4.3: ALLOW after session_set_defaults | 変更なし | **維持** |

**Summary: 3 tests require rewrite, 3 tests deleted, 6 tests maintained.**

### 影響なしのテストファイル

| テストファイル | テスト数 | 影響 | 理由 |
|--------------|---------|------|------|
| test_sim_auto_inject.bats | 6 | **低** | `mcp__XcodeBuildMCP__build` が CLONE_REQUIRED に残るか確認必要（Issue 本文では `build` は「`build_sim` にリネーム」とあるが、承認済み AC では個別ツールとしての `build` の扱いが不明確）。`mcp__ios-simulator__tap` は ios-simulator ツール名変更（`tap` → `ui_tap`）で FAIL する可能性あり。 |
| test_sim_ephemeral_clone.bats | 7 | **中** | `mcp__ios-simulator__tap` と `mcp__ios-simulator__take_screenshot` を使用。ツール名変更で FAIL する可能性。 |
| test_sim_golden_init.bats | 7 | **低** | `mcp__ios-simulator__tap` 使用。同上。 |
| test_sim_golden_set_fallback.bats | 13 | **低** | `mcp__ios-simulator__tap` 使用。同上。 |
| test_sim_init_guidance.bats | 4 | **なし** | addon.yml のドキュメント検証。guard ロジック非依存。 |
| test_sim_orphan_cleanup.bats | 9 | **低** | `mcp__ios-simulator__tap` 使用。同上。 |
| test_sim_persist_block.bats | 10 | **なし** | `session_set_defaults` と `session_use_defaults_profile` を使用。これらは AC2b で CLONE_REQUIRED に残る。 |
| test_sim_pool_docs.bats | 4 | **なし** | SKILL.md のドキュメント検証。 |

**Critical finding:** 既存テスト 6 ファイルが `mcp__ios-simulator__tap` を使用しているが、AC3 の承認済み AC では ios-simulator のツール名が `ui_tap` に変更されている。fail-open 後、旧名 `tap` は未登録扱いで ALLOW（UDID 注入なし）になるため、既存テストの UDID 注入検証が FAIL する。これらのテストは全て新ツール名に更新する必要がある。

## 3. 新規テストケース設計

### 3.1 test_sim_failopen_guard.bats (新規作成)

`test_sim_failclosed_guard.bats` を rename/rewrite して fail-open テストに変換。

```
# ── AC1: Fail-open デフォルト ──

@test "AC1.1: unknown XcodeBuildMCP tool gets immediate ALLOW"
  Input: tool_name="mcp__XcodeBuildMCP__unknown_future_tool", session_id="test-session"
  Expect: permissionDecision == "allow"

@test "AC1.2: unknown ios-simulator tool gets immediate ALLOW"
  Input: tool_name="mcp__ios-simulator__unknown_future_tool", session_id="test-session"
  Expect: permissionDecision == "allow"

@test "AC1.3: former READONLY tool (list_schemes) gets immediate ALLOW under fail-open"
  Input: tool_name="mcp__XcodeBuildMCP__list_schemes", session_id="test-session"
  Expect: permissionDecision == "allow"

@test "AC1.4: former READONLY tool (get_booted_sim_id) gets immediate ALLOW"
  Input: tool_name="mcp__ios-simulator__get_booted_sim_id", session_id="test-session"
  Expect: permissionDecision == "allow"

@test "AC1.5: non-sim XcodeBuildMCP tool (build_device) gets immediate ALLOW"
  Input: tool_name="mcp__XcodeBuildMCP__build_device", session_id="test-session"
  Expect: permissionDecision == "allow"

# ── AC4: DENY erase_sims ──

@test "AC4.1: erase_sims is DENY"
  Input: tool_name="mcp__XcodeBuildMCP__erase_sims", session_id="test-session"
  Expect: permissionDecision == "deny"

@test "AC4.2: erase_sims DENY reason mentions golden image protection"
  Input: same as AC4.1
  Expect: permissionDecisionReason contains "golden image protection"

@test "AC4.3: erase_sims DENY reason mentions Xcode"
  Input: same as AC4.1
  Expect: permissionDecisionReason contains "Xcode"

# ── AC5: DENY check before session_id check ──

@test "AC5.1: erase_sims with empty session_id is still DENY"
  Input: tool_name="mcp__XcodeBuildMCP__erase_sims", session_id=""
  Expect: permissionDecision == "deny" (NOT allow from empty session_id passthrough)

@test "AC5.2: non-DENY tool with empty session_id is ALLOW"
  Input: tool_name="mcp__XcodeBuildMCP__build_device", session_id=""
  Expect: permissionDecision == "allow"

# ── AC6: READONLY_TOOLS 廃止 + set -u ──

@test "AC6.1: guard script does NOT contain READONLY_TOOLS array"
  Method: ! grep -q 'READONLY_TOOLS=' "$GUARD"

@test "AC6.2: guard script does NOT reference READONLY_TOOLS[@]"
  Method: ! grep -q 'READONLY_TOOLS\[@\]' "$GUARD"

@test "AC6.3: no unbound variable error with CLONE_REQUIRED tool"
  Input: tool_name="mcp__XcodeBuildMCP__build_sim", session_id="test-session"
  Method: run_guard; check exit code == 0 (no set -u crash)
  Expect: valid JSON output

@test "AC6.4: no unbound variable error with unknown tool"
  Input: tool_name="mcp__XcodeBuildMCP__unknown_tool", session_id="test-session"
  Method: run_guard; check exit code == 0
  Expect: valid JSON output

# ── Regression: maintained behaviors ──

@test "REG.1: addon.yml hooks matcher catches XcodeBuildMCP tools"
  Method: grep -q 'mcp__XcodeBuildMCP__' addons/ios/addon.yml

@test "REG.2: addon.yml hooks matcher catches ios-simulator tools"
  Method: grep -q 'mcp__ios-simulator__' addons/ios/addon.yml

@test "REG.3: empty session_id for non-DENY tool passes through as ALLOW"
  Input: tool_name="mcp__XcodeBuildMCP__list_schemes", session_id=""
  Expect: permissionDecision == "allow"

@test "REG.4: guard script is executable"
  Method: [[ -f "$GUARD" ]]
```

**Total: 17 tests**

### 3.2 test_sim_pattern_match.bats (新規作成)

AC2a/AC2b のパターンマッチとルーティングに特化。

```
# ── AC2a: _sim パターンマッチ ──

@test "AC2a.1: boot_sim matches _sim pattern → CLONE_REQUIRED routing"
  Input: tool_name="mcp__XcodeBuildMCP__boot_sim", session_id="s-2a1"
  Expect: permissionDecision == "deny" (first call, guidance DENY)
  Verify: additionalContext contains "session_set_defaults"

@test "AC2a.2: build_sim matches _sim pattern"
  Input: tool_name="mcp__XcodeBuildMCP__build_sim", session_id="s-2a2"
  Expect: permissionDecision == "deny" (guidance)

@test "AC2a.3: test_sim matches _sim pattern"
  Input: tool_name="mcp__XcodeBuildMCP__test_sim", session_id="s-2a3"
  Expect: permissionDecision == "deny" (guidance)

@test "AC2a.4: install_app_sim matches _sim pattern"
  Input: tool_name="mcp__XcodeBuildMCP__install_app_sim", session_id="s-2a4"
  Expect: permissionDecision == "deny" (guidance)

@test "AC2a.5: record_sim_video matches _sim pattern (contains _sim_)"
  Input: tool_name="mcp__XcodeBuildMCP__record_sim_video", session_id="s-2a5"
  Expect: permissionDecision == "deny" (guidance)
  Note: _sim_ (with trailing chars) must also match

@test "AC2a.6: start_sim_log_cap matches _sim pattern"
  Input: tool_name="mcp__XcodeBuildMCP__start_sim_log_cap", session_id="s-2a6"
  Expect: permissionDecision == "deny" (guidance)

@test "AC2a.7: _sim suffix ALLOW after session_set_defaults"
  Input: sequence with session_id="s-2a7":
    1. run_guard build_sim → DENY (creates clone + setup_flag)
    2. run_guard session_set_defaults → ALLOW
    3. run_guard build_sim → ALLOW
  Expect: step 3 permissionDecision == "allow"

# ── AC2a: 境界テスト — パターンの精度 ──

@test "AC2a.EDGE.1: tool ending in _simulator does NOT match _sim pattern (fail-open ALLOW)"
  Input: tool_name="mcp__XcodeBuildMCP__boot_simulator", session_id="s-edge1"
  Expect: permissionDecision == "allow" (fail-open, not CLONE_REQUIRED)
  Note: _simulator contains _sim but is NOT a valid _sim pattern tool. If implementation
        uses *_sim* glob, this WOULD match. If using _sim$ or _sim[^u], it would not.
        This test documents the boundary and verifies the actual behavior.

@test "AC2a.EDGE.2: tool name 'sim_something' without _sim suffix/infix → fail-open ALLOW"
  Input: tool_name="mcp__XcodeBuildMCP__sim_config", session_id="s-edge2"
  Expect: permissionDecision == "allow"
  Note: _sim must appear after the tool's action verb, not as prefix

# ── AC2b: 個別指定ツール ──

@test "AC2b.1: screenshot is CLONE_REQUIRED (not _sim pattern)"
  Input: tool_name="mcp__XcodeBuildMCP__screenshot", session_id="s-2b1"
  Expect: permissionDecision == "deny" (guidance)

@test "AC2b.2: snapshot_ui is CLONE_REQUIRED"
  Input: tool_name="mcp__XcodeBuildMCP__snapshot_ui", session_id="s-2b2"
  Expect: permissionDecision == "deny" (guidance)

@test "AC2b.3: session_set_defaults is CLONE_REQUIRED and ALLOWed"
  Input: tool_name="mcp__XcodeBuildMCP__session_set_defaults",
         tool_input={"simulatorName":"clone","persist":false}, session_id="s-2b3"
  Expect: permissionDecision == "allow"

@test "AC2b.4: session_use_defaults_profile is CLONE_REQUIRED"
  Input: tool_name="mcp__XcodeBuildMCP__session_use_defaults_profile",
         tool_input={"profile":"default","persist":false}, session_id="s-2b4"
  Expect: permissionDecision == "allow" (resets setup_flag)

# ── AC2a/2b: clone 作成失敗 ──

@test "AC2a.FAIL.1: clone creation failure returns DENY"
  Setup: mock xcrun clone returns exit code 1
  Input: tool_name="mcp__XcodeBuildMCP__build_sim", session_id="s-fail1"
  Expect: permissionDecision == "deny"
  Expect: reason contains "Failed to create simulator clone"

@test "AC2b.FAIL.1: clone creation failure for screenshot returns DENY"
  Setup: mock xcrun clone returns exit code 1
  Input: tool_name="mcp__XcodeBuildMCP__screenshot", session_id="s-fail2"
  Expect: permissionDecision == "deny"
```

**Total: 15 tests**

### 3.3 test_sim_auto_inject.bats (更新)

既存テストのツール名を新 ios-simulator 名に更新 + AC3 の新ツール検証を追加。

```
# ── 既存テスト更新 ──

変更点:
- "mcp__ios-simulator__tap" → "mcp__ios-simulator__ui_tap"
- "mcp__ios-simulator__take_screenshot" → "mcp__ios-simulator__screenshot" (ephemeral clone test)
- tool_input の x/y フィールドは ios-simulator 新 API に合わせて更新

# ── AC3: ios-simulator UDID 注入（新規追加分） ──

@test "AC3.1: ui_tap gets clone UDID injected"
  Input: tool_name="mcp__ios-simulator__ui_tap", tool_input={"x":100,"y":200}
  Expect: permissionDecision == "allow", updatedInput.udid == "CLONE-UUID-5678"

@test "AC3.2: ui_swipe gets clone UDID injected"
  Input: tool_name="mcp__ios-simulator__ui_swipe", tool_input={"fromX":0,"fromY":0,"toX":100,"toY":100}
  Expect: updatedInput.udid == "CLONE-UUID-5678"

@test "AC3.3: install_app gets clone UDID injected"
  Input: tool_name="mcp__ios-simulator__install_app", tool_input={"path":"/tmp/app"}
  Expect: updatedInput.udid == "CLONE-UUID-5678"

@test "AC3.4: ui_describe_all gets clone UDID injected"
  Input: tool_name="mcp__ios-simulator__ui_describe_all", tool_input={}
  Expect: updatedInput.udid == "CLONE-UUID-5678"

@test "AC3.5: get_booted_sim_id is NOT CLONE_REQUIRED (fail-open ALLOW, no UDID injection)"
  Input: tool_name="mcp__ios-simulator__get_booted_sim_id"
  Expect: permissionDecision == "allow", NO updatedInput field

@test "AC3.6: stop_recording is NOT CLONE_REQUIRED (fail-open ALLOW, no UDID injection)"
  Input: tool_name="mcp__ios-simulator__stop_recording"
  Expect: permissionDecision == "allow", NO updatedInput field

@test "AC3.7: original tool_input fields preserved after UDID injection"
  Input: tool_name="mcp__ios-simulator__ui_tap", tool_input={"x":100,"y":200}
  Expect: updatedInput.x == 100, updatedInput.y == 200, updatedInput.udid == "CLONE-UUID-5678"

@test "AC3.8: existing udid in tool_input is overwritten with clone UDID"
  Input: tool_name="mcp__ios-simulator__ui_tap", tool_input={"udid":"user-provided","x":50}
  Expect: updatedInput.udid == "CLONE-UUID-5678" (overwritten)

@test "AC3.FAIL.1: clone failure for ios-simulator tool returns DENY"
  Setup: mock xcrun clone returns exit code 1
  Input: tool_name="mcp__ios-simulator__ui_tap"
  Expect: permissionDecision == "deny"
```

**Total: 9 new + 6 updated = 15 tests**

### 3.4 既存テストファイルのツール名更新

以下のファイルで `mcp__ios-simulator__tap` → `mcp__ios-simulator__ui_tap` および `mcp__ios-simulator__take_screenshot` → `mcp__ios-simulator__screenshot` の一括置換が必要:

| ファイル | 置換箇所数 | 他の変更 |
|---------|-----------|---------|
| test_sim_ephemeral_clone.bats | 4 | `take_screenshot` → `screenshot` |
| test_sim_golden_init.bats | 1 | |
| test_sim_golden_set_fallback.bats | 5 | |
| test_sim_orphan_cleanup.bats | 1 | |

## 4. テストケース全体サマリ

### 新規テスト

| ファイル | AC | テスト数 | 内容 |
|---------|-----|---------|------|
| test_sim_failopen_guard.bats | AC1, AC4, AC5, AC6 | 17 | fail-open デフォルト、DENY、session_id 順序、READONLY 廃止 |
| test_sim_pattern_match.bats | AC2a, AC2b | 15 | `_sim` パターン、個別指定、境界ケース、clone 失敗 |
| test_sim_auto_inject.bats (追加分) | AC3 | 9 | ios-simulator UDID 注入、除外ツール、clone 失敗 |

### 更新テスト

| ファイル | 変更内容 | 影響テスト数 |
|---------|---------|------------|
| test_sim_failclosed_guard.bats → test_sim_failopen_guard.bats | rename + rewrite | 17 (全面書き換え) |
| test_sim_clone_required_variants.bats | READONLY 参照削除、静的テスト → 動的テスト | 6 (AC1, AC2 の 6 テスト書き換え) |
| test_sim_auto_inject.bats | ツール名更新 + 新テスト追加 | 6 (更新) + 9 (追加) |
| test_sim_ephemeral_clone.bats | ツール名更新 | 4 |
| test_sim_golden_init.bats | ツール名更新 | 1 |
| test_sim_golden_set_fallback.bats | ツール名更新 | 5 |
| test_sim_orphan_cleanup.bats | ツール名更新 | 1 |

### 影響なし（そのまま維持）

| ファイル | テスト数 |
|---------|---------|
| test_sim_init_guidance.bats | 4 |
| test_sim_persist_block.bats | 10 |
| test_sim_pool_docs.bats | 4 |

## 5. Edge Case テスト設計

### 5.1 空 session_id + DENY ツール

**AC5 でカバー。** 以下の 2 テストで検証:

```
@test "AC5.1: erase_sims with empty session_id is still DENY"
  Purpose: DENY チェックが session_id パススルーより先に実行されることを検証
  Input: {"tool_name":"mcp__XcodeBuildMCP__erase_sims","tool_input":{},"session_id":""}
  Current behavior: ALLOW (session_id 空 → 即 ALLOW at L382-385)
  Expected behavior: DENY (AC5 の要件)
  Implementation note: main() で DENY_TOOLS チェックを session_id 空チェックより上に移動

@test "AC5.2: non-DENY tool with empty session_id is still ALLOW"
  Purpose: DENY 以外のツールは従来通り空 session_id で ALLOW されることを検証
  Input: {"tool_name":"mcp__XcodeBuildMCP__build_device","tool_input":{},"session_id":""}
  Expected: ALLOW
```

### 5.2 Clone 作成失敗

**AC2a.FAIL.1, AC2b.FAIL.1, AC3.FAIL.1 でカバー。** 特殊な mock setup が必要:

```bash
# clone 失敗用 mock: xcrun simctl clone → exit 1
create_failing_clone_mock() {
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) exit 1 ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
}
```

3 テストで共通利用。各テストの `setup` の後に `create_failing_clone_mock` を呼ぶ、または専用テストブロックで setup を上書きする。

### 5.3 パターン境界: `_sim` の精度

**AC2a.EDGE.1, AC2a.EDGE.2 でカバー。**

| テスト入力 | `_sim` パターンマッチ | 期待される分類 |
|-----------|---------------------|--------------|
| `boot_sim` | 末尾 `_sim` → マッチ | CLONE_REQUIRED |
| `build_sim` | 末尾 `_sim` → マッチ | CLONE_REQUIRED |
| `record_sim_video` | 中間 `_sim_` → マッチ | CLONE_REQUIRED |
| `start_sim_log_cap` | 中間 `_sim_` → マッチ | CLONE_REQUIRED |
| `boot_simulator` | `_sim` を含むが `_simulator` → 実装依存 | **境界ケース** |
| `sim_config` | 先頭 `sim_` → 非マッチ | fail-open ALLOW |
| `build_device` | `_sim` なし → 非マッチ | fail-open ALLOW |

**Implementation note:** パターンマッチの実装方法によって `boot_simulator` の扱いが変わる:
- `*_sim*` (glob): `_simulator` もマッチ → CLONE_REQUIRED
- `*_sim` (末尾のみ): `_simulator` はマッチしない → fail-open ALLOW
- `*_sim[^a-z]*|*_sim` (末尾 or 後に非英字): `_sim_video` はマッチ、`_simulator` はマッチしない

テスト AC2a.EDGE.1 は実装後の実際の挙動を文書化する役割を持つ。実装者が選択したパターンに合わせて期待値を設定する。

### 5.4 DENY_TOOLS 配列の静的検証

```
@test "DENY_TOOLS contains erase_sims"
  Method: grep -q '"mcp__XcodeBuildMCP__erase_sims"' <(
    sed -n '/^DENY_TOOLS=/,/^)/p' "$GUARD"  # or DENY_TOOLS の実装形態に応じて
  )

@test "DENY_TOOLS has exactly 1 entry"
  Method: count entries in DENY_TOOLS array
  Purpose: 意図しないツールが DENY に追加されていないことを検証
```

## 6. テスト実行戦略

### 実行順序

```
Phase 1: 構造テスト（高速、環境非依存）
  - AC6 の READONLY_TOOLS 非存在検証
  - DENY_TOOLS 配列検証
  - addon.yml matcher 検証

Phase 2: 動的テスト（mock 環境必要）
  - AC1 fail-open テスト
  - AC2a/2b パターンマッチテスト
  - AC3 UDID 注入テスト
  - AC4 DENY テスト
  - AC5 session_id 順序テスト

Phase 3: 回帰テスト（全既存テスト）
  - bats addons/ios/tests/
```

### CI 実行

```bash
bats addons/ios/tests/ --formatter tap
```

全テストファイルを一括実行。BATS の `setup`/`teardown` がテスト間の分離を保証。

### テスト数の見込み

| カテゴリ | テスト数 |
|---------|---------|
| 新規テスト | 41 |
| 更新テスト（書き換え + ツール名更新） | 23 |
| 維持テスト | 18 + 残りの既存テスト |
| **全テスト合計（見込み）** | **約 85-90** |

## 7. setup/teardown 設計

### 標準 setup（全動的テストファイル共通）

```bash
setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"
  touch "$SIM_MARKER_DIR/golden-initialized-iOS-18-0"

  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) echo "CLONE-UUID-5678" ;;
  simctl\ boot\ *|simctl\ shutdown\ *|simctl\ bootstatus\ *) ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  simctl\ delete\ *) ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  export PATH="$MOCK_BIN:$PATH"
}
```

### clone 失敗用 setup（AC2a.FAIL, AC2b.FAIL, AC3.FAIL 専用）

個別テスト内で mock を差し替える:

```bash
@test "AC2a.FAIL.1: clone creation failure returns DENY" {
  # Override mock to fail on clone
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) exit 1 ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}' "s-fail1")
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
}
```

### run_guard ヘルパー（全ファイル共通パターン）

```bash
run_guard() {
  local tool_name="$1"
  local tool_input="${2:-\{\}}"
  local session_id="${3:-test-session-default}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}
```

## 8. リスクと注意事項

### リスク 1: パターンマッチ実装のバリエーション

AC2a の `_sim` パターンマッチは実装方法によりカバレッジが変わる。テストは「期待される分類結果」で書くが、パターン実装の選択後に境界テスト（AC2a.EDGE.1, AC2a.EDGE.2）の期待値を調整する必要がある。

**Mitigation:** 実装者が選択したパターンをテストコメントに明記し、境界テストの期待値を合わせる。

### リスク 2: ios-simulator ツール名の変更範囲

Issue 本文のツール名変更リストと承認済み AC のツール名が一致するか確認が必要。特に:
- `tap` → `ui_tap` は承認済み AC に明記
- `take_screenshot` → `screenshot` は承認済み AC に明記
- `get_booted_simulators` → `get_booted_sim_id` は承認済み AC に明記
- その他の旧ツール名（`long_press`, `type_text`, `press_button` 等）は廃止

**Mitigation:** テストでは承認済み AC に明記された 11 + 2 ツール名のみ使用する。

### リスク 3: addon.yml matcher の変更

Issue 本文では addon.yml に negative lookahead を追加する記載があるが、承認済み AC にはこの変更が含まれていない。matcher 変更の有無で以下が変わる:
- matcher 変更あり: 旧 READONLY ツールは guard に到達しない → テスト不要
- matcher 変更なし: 旧 READONLY ツールは guard に到達し fail-open ALLOW → AC1 でテスト

**Mitigation:** AC1 のテスト（旧 READONLY ツールの ALLOW 検証）を含めておく。matcher 変更があっても guard 単体テストとしては有効。

### リスク 4: `mcp__XcodeBuildMCP__build` の扱い

現行コードでは `build` (suffix なし) が CLONE_REQUIRED。Issue 本文では `build` → `build_sim` にリネームと記載。しかし承認済み AC では `build` の扱いが不明確。

- `build` が CLONE_REQUIRED に残る場合: 既存テストの `mcp__XcodeBuildMCP__build` は維持可能
- `build` が除外される場合: fail-open ALLOW になり、既存テスト（test_sim_auto_inject.bats AC5.1-AC5.2）が FAIL

**Mitigation:** `build` は `_sim` パターンに該当しないため、AC2b の個別指定に含まれていなければ fail-open ALLOW になる。承認済み AC2b では `screenshot`, `snapshot_ui`, `session_set_defaults`, `session_use_defaults_profile` の 4 つのみ。`build` は含まれていないため fail-open ALLOW が正しい動作。既存テストは更新が必要。
