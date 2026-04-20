#!/usr/bin/env bats

# Issue #122 — .claude/workflow-config.yml → .claude/config.yml migration + AC11
# placeholder template drift-detect.
#
# Scope:
#   AC7  — 5-branch migration specified in skills/session-start/SKILL.md
#   AC11 — spawn_profiles.custom placeholder template requirements specified

SESSION_START="${BATS_TEST_DIRNAME}/../skills/session-start/SKILL.md"

@test "session-start SKILL.md exists" {
  [ -f "$SESSION_START" ]
}

# --- AC7: 5-branch migration ---

@test "AC7: SKILL.md references .claude/config.yml (new target file)" {
  grep -q '\.claude/config\.yml' "$SESSION_START"
}

@test "AC7: SKILL.md documents migration from workflow-config.yml to config.yml" {
  grep -qiE 'workflow-config\.yml.*config\.yml|migrate.*workflow-config|workflow-config.*→.*config\.yml' "$SESSION_START"
}

@test "AC7: SKILL.md documents old-only branch (write-then-delete)" {
  grep -qiE 'old.*only|only old|only.*workflow-config.*exist|旧のみ' "$SESSION_START"
  grep -qiE 'write.*then.*delete|write-then-delete|write first.*delete|delete.*after.*write' "$SESSION_START"
}

@test "AC7: SKILL.md documents new-only branch (no-op)" {
  grep -qiE 'new.*only.*no-?op|only.*config\.yml.*no-?op|新のみ.*no-?op' "$SESSION_START"
}

@test "AC7: SKILL.md documents both-exist with platform present (delete old only, no merge)" {
  grep -qiE 'both.*exist.*platform.*(present|有).*delete.*old|両方存在.*platform.*有.*旧削除|duplicate.*merge.*skip' "$SESSION_START"
}

@test "AC7: SKILL.md documents both-exist with platform absent (merge platform from old)" {
  grep -qiE 'both.*exist.*platform.*(absent|無).*merge|platform.*missing.*merge.*from.*old|両方存在.*platform.*無.*merge' "$SESSION_START"
}

@test "AC7: SKILL.md documents both-absent branch (no-op)" {
  grep -qiE 'both.*absent.*no-?op|neither.*exist.*no-?op|両方不在.*no-?op' "$SESSION_START"
}

@test "AC7: SKILL.md documents sync report entry for migration outcome" {
  grep -qiE 'sync report.*migrat|migration.*sync report|同期レポート.*移行' "$SESSION_START"
}

@test "AC7: SKILL.md write-then-delete is idempotent" {
  grep -qiE 'idempot' "$SESSION_START"
}

# --- AC11: placeholder template requirements ---

@test "AC11: SKILL.md documents spawn_profiles.custom placeholder template" {
  grep -q 'spawn_profiles' "$SESSION_START"
  grep -qiE 'placeholder|template|commented.*out' "$SESSION_START"
}

@test "AC11: SKILL.md placeholder template lists all 6 roles" {
  # The template spec block should enumerate every role either as a list or
  # a commented example.
  for role in developer qa tester reviewer researcher writer; do
    grep -q "$role" "$SESSION_START" \
      || { echo "role missing from session-start SKILL.md: $role"; return 1; }
  done
}

@test "AC11: SKILL.md placeholder template is idempotent (skip when spawn_profiles already present)" {
  grep -qiE 'already.*spawn_profiles|spawn_profiles.*already|skip.*if.*spawn_profiles|idempot.*spawn_profiles' "$SESSION_START"
}

@test "AC11: SKILL.md notes unspecified roles inherit session default" {
  grep -qiE 'unspecified.*session default|未指定.*session default|undefined.*session default|unset.*session default' "$SESSION_START"
}
