#!/usr/bin/env bats
# @covers: .claude-plugin/plugin.json, CHANGELOG.md
# AT-334-E: リリース整合（invariant 回帰）
#
# plugin.json の version が CHANGELOG 最上位リリース見出しと一致することを invariant として確認する。
# 特定バージョン値は固定しない（post-merge regression で次の bump の度に壊れるため）。
#
# lifecycle: [draft]

@test "AT-334-E1: plugin.json version matches CHANGELOG topmost release heading (invariant)" {
  # Given: .claude-plugin/plugin.json と CHANGELOG.md
  # When: バージョンと最上位リリース見出しを照合する
  # Then: plugin.json の version が CHANGELOG 最上位リリース見出しと一致する（特定値を固定しない invariant）
  # [Unreleased] は開発中スニペットのため、バージョン番号を持つ最初のリリース見出しと比較する
  local plugin_version changelog_version
  plugin_version=$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json"))["version"])')
  changelog_version=$(grep '^## \[' CHANGELOG.md | grep -v 'Unreleased' | head -1 | sed 's/^## \[//; s/\].*//')
  [ "$plugin_version" = "$changelog_version" ]
}
