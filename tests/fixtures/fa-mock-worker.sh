#!/usr/bin/env bash
# mock worker: 並列度を観測しつつ短時間 hold して exit 0。
# env: CC_DIR（active/ と samples を置く）, MOCK_SLEEP
issue="$1"
mkdir -p "$CC_DIR/active"
: > "$CC_DIR/active/$issue"
# 現在の同時 active 数をサンプル記録（最大値の検証用）
ls "$CC_DIR/active" 2>/dev/null | grep -c . >> "$CC_DIR/samples"
sleep "${MOCK_SLEEP:-0.3}"
rm -f "$CC_DIR/active/$issue"
echo "$issue" >> "$CC_DIR/launched"
exit 0
