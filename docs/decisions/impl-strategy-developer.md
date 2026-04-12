# Implementation Strategy: Issue #21

**Issue:** #21 — fix: sim-pool-guard.sh の allowlist を fail-closed → fail-open に設計転換
**Author:** Developer Agent
**Date:** 2026-04-12
**Prior Decision:** `docs/decisions/ac-review-developer.md`

## 1. File Structure and Modification Map

### Modified Files

| # | File | Nature of Change |
|---|------|------------------|
| F1 | `addons/ios/scripts/sim-pool-guard.sh` | Core logic rewrite: remove READONLY_TOOLS, add DENY_TOOLS, add `is_xcode_clone_required()`, rename CLONE_REQUIRED_TOOLS to CLONE_REQUIRED_IOS_SIM, rewrite `main()` flow |
| F2 | `addons/ios/tests/test_sim_failclosed_guard.bats` | **Delete** — replaced by F3 |
| F3 | `addons/ios/tests/test_sim_failopen_guard.bats` | **New file** — fail-open ALLOW, DENY_TOOLS, pattern match, addon.yml matchers |
| F4 | `addons/ios/tests/test_sim_clone_required_variants.bats` | Remove READONLY_TOOLS negative tests; update array name to CLONE_REQUIRED_IOS_SIM; add `*_sim` pattern match tests |
| F5 | `addons/ios/tests/test_sim_persist_block.bats` | Update static grep to match new array location if line numbers shift |
| F6 | `CHANGELOG.md` | Add entry under `[Unreleased]` |
| F7 | `.claude-plugin/plugin.json` | Version bump |

### Unchanged Files (verify-only)

| File | Reason |
|------|--------|
| `addons/ios/addon.yml` | Hook matchers already catch all tools; no change needed |
| `addons/ios/tests/test_sim_auto_inject.bats` | UDID injection logic untouched |
| `addons/ios/tests/test_sim_ephemeral_clone.bats` | Clone lifecycle untouched |
| `addons/ios/tests/test_sim_golden_init.bats` | Golden init logic untouched |
| `addons/ios/tests/test_sim_golden_set_fallback.bats` | Golden set logic untouched |
| `addons/ios/tests/test_sim_orphan_cleanup.bats` | Cleanup logic untouched |
| `addons/ios/tests/test_sim_pool_docs.bats` | Doc content tests |
| `addons/ios/tests/test_sim_init_guidance.bats` | addon.yml guidance tests |

## 2. Implementation Sequence

Ordered by dependency. Each step depends on the prior step being complete.

### Phase 1: Guard Script Core (F1 — sim-pool-guard.sh)

#### Step 1.1 — Remove READONLY_TOOLS array and references (AC6)

Remove lines 33-49 (`READONLY_TOOLS` array) and lines 387-390 (`in_array READONLY_TOOLS` check in `main()`).

This is the prerequisite for all other changes — removing dead code first prevents merge conflicts.

**Verification:** `bash -n sim-pool-guard.sh` passes (syntax check). `set -u` does not trigger on removed references.

#### Step 1.2 — Add DENY_TOOLS array and check (AC4, AC5)

Add new array after `PERSIST_CHECK_TOOLS`:

```bash
# Unconditionally denied — golden image destruction risk
DENY_TOOLS=(
  "mcp__XcodeBuildMCP__erase_sims"
)
```

Add DENY check in `main()` as the **first check**, before the `session_id` early-return:

```bash
# 1. DENY_TOOLS — unconditional DENY (AC4, AC5: before session_id check)
if in_array "$tool_name" "${DENY_TOOLS[@]}"; then
  emit_deny "sim-pool: '${tool_name}' is denied to protect the golden image."
  exit 0
fi
```

**Ordering rationale (AC5):** DENY must fire even when `session_id` is empty. The current code returns early with ALLOW when `session_id` is empty (line 383). Placing DENY before session_id ensures `erase_sims` is blocked regardless of session context.

#### Step 1.3 — Add `is_xcode_clone_required()` pattern matcher (AC2a, AC2b)

Replace the XcodeBuildMCP entries in `CLONE_REQUIRED_TOOLS` with a function:

```bash
# XcodeBuildMCP clone-required: pattern match + explicit list
is_xcode_clone_required() {
  local tool="$1"
  case "$tool" in
    mcp__XcodeBuildMCP__*_sim)                        return 0 ;;
    mcp__XcodeBuildMCP__screenshot)                   return 0 ;;
    mcp__XcodeBuildMCP__snapshot_ui)                   return 0 ;;
    mcp__XcodeBuildMCP__session_set_defaults)          return 0 ;;
    mcp__XcodeBuildMCP__session_use_defaults_profile)  return 0 ;;
    *)                                                 return 1 ;;
  esac
}
```

