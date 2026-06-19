#!/usr/bin/env bats
# @covers: lib/full-autopilot-run.sh
# =============================================================================
# AT-329-queue: queue が動的に再評価される（US-1 / 真因1）
# AT-329-1a: 走行中に追加された ready-to-go を現セッションが拾う
# AT-329-1b: 同一 issue を二重起動しない
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RUN_PATH="$ROOT/lib/full-autopilot-run.sh"
  STORE="$(mktemp -d)"
  CC="$(mktemp -d)"; mkdir -p "$CC/active"
  : > "$CC/samples"; : > "$CC/launched"; : > "$CC/merged"
  QUEUE_FILE="$STORE/queue"
  QUEUE_CALL_COUNT_FILE="$STORE/queue_calls"
  : > "$QUEUE_CALL_COUNT_FILE"
}

teardown() { rm -rf "$STORE" "$CC"; }

# Dynamic queue script: first call returns issue A only; subsequent calls return A+B.
# This simulates issue B being added to ready-to-go after the session started.
make_dynamic_queue() {
  cat > "$STORE/dynamic_queue.sh" <<'SCRIPT'
#!/usr/bin/env bash
COUNT_FILE="$1"
# count calls
n=$(wc -l < "$COUNT_FILE" 2>/dev/null || echo 0)
echo "" >> "$COUNT_FILE"
n=$(( n + 1 ))
if [ "$n" -le 1 ]; then
  echo "501"
else
  echo "501"
  echo "502"
fi
SCRIPT
  chmod +x "$STORE/dynamic_queue.sh"
}

fa_run() {
  local k="$1"
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= FA_SESSION=fa CC_DIR="$CC" MOCK_SLEEP=0.3 \
    FA_FAIL_ISSUES="${FA_FAIL_ISSUES:-}" \
    FA_LOG="$CC/log" FA_RUNDIR="$CC/run" FA_POLL_INTERVAL=0.05 \
    FA_QUEUE_CMD="bash $STORE/dynamic_queue.sh $QUEUE_CALL_COUNT_FILE" \
    FA_LAUNCH_CMD="bash $ROOT/tests/fixtures/fa-mock-worker.sh" \
    FA_RESULT_CMD="bash $ROOT/tests/fixtures/fa-mock-result.sh" \
    FA_MERGE_CMD="bash $ROOT/tests/fixtures/fa-mock-merge.sh" \
    bash "$RUN_PATH" "$k"
}

# AT-329-1a: 走行中に追加された issue B も同一セッションで launch される（動的キュー再評価）
@test "AT-329-1a: issue added to queue after start is picked up in same session" {
  make_dynamic_queue
  fa_run 2
  # Both 501 and 502 must have been launched
  grep -qx '501' "$CC/launched"
  grep -qx '502' "$CC/launched"
  # Queue command was called more than once (dynamic re-evaluation)
  call_count=$(wc -l < "$QUEUE_CALL_COUNT_FILE")
  [ "$call_count" -ge 2 ]
}

# AT-329-1b: in-flight / 完了済みの issue は再 launch されない（dedup）
@test "AT-329-1b: in-flight and done issues are not re-launched (dedup)" {
  # Static queue that always returns issues 601 and 602
  printf '601\n602\n' > "$STORE/static_queue.txt"
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= FA_SESSION=fa CC_DIR="$CC" MOCK_SLEEP=0.3 \
    FA_FAIL_ISSUES="" \
    FA_LOG="$CC/log" FA_RUNDIR="$CC/run" FA_POLL_INTERVAL=0.05 \
    FA_QUEUE_CMD="cat $STORE/static_queue.txt" \
    FA_LAUNCH_CMD="bash $ROOT/tests/fixtures/fa-mock-worker.sh" \
    FA_RESULT_CMD="bash $ROOT/tests/fixtures/fa-mock-result.sh" \
    FA_MERGE_CMD="bash $ROOT/tests/fixtures/fa-mock-merge.sh" \
    bash "$RUN_PATH" 2
  # Each issue launched exactly once (no double dispatch)
  count_601=$(grep -cx '601' "$CC/launched" || echo 0)
  count_602=$(grep -cx '602' "$CC/launched" || echo 0)
  [ "$count_601" -eq 1 ]
  [ "$count_602" -eq 1 ]
}

# AT-329-1b: $QUEUE_CMD が re-evaluate されても completed issues are not re-launched
@test "AT-329-1b: completed issues from a prior queue evaluation are never re-launched" {
  make_dynamic_queue
  fa_run 1
  # With K=1: issue 501 launches and completes, then 502 launches once
  count_501=$(grep -cx '501' "$CC/launched" || echo 0)
  count_502=$(grep -cx '502' "$CC/launched" || echo 0)
  [ "$count_501" -eq 1 ]
  [ "$count_502" -eq 1 ]
  # Total: exactly 2 launches (no repeats)
  total=$(grep -c . "$CC/launched")
  [ "$total" -eq 2 ]
}
