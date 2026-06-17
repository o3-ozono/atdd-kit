#!/usr/bin/env bash
# lib/fa-notify-discord.sh — full-autopilot の per-issue Discord スレッド通知
#
# Issue #318。`FA_NOTIFY_CMD` として使う通知フックの Discord 実装。各 issue ごとに
# 1つの **forum スレッド**を立て、その issue の状況・ログをスレッドへ流す。
# 呼び出し契約（full-autopilot-run.sh から）: <event> <issue> <detail>
#
# Discord 仕様: forum channel の webhook に `thread_name` 付きで POST すると新規スレッドが
# 立つ（初回）。以後は `?thread_id=<id>` でそのスレッドへ追記する。スレッド id は
# 初回 POST のレスポンス（`channel_id`）から取得し issue→id でローカルに保持する。
#
# config:
#   FA_DISCORD_WEBHOOK   forum channel の webhook URL（未設定なら no-op で 0 を返す）
#   FA_NOTIFY_STATE      issue→thread_id マップ置き場（既定 ${RUNDIR}/fa-notify）
#   FA_HTTP_POST         HTTP POST 実行コマンド "<url> <json>"（既定 curl、テストはモック注入）
#   FA_DISCORD_MENTION   escalate 時に付けるメンション（任意, 例 "<@123>"）

set -u

STATE="${FA_NOTIFY_STATE:-${RUNDIR:-/tmp}/fa-notify}"
WEBHOOK="${FA_DISCORD_WEBHOOK:-}"
MENTION="${FA_DISCORD_MENTION:-}"
LIMIT=1900   # Discord メッセージ上限 2000 未満で分割

__curl_post() { curl -sS -H 'Content-Type: application/json' -X POST -d "$2" "$1"; }
HTTP_POST="${FA_HTTP_POST:-__curl_post}"

json_str() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

thread_file() { printf '%s/thread.%s' "$STATE" "$1"; }

# issue のスレッドを確保し thread_id を出力。無ければ thread_name 付き POST で新規作成。
ensure_thread() {
  local issue="$1" title="$2" tf resp id body
  tf="$(thread_file "$issue")"
  if [ -f "$tf" ]; then cat "$tf"; return 0; fi
  [ -z "$WEBHOOK" ] && return 1
  mkdir -p "$STATE"
  body="$(printf '{"thread_name":%s,"content":%s}' \
    "$(printf '%s' "$title" | json_str)" "$(printf '%s' "🧵 $title — full-autopilot 開始" | json_str)")"
  resp="$($HTTP_POST "${WEBHOOK}?wait=true" "$body")"
  id="$(printf '%s' "$resp" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except: d={}
print(d.get("channel_id") or d.get("id") or "")' 2>/dev/null)"
  [ -z "$id" ] && return 1
  printf '%s' "$id" > "$tf"
  printf '%s' "$id"
}

# issue のスレッドへメッセージを流す（上限超は分割）。
post_thread() {
  local issue="$1" msg="$2" id chunk
  id="$(ensure_thread "$issue" "issue #$issue (full-autopilot)")" || return 1
  [ -z "$WEBHOOK" ] && return 1
  while [ -n "$msg" ]; do
    chunk="${msg:0:$LIMIT}"; msg="${msg:$LIMIT}"
    $HTTP_POST "${WEBHOOK}?thread_id=${id}&wait=true" \
      "$(printf '{"content":%s}' "$(printf '%s' "$chunk" | json_str)")" >/dev/null 2>&1 || true
  done
  return 0
}

main() {
  local event="${1:-}" issue="${2:-}" detail="${3:-}"
  [ -z "$WEBHOOK" ] && return 0   # 未設定なら no-op（成功扱い）
  case "$event" in
    dispatch)       post_thread "$issue" "🚀 着手: headless worker 起動" ;;
    progress)       post_thread "$issue" "… $detail" ;;
    log)            post_thread "$issue" "\`\`\`\n$detail\n\`\`\`" ;;
    merge-ready)    post_thread "$issue" "🟢 merge-ready" ;;
    merged)         post_thread "$issue" "✅ merged${detail:+: $detail}" ;;
    merge-failed)   post_thread "$issue" "⚠️ merge-failed: $detail" ;;
    worker-failed)  post_thread "$issue" "❌ worker-failed: $detail" ;;
    escalate)       post_thread "$issue" "🚨 ESCALATION ${MENTION}: $detail" ;;
    *)              post_thread "$issue" "$event: $detail" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