**Why `case` with glob:**
- `case` glob patterns are POSIX-compatible and work under `set -euo pipefail`
- `*_sim` matches any tool name ending in `_sim` — exactly the pattern we need
- Zero subprocess overhead (shell built-in)
- Forward-compatible: any future `*_sim` tool is captured automatically
- No `shopt -s extglob` or bash-specific regex needed

**Pattern coverage:**
- `*_sim` catches: `build_sim`, `build_run_sim`, `test_sim`, `run_sim`, `install_app_sim`, `launch_app_sim`, `tap_sim`, `swipe_sim`, etc. (all current and future `_sim` suffixed tools)
- Explicit list: `screenshot`, `snapshot_ui` (no `_sim` suffix but sim-interacting), `session_set_defaults`, `session_use_defaults_profile` (session target configuration)
- **Not captured (intentional):** `debug_*` tools (no `_sim` suffix, may also target macOS — fall through to fail-open ALLOW), `build_device`, `list_schemes`, `get_build_logs`, etc. (non-sim operations — fall through to ALLOW)

**Edge case — `*_sim` as substring:** A hypothetical tool like `get_sim_status` does NOT end with `_sim`, so `*_sim` does NOT match. `case "mcp__XcodeBuildMCP__get_sim_status" in *_sim)` evaluates to false. Correct behavior.

#### Step 1.4 — Rename and slim CLONE_REQUIRED_TOOLS to ios-simulator only (AC3)

```bash
# ios-simulator clone-required tools (UDID injection needed)
CLONE_REQUIRED_IOS_SIM=(
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

**Excluded (fall through to fail-open ALLOW):**
- `get_booted_sim_id` (read-only, no UDID injection needed)
- `stop_recording` (stops ongoing recording, UDID not needed)

**Why array instead of pattern matching for ios-simulator:** All 22 tools need UDID injection via `handle_ios_simulator`. The tool set is stable (ios-simulator MCP server). Pattern matching offers no advantage here since we need to be explicit about which tools get UDID injected.

#### Step 1.5 — Rewrite `main()` routing logic (AC1 + all ACs integrated)

```bash
main() {
  local input
  input=$(cat)

  local tool_name
  tool_name=$(echo "$input" | jq -r '.tool_name // ""')
  local tool_input
  tool_input=$(echo "$input" | jq -c '.tool_input // {}')
  local session_id
  session_id=$(echo "$input" | jq -r '.session_id // ""')

  # 1. DENY_TOOLS — unconditional block (AC4, AC5)
  if in_array "$tool_name" "${DENY_TOOLS[@]}"; then
    emit_deny "sim-pool: '${tool_name}' is denied to protect the golden image."
    exit 0
  fi

  # 2. No session_id — passthrough
  if [ -z "$session_id" ]; then
    emit_allow
    exit 0
  fi

  # 3. Persist check (AC7)
  if in_array "$tool_name" "${PERSIST_CHECK_TOOLS[@]}"; then
    handle_persist_check "$tool_input"
  fi

  # 4. XcodeBuildMCP clone-required — pattern match (AC2a, AC2b)
  if is_xcode_clone_required "$tool_name"; then
    handle_xcodebuildmcp "$session_id" "$tool_name" "$tool_input"
    exit 0
  fi

  # 5. ios-simulator clone-required — array match (AC3)
  if in_array "$tool_name" "${CLONE_REQUIRED_IOS_SIM[@]}"; then
    handle_ios_simulator "$session_id" "$tool_input"
    exit 0
  fi

  # 6. Default — fail-open ALLOW (AC1)
  emit_allow
}
```

**Flow diagram:**

```
tool_name in DENY_TOOLS? ──yes──> DENY (exit)
         │ no
session_id empty? ──yes──> ALLOW (exit)
         │ no
tool_name in PERSIST_CHECK? ──yes──> persist:true? ──yes──> DENY (exit)
         │                                    │ no
         │                                    v (continue)
is_xcode_clone_required? ──yes──> handle_xcodebuildmcp (exit)
         │ no
tool_name in CLONE_REQUIRED_IOS_SIM? ──yes──> handle_ios_simulator (exit)
         │ no
