#!/usr/bin/env bash
# テスト用モックステップ: ステップ名を order ログに追記し、"fail" 指定時は非ゼロ終了。
# 呼び出し形: mc-step.sh <step> <orderlog> [fail] <branch>
#   merge-coordinator.sh は末尾に <branch> を付けて呼ぶ。
step="$1"; log="$2"; mode="${3:-}"
echo "$step" >> "$log"
[ "$mode" = "fail" ] && exit 1
exit 0
