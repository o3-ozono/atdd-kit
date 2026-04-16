#!/usr/bin/env bats

# Issue #78: Tightening protection — structural elements must survive tight English compression

# --- AC2a: Agent frontmatter fields preserved ---

@test "AC2a: all agent files retain model field" {
  for f in agents/[^R]*.md; do
    grep -q '^model:' "$f"
  done
}

@test "AC2a: all agent files retain effort field" {
  for f in agents/[^R]*.md; do
    grep -q '^effort:' "$f"
  done
}

@test "AC2a: all agent files retain tools section" {
  for f in agents/[^R]*.md; do
    grep -q '^tools:' "$f"
  done
}

# --- AC2b: Code block balance (even fence count per file) ---

@test "AC2b: all skill SKILL.md files have balanced backtick fences" {
  for f in skills/*/SKILL.md; do
    count=$(grep -c '^```' "$f" || true)
    (( count % 2 == 0 ))
  done
}

@test "AC2b: all command files have balanced backtick fences" {
  for f in commands/[^R]*.md; do
    count=$(grep -c '^```' "$f" || true)
    (( count % 2 == 0 ))
  done
}

# --- AC5: DEVELOPMENT.md Tightening Guidelines section ---

@test "AC5: DEVELOPMENT.md has Tightening Guidelines section" {
  grep -q 'Tightening Guidelines' DEVELOPMENT.md
}

@test "AC5: DEVELOPMENT.md Tightening Guidelines contains at least 7 numbered rules" {
  count=$(sed -n '/Tightening Guidelines/,/^###/p' DEVELOPMENT.md | grep -cE '^[0-9]+\.' || true)
  (( count >= 7 ))
}
