#!/usr/bin/env bats
# @covers: CHANGELOG.md
@test "CHANGELOG.md exists" {
  [[ -f CHANGELOG.md ]]
}

@test "CHANGELOG.md starts with '# Changelog' header" {
  head -1 CHANGELOG.md | grep -q "^# Changelog"
}

@test "CHANGELOG.md has at least one versioned section" {
  grep -qE '## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md
}

@test "CHANGELOG.md versioned sections have dates (YYYY-MM-DD)" {
  grep -E '## \[' CHANGELOG.md | grep -v 'Unreleased' | while read -r line; do
    [[ "$line" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]
  done
}

@test "CHANGELOG.md version matches plugin.json version" {
  plugin_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
  grep -q "## \[${plugin_version}\]" CHANGELOG.md
}
