#!/usr/bin/env bats
# @covers: agents/**
# Issue #105: Agent frontmatter model/effort removal — regression guard
# Agents must NOT have pinned model or effort; session-level settings inherit instead.

@test "AC1: no pinned model field in any agent file" {
  for agent in developer qa researcher tester reviewer writer; do
    ! grep -q '^model:' "agents/${agent}.md"
  done
}

@test "AC2: no pinned effort field in any agent file" {
  for agent in developer qa researcher tester reviewer writer; do
    ! grep -q '^effort:' "agents/${agent}.md"
  done
}

@test "AC3: agents/README.md has no Model or Effort column in Agent table" {
  ! grep -q '| Model |' agents/README.md
  ! grep -q '| Effort |' agents/README.md
}

@test "AC3: agents/README.md documents session-level inheritance" {
  grep -qi 'session' agents/README.md
}
