#!/usr/bin/env bash
# mock HTTP POST: args <url> <json>。呼び出しを HTTP_LOG に記録し、
# thread_name を含む（=スレッド作成）POST には fake thread id を返す。
echo "POST $1" >> "$HTTP_LOG"
echo "BODY $2" >> "$HTTP_LOG"
case "$2" in
  *thread_name*) echo '{"channel_id":"T999"}' ;;
  *) echo '{}' ;;
esac
