#!/usr/bin/env bash
# mock notifier: <event> <issue> <detail> を NOTIFY_LOG に記録。
echo "$1 $2" >> "$NOTIFY_LOG"
