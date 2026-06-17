#!/usr/bin/env bats
# @covers: addons/discord/scripts/fa-notify-discord.sh
# =============================================================================
# fa-notify-discord.sh -- per-issue Discord スレッド通知（FA_NOTIFY_CMD 実装）
# Issue #318。HTTP は注入モックで置換し、スレッド生成→追記・per-issue 分離・
# 分割・no-op・escalate メンションを検証する。
#
#   DN-1: 初回イベントで thread_name 付き POST（スレッド生成）＋ id 永続化
#   DN-2: 同一 issue の以後のイベントは thread_id でそのスレッドへ追記
#   DN-3: issue ごとに別スレッド
#   DN-4: webhook 未設定なら no-op（HTTP 呼び出しゼロ）
#   DN-5: 上限超メッセージは複数 POST に分割
#   DN-6: escalate はメンションを含む
# =============================================================================

setup() {
  ADDON="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"   # addons/discord
  LIB_PATH="$ADDON/scripts/fa-notify-discord.sh"
  MOCK_HTTP="$ADDON/tests/fixtures/fa-mock-http.sh"
  STATE="$(mktemp -d)"
  LOG="$STATE/http.log"; : > "$LOG"
}

teardown() { rm -rf "$STATE"; }

dn() {
  FA_DISCORD_WEBHOOK="https://hook.test/wh" FA_NOTIFY_STATE="$STATE" \
    FA_HTTP_POST="bash $MOCK_HTTP" HTTP_LOG="$LOG" \
    FA_DISCORD_MENTION="<@1>" bash "$LIB_PATH" "$@"
}

@test "DN-1: first event creates a thread (thread_name) and persists the id" {
  dn dispatch 318
  grep -q 'thread_name' "$LOG"
  [ -f "$STATE/thread.318" ]
  [ "$(cat "$STATE/thread.318")" = "T999" ]
}

@test "DN-2: later events for the same issue post into its thread via thread_id" {
  dn dispatch 318
  dn merged 318
  grep -q 'thread_id=T999' "$LOG"
}

@test "DN-3: each issue gets its own thread" {
  dn dispatch 318
  dn dispatch 319
  [ -f "$STATE/thread.318" ]
  [ -f "$STATE/thread.319" ]
}

@test "DN-4: no webhook configured -> no-op (zero HTTP calls)" {
  FA_DISCORD_WEBHOOK="" FA_NOTIFY_STATE="$STATE" \
    FA_HTTP_POST="bash $MOCK_HTTP" HTTP_LOG="$LOG" \
    bash "$LIB_PATH" dispatch 318
  [ ! -s "$LOG" ]
}

@test "DN-5: an over-limit message is split into multiple posts" {
  big="$(printf 'x%.0s' $(seq 1 4000))"
  dn log 318 "$big"
  # thread 作成1 + content 追記（4000/1900 = 3 チャンク）。thread_id POST が 2 以上。
  [ "$(grep -c 'thread_id=T999' "$LOG")" -ge 2 ]
}

@test "DN-6: escalate includes the mention" {
  dn escalate 318 "N回失敗"
  grep -q 'ESCALATION' "$LOG"
  grep -q '<@1>' "$LOG"
}

@test "DN-7: HTTP failure is detected and recorded (not silently swallowed)" {
  ERR="$STATE/err.log"; : > "$ERR"
  run env FA_DISCORD_WEBHOOK="https://hook.test/wh" FA_NOTIFY_STATE="$STATE" \
    FA_HTTP_POST="bash $MOCK_HTTP" HTTP_LOG="$LOG" FA_MOCK_HTTP_FAIL=1 \
    FA_NOTIFY_ERRLOG="$ERR" bash "$LIB_PATH" dispatch 318
  # スレッド生成 POST が HTTP 失敗 → 非ゼロ ＋ errlog に記録（無音喪失しない）
  [ "$status" -ne 0 ]
  [ -s "$ERR" ]
  grep -qi 'fail' "$ERR"
}
