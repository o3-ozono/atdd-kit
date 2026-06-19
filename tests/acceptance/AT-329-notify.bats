#!/usr/bin/env bats
# @covers: lib/full-autopilot-run.sh
# =============================================================================
# AT-329-notify: 起動時に通知先が確認される（US-2 / 真因2）
# AT-329-2a: 通知先未設定なら起動時に警告
# AT-329-2b: 通知先設定済みなら確認ログ
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RUN_PATH="$ROOT/lib/full-autopilot-run.sh"
  STORE="$(mktemp -d)"
  CC="$(mktemp -d)"; mkdir -p "$CC/active"
  : > "$CC/samples"; : > "$CC/launched"; : > "$CC/merged"
  printf '701\n' > "$STORE/queue"
}

teardown() { rm -rf "$STORE" "$CC"; }

# AT-329-2a: FA_NOTIFY_CMD 未設定で起動時に「通知先未設定」警告が1回 FA_LOG に出る
@test "AT-329-2a: unset FA_NOTIFY_CMD logs a warning at startup (once)" {
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= FA_SESSION=fa CC_DIR="$CC" MOCK_SLEEP=0.1 \
    FA_FAIL_ISSUES="" FA_LOG="$CC/log" FA_RUNDIR="$CC/run" FA_POLL_INTERVAL=0.05 \
    FA_QUEUE_CMD="cat $STORE/queue" \
    FA_LAUNCH_CMD="bash $ROOT/tests/fixtures/fa-mock-worker.sh" \
    FA_RESULT_CMD="bash $ROOT/tests/fixtures/fa-mock-result.sh" \
    FA_MERGE_CMD="bash $ROOT/tests/fixtures/fa-mock-merge.sh" \
    bash "$RUN_PATH" 1
  # FA_LOG should contain the preflight unset warning
  grep -q 'preflight.*NOTIFY_CMD.*unset' "$CC/log"
  # Warning should appear exactly once
  count=$(grep -c 'preflight.*NOTIFY_CMD.*unset' "$CC/log")
  [ "$count" -eq 1 ]
  # Process should not have stopped (drain-complete reached)
  grep -q 'drain-complete' "$CC/log"
}

# AT-329-2b: FA_NOTIFY_CMD 設定済みで確認ログ1行が出る（本体は止まらない）
@test "AT-329-2b: set FA_NOTIFY_CMD logs a confirmation at startup (once)" {
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= FA_SESSION=fa CC_DIR="$CC" MOCK_SLEEP=0.1 \
    FA_FAIL_ISSUES="" FA_LOG="$CC/log" FA_RUNDIR="$CC/run" FA_POLL_INTERVAL=0.05 \
    FA_QUEUE_CMD="cat $STORE/queue" \
    FA_LAUNCH_CMD="bash $ROOT/tests/fixtures/fa-mock-worker.sh" \
    FA_RESULT_CMD="bash $ROOT/tests/fixtures/fa-mock-result.sh" \
    FA_MERGE_CMD="bash $ROOT/tests/fixtures/fa-mock-merge.sh" \
    FA_NOTIFY_CMD="echo notify" \
    bash "$RUN_PATH" 1
  # FA_LOG should contain the preflight confirmation (with the NOTIFY_CMD value)
  grep -q 'preflight.*NOTIFY_CMD=echo notify' "$CC/log"
  # Confirmation should appear exactly once
  count=$(grep -c 'preflight.*NOTIFY_CMD=' "$CC/log")
  [ "$count" -eq 1 ]
  # Process should not have stopped
  grep -q 'drain-complete' "$CC/log"
}