ALLOW (fail-open default)
```

**Key ordering invariant:** `session_set_defaults` and `session_use_defaults_profile` appear in both `PERSIST_CHECK_TOOLS` and `is_xcode_clone_required`. Persist check runs first (step 3). If `persist:true`, DENY exits before reaching clone-required. If `persist:false` or omitted, execution continues to `is_xcode_clone_required`. This matches current behavior.

#### Step 1.6 — Update file header comment

```bash
# Line 2: "Fail-Closed Guard" → "Fail-Open Guard"
# Line 5: "unknown tools are DENIED (fail-closed)" → "unknown tools are ALLOWED (fail-open)"
```

### Phase 2: Test Rewrite (F2, F3, F4, F5)

#### Step 2.1 — Delete `test_sim_failclosed_guard.bats` (F2)

All 17 tests test fail-closed behavior that no longer exists. Remove the entire file.

#### Step 2.2 — Create `test_sim_failopen_guard.bats` (F3)

| Test ID | AC | Description |
|---------|-----|-------------|
| FO1.1 | AC1 | Unknown XcodeBuildMCP tool (`unknown_new_tool`) → ALLOW |
| FO1.2 | AC1 | Unknown ios-simulator tool → ALLOW |
| FO1.3 | AC1 | `build_device` (non-sim XcodeBuildMCP) → ALLOW |
| FO1.4 | AC1 | `swift_package_test` → ALLOW |
| FO1.5 | AC1 | `debug_continue` (debug tool, no `_sim`) → ALLOW |
| FO2.1 | AC2a | `build_sim` → DENY with session_set_defaults guidance (first call) |
| FO2.2 | AC2a | `test_sim` → DENY with guidance (first call) |
| FO2.3 | AC2a | `future_feature_sim` (hypothetical) → DENY with guidance |
| FO2.4 | AC2b | `screenshot` → DENY with guidance (first call) |
| FO2.5 | AC2b | `snapshot_ui` → DENY with guidance (first call) |
| FO2.6 | AC2b | `session_set_defaults` (persist:false) → ALLOW via handle_xcodebuildmcp |
| FO2.7 | AC2b | `session_use_defaults_profile` (persist:false) → ALLOW via handle_xcodebuildmcp |
| FO3.1 | AC4 | `erase_sims` → DENY with golden image protection reason |
| FO3.2 | AC4 | `erase_sims` DENY reason contains "golden image" |
| FO3.3 | AC5 | `erase_sims` denied even with empty session_id |
| FO4.1 | AC6 | No READONLY_TOOLS array in guard script |
| FO4.2 | AC6 | Guard script has `is_xcode_clone_required` function |
| FO4.3 | AC6 | Guard processes representative tools without unbound variable error |
| FO5.1 | — | addon.yml matcher catches XcodeBuildMCP (migrated from old file) |
| FO5.2 | — | addon.yml matcher catches ios-simulator (migrated) |
| FO5.3 | — | addon.yml timeout is 90 seconds (migrated) |
| FO5.4 | — | Empty session_id → ALLOW passthrough (migrated) |
| FO5.5 | — | Guard script is executable (migrated) |

**Mock setup:** Standard pattern from existing tests (mock xcrun in `$MOCK_BIN`).

#### Step 2.3 — Update `test_sim_clone_required_variants.bats` (F4)

Changes:
- Remove AC2.1-2.3 (READONLY_TOOLS negative grep tests) — array no longer exists
- Update AC1.1-1.3 static grep: `CLONE_REQUIRED_TOOLS` → `CLONE_REQUIRED_IOS_SIM`
- The ios-simulator tools (`launch_app`, `tap`, etc.) should still be verified in this array
- Update `run_guard` helper if the session flow changes (unlikely — same guard script, same stdin format)

#### Step 2.4 — Verify `test_sim_persist_block.bats` (F5)

AC4.9-4.10 grep for `PERSIST_CHECK_TOOLS`. This array is unchanged. Tests should pass as-is. Run to confirm.

### Phase 3: Housekeeping (F6, F7)

#### Step 3.1 — CHANGELOG.md

```markdown
## [Unreleased]

