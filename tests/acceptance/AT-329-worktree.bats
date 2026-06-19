#!/usr/bin/env bats
# @covers: lib/full-autopilot-run.sh
# =============================================================================
# AT-329-worktree: headless worker の worktree にプラグイン設定を播種する（真因0 follow-up）
# 背景: gitignore 対象の .claude/settings.local.json は worktree に複製されないため、
#       headless `claude -p` worker が atdd-kit プラグインを読めず Unknown command で落ちる。
# 注: lib を source すると bats の `run` が fd 3 を待ってハングするため、検証は直接呼び出し
#     ＋ファイル状態で行う（`run` は使わない）。
# AT-329-wt-a: source が在れば worktree に播種される
# AT-329-wt-b: 冪等（二度実行しても成功・内容一致）
# AT-329-wt-c: source 不在なら no-op（エラーにしない / ファイルを作らない）
# AT-329-wt-d: 既存の異なる dest は source 内容で上書きされる
# AT-329-wt-e: FA_NO_WORKTREE=1 で worktree 解決が空（従来どおり cwd 起動）
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RUN_PATH="$ROOT/lib/full-autopilot-run.sh"
  # source 元になる一時 git リポジトリ（.claude/settings.local.json を持つ）
  SRCREPO="$(mktemp -d)"
  git -C "$SRCREPO" init -q
  mkdir -p "$SRCREPO/.claude"
  printf '{"enabledPlugins":{"atdd-kit@atdd-kit":true}}\n' > "$SRCREPO/.claude/settings.local.json"
  WT="$(mktemp -d)/wt"   # 播種先（まだ存在しない）
  export FA_REPO="$SRCREPO"
  export LEASE_STORE_DIR="$(mktemp -d)"
  # 関数だけ使うため source（BASH_SOURCE ガードで main は走らない）。
  source "$RUN_PATH"
}

teardown() { rm -rf "$SRCREPO" "$(dirname "$WT")" "$LEASE_STORE_DIR"; }

@test "AT-329-wt-a: settings are seeded into the worktree when source exists" {
  __seed_worktree_settings "$WT"
  [ -f "$WT/.claude/settings.local.json" ]
  cmp -s "$SRCREPO/.claude/settings.local.json" "$WT/.claude/settings.local.json"
}

@test "AT-329-wt-b: seeding is idempotent (run twice, success, content matches)" {
  __seed_worktree_settings "$WT"; rc1=$?
  __seed_worktree_settings "$WT"; rc2=$?
  [ "$rc1" -eq 0 ]
  [ "$rc2" -eq 0 ]
  cmp -s "$SRCREPO/.claude/settings.local.json" "$WT/.claude/settings.local.json"
}

@test "AT-329-wt-c: no source settings → no-op (returns 0, no dest file)" {
  rm -f "$SRCREPO/.claude/settings.local.json"
  __seed_worktree_settings "$WT"; rc=$?
  [ "$rc" -eq 0 ]
  [ ! -f "$WT/.claude/settings.local.json" ]
}

@test "AT-329-wt-d: a differing existing dest is overwritten to match source" {
  mkdir -p "$WT/.claude"
  printf '{"stale":true}\n' > "$WT/.claude/settings.local.json"
  __seed_worktree_settings "$WT"
  cmp -s "$SRCREPO/.claude/settings.local.json" "$WT/.claude/settings.local.json"
}

@test "AT-329-wt-e: FA_NO_WORKTREE=1 resolves to empty (cwd launch, no worktree)" {
  out="$(FA_NO_WORKTREE=1 __worker_worktree 777)"
  [ -z "$out" ]
}
