#!/usr/bin/env bash
# mock HTTP POST: args <url> <json>。呼び出しを HTTP_LOG に記録。
# FA_MOCK_HTTP_FAIL=1 で HTTP 失敗（非ゼロ終了）をシミュレート（curl --fail 相当）。
echo "POST $1" >> "$HTTP_LOG"
echo "BODY $2" >> "$HTTP_LOG"
if [ "${FA_MOCK_HTTP_FAIL:-}" = "1" ]; then exit 22; fi
case "$2" in
  *thread_name*) echo '{"channel_id":"T999"}' ;;
  *) echo '{}' ;;
esac
