#!/usr/bin/env bash
# 長命の孫プロセスを spawn して PID を記録し、自身は hang（timeout を誘発）。
# timeout kill が孫まで落とすか（孤児化しないか）の検証用。
issue="$1"
sleep 60 &
echo $! > "$CC_DIR/grandchild.$issue"
wait
