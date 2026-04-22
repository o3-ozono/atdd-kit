#!/usr/bin/env bats
# @covers: lib/**
# i18n structure tests — English-only skills, bilingual user-facing docs

# --- No SKILL.ja.md files exist (English-only) ---

@test "no SKILL.ja.md files exist in skills/" {
  local result
  result=$(find skills/ -name 'SKILL.ja.md' 2>/dev/null || true)
  [ -z "$result" ]
}

# --- User-facing bilingual docs still exist ---

@test "README.ja.md exists (user-facing bilingual)" {
  [[ -f "README.ja.md" ]]
}

@test "DEVELOPMENT.ja.md exists (user-facing bilingual)" {
  [[ -f "DEVELOPMENT.ja.md" ]]
}

# --- No docs/*.ja.md files (except user-generated subdirs) ---

@test "no docs/*.ja.md files at top level" {
  local result
  result=$(find docs/ -maxdepth 1 -name '*.ja.md' 2>/dev/null || true)
  [ -z "$result" ]
}
