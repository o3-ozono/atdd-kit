#!/usr/bin/env bash
# lib/fa-merge-steps.sh — full-autopilot merge coordinator の **実** git ステップ（#318）
#
# `__default_merge`（full-autopilot-run.sh）がこのスクリプトを `MC_REBASE_CMD`/`MC_MERGE_CMD`
# に配線することで、merge 経路が実際に rebase / merge を行う（配線しないと process() の
# 各ステップが空コマンド＝no-op success になり「実際には何も merge しない」事故になる #318 review）。
#
# FA_REPO（既定 cwd）の git リポジトリに対して操作する。gh ではなく素の git なので
# throwaway repo で決定論的に統合テストできる（main を汚さない）。
#   fa-merge-steps.sh rebase <branch>   # branch を base（origin/main→main）へ rebase。衝突は abort して非ゼロ
#   fa-merge-steps.sh merge  <branch>   # branch を base へ --no-ff merge。衝突は abort して非ゼロ
#
# Env: FA_REPO（対象 repo, 既定 pwd）/ FA_MERGE_BASE（base ブランチ, 既定 main）

set -u

REPO="${FA_REPO:-$(pwd)}"
BASE="${FA_MERGE_BASE:-main}"

g() { git -C "$REPO" "$@"; }

# rebase 先: origin/<base> があれば優先、無ければローカル <base>。
base_ref() {
  if g rev-parse -q --verify "origin/$BASE" >/dev/null 2>&1; then echo "origin/$BASE"; else echo "$BASE"; fi
}

case "${1:-}" in
  rebase)
    b="${2:?branch required}"
    g fetch origin "$BASE" -q 2>/dev/null || true
    g checkout -q "$b" || exit 1
    g rebase "$(base_ref)" || { g rebase --abort 2>/dev/null || true; exit 1; }
    ;;
  merge)
    b="${2:?branch required}"
    g checkout -q "$BASE" || exit 1
    g merge --no-ff -q -m "merge $b (full-autopilot)" "$b" || { g merge --abort 2>/dev/null || true; exit 1; }
    ;;
  *)
    echo "usage: fa-merge-steps.sh {rebase|merge} <branch>" >&2; exit 2 ;;
esac