### Changed
- sim-pool-guard.sh: redesign from fail-closed to fail-open — unlisted tools now ALLOW instead of DENY (#21)
- sim-pool-guard.sh: XcodeBuildMCP clone-required tools use `_sim` pattern matching instead of explicit list (#21)
- sim-pool-guard.sh: rename `CLONE_REQUIRED_TOOLS` to `CLONE_REQUIRED_IOS_SIM` for clarity (#21)

### Added
- sim-pool-guard.sh: `DENY_TOOLS` array for golden image protection (`erase_sims`) (#21)
- sim-pool-guard.sh: `is_xcode_clone_required()` function for pattern-based tool matching (#21)

### Removed
- sim-pool-guard.sh: `READONLY_TOOLS` array (superseded by fail-open default) (#21)
```

#### Step 3.2 — .claude-plugin/plugin.json version bump

This is a behavioral change (fail-closed → fail-open), not just a bug fix. Bump MINOR:

```json
"version": "1.2.0"
```

**Rationale:** SemVer MINOR — the guard's behavior changes for unknown tools (DENY → ALLOW). Not a PATCH because the observable behavior changes. Not MAJOR because the hook contract (stdin JSON → stdout JSON) is unchanged.

### Phase 4: Verification

#### Step 4.1 — Syntax check

```bash
bash -n addons/ios/scripts/sim-pool-guard.sh
```

#### Step 4.2 — Full BATS suite

```bash
bats addons/ios/tests/
```

All tests must pass.

#### Step 4.3 — Manual smoke test

```bash
# Fail-open default (unknown tool → ALLOW)
echo '{"tool_name":"mcp__XcodeBuildMCP__list_schemes","tool_input":{},"session_id":"s1"}' \
  | bash addons/ios/scripts/sim-pool-guard.sh
# Expected: {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}

# DENY (erase_sims, empty session_id)
echo '{"tool_name":"mcp__XcodeBuildMCP__erase_sims","tool_input":{},"session_id":""}' \
  | bash addons/ios/scripts/sim-pool-guard.sh
# Expected: DENY with golden image reason

# Pattern match (_sim tool)
echo '{"tool_name":"mcp__XcodeBuildMCP__build_sim","tool_input":{},"session_id":"s1"}' \
  | bash addons/ios/scripts/sim-pool-guard.sh
# Expected: DENY with session_set_defaults guidance (first call, needs mock xcrun)
```

## 3. Technical Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | `case` glob `*_sim` matches unintended tool names | Very Low | Medium | `*_sim` only matches at end of string. `get_sim_status` does NOT match. Verified by bash semantics. Test FO2.3 covers forward-compatibility. |
| R2 | `CLONE_REQUIRED_IOS_SIM` rename breaks test greps | Medium | Low | `grep -r 'CLONE_REQUIRED_TOOLS' addons/ios/tests/` and update all references. Covered in Step 2.3. |
| R3 | `set -u` with empty `DENY_TOOLS` expansion | Very Low | High | DENY_TOOLS always has at least one entry (`erase_sims`). Add comment documenting this invariant. |
| R4 | DENY before session_id changes behavior for non-session invocations | Intentional | — | This is AC5. `erase_sims` must be blocked in all contexts. DENY message is context-independent. |
| R5 | `handle_xcodebuildmcp` receives new pattern-matched tools | Expected | — | Handler is generic: ensure_clone → setup_flag check → ALLOW. Does not inspect specific tool names except `session_set_defaults` and `session_use_defaults_profile`. All `*_sim` tools follow the same path. |
| R6 | Existing tests reference `READONLY_TOOLS` in static greps | Medium | Low | `test_sim_failclosed_guard.bats` deleted. `test_sim_clone_required_variants.bats` updated in Step 2.3. Search: `grep -r 'READONLY_TOOLS' addons/ios/tests/` |

## 4. Per-AC Implementation Mapping

| AC | Phase | Step | Primary Change |
|----|-------|------|----------------|
| AC1 (fail-open default) | 1 | 1.5 | `main()` final branch: `emit_deny` → `emit_allow` |
| AC2a (`_sim` pattern) | 1 | 1.3 | New `is_xcode_clone_required()` function |
| AC2b (individual tools) | 1 | 1.3 | `screenshot`, `snapshot_ui`, `session_*` in case statement |
| AC3 (ios-simulator UDID) | 1 | 1.4 | `CLONE_REQUIRED_IOS_SIM` array (22 tools) |
| AC4 (erase_sims DENY) | 1 | 1.2 | `DENY_TOOLS` array + check in `main()` |
| AC5 (DENY before session_id) | 1 | 1.2 | DENY check placement in `main()` |
| AC6 (READONLY_TOOLS removal) | 1 | 1.1 | Delete array + references |
| AC7 (persist:true block) | — | — | No change — verify existing behavior maintained |
| AC8 (BATS tests) | 2 | 2.1-2.4 | Delete old, create new, update existing |
