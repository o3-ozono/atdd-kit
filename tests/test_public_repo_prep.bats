#!/usr/bin/env bats
# @covers: docs/**
# test_public_repo_prep.bats — Issue #16: public リポジトリ化の準備

# ─── AC1: marketplace.json のバージョン整合 ───

@test "AC1: marketplace.json does not duplicate version (plugin.json is single source of truth)" {
  # marketplace.json should NOT have version field (plugin.json takes priority per docs)
  marketplace_version="$(jq -r '.plugins[0].version // "null"' .claude-plugin/marketplace.json)"
  [ "$marketplace_version" = "null" ]
}

# ─── AC2: .gitignore に worktrees を明示追加 ───

@test "AC2: .gitignore contains .claude/worktrees/" {
  grep -q '\.claude/worktrees/' .gitignore
}
