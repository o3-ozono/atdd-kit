#!/usr/bin/env bats
# @covers: agents/**
# Issue #105: Agent frontmatter model/effort removal — regression guard
# Agents must NOT have pinned model or effort; session-level settings inherit instead.
# Updated by #271: AC1/AC2 now use glob-based detection (no fixed 6-file list).

@test "AC1: no pinned model field in any agent definition file under agents/" {
  # If no *.md files exist beyond README.md, the test trivially passes (no agents to check).
  local found=0
  for f in agents/*.md; do
    [[ "$f" == "agents/README.md" ]] && continue
    [[ -f "$f" ]] || continue
    found=1
    ! grep -q '^model:' "$f" || {
      echo "FAIL: ${f} has pinned model field"
      return 1
    }
  done
  # Log informational message when no agent files exist
  [[ "$found" -eq 1 ]] || echo "# info: no agent definition files found in agents/ (only README.md)"
}

@test "AC2: no pinned effort field in any agent definition file under agents/" {
  # If no *.md files exist beyond README.md, the test trivially passes (no agents to check).
  local found=0
  for f in agents/*.md; do
    [[ "$f" == "agents/README.md" ]] && continue
    [[ -f "$f" ]] || continue
    found=1
    ! grep -q '^effort:' "$f" || {
      echo "FAIL: ${f} has pinned effort field"
      return 1
    }
  done
  [[ "$found" -eq 1 ]] || echo "# info: no agent definition files found in agents/ (only README.md)"
}

@test "AC3: agents/README.md has no Model or Effort column in Agent table" {
  ! grep -q '| Model |' agents/README.md
  ! grep -q '| Effort |' agents/README.md
}

@test "AC3: agents/README.md documents session-level inheritance" {
  grep -qi 'session' agents/README.md
}
