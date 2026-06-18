#!/usr/bin/env bats
# @covers: templates/issue/ja/development.yml templates/issue/en/development.yml
# =============================================================================
# AT-329-template: Issue テンプレートが意図シードに軽量化されている（US-0 / 真因0）
# AT-329-0a: AC/サブタスク/完了条件/User Story が optional
# AT-329-0b: 意図3点フィールドが required（summary / outcome / scope-boundary）
# AT-329-0c: always-sync 経路が壊れていない（bilingual + template_sync）
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  JA="$ROOT/templates/issue/ja/development.yml"
  EN="$ROOT/templates/issue/en/development.yml"
}

# AT-329-0a: AC/サブタスク/完了条件/User Story はいずれも required: true を持たない
@test "AT-329-0a(ja): acceptance-criteria is optional (no required: true)" {
  # Extract the block for acceptance-criteria and check no required: true after it
  # Use awk to find the id: acceptance-criteria block and check required field
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: acceptance-criteria/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$JA")
  [ -z "$result" ]
}

@test "AT-329-0a(ja): subtasks is optional (no required: true)" {
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: subtasks/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$JA")
  [ -z "$result" ]
}

@test "AT-329-0a(ja): completion-criteria is optional (no required: true)" {
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: completion-criteria/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$JA")
  [ -z "$result" ]
}

@test "AT-329-0a(ja): user-story is optional (no required: true)" {
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: user-story/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$JA")
  [ -z "$result" ]
}

@test "AT-329-0a(en): acceptance-criteria is optional (no required: true)" {
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: acceptance-criteria/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$EN")
  [ -z "$result" ]
}

@test "AT-329-0a(en): subtasks is optional (no required: true)" {
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: subtasks/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$EN")
  [ -z "$result" ]
}

@test "AT-329-0a(en): completion-criteria is optional (no required: true)" {
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: completion-criteria/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$EN")
  [ -z "$result" ]
}

@test "AT-329-0a(en): user-story is optional (no required: true)" {
  result=$(awk '/^  - type: textarea/{blk=""} {blk=blk"\n"$0} /id: user-story/{found=1} found && /required: true/{print "REQUIRED_TRUE"; found=0} found && /^  - type:/{found=0}' "$EN")
  [ -z "$result" ]
}

# AT-329-0b: 意図3点（summary / outcome / scope-boundary）が required: true を持つ
# and ONLY those three are required (no other required: true fields except skills checkbox)
@test "AT-329-0b(ja): summary is required" {
  result=$(awk '/id: summary/{found=1} found && /required: true/{print "OK"; found=0} found && /^  - type:/{found=0}' "$JA")
  [ "$result" = "OK" ]
}

@test "AT-329-0b(ja): outcome is required" {
  result=$(awk '/id: outcome/{found=1} found && /required: true/{print "OK"; found=0} found && /^  - type:/{found=0}' "$JA")
  [ "$result" = "OK" ]
}

@test "AT-329-0b(ja): scope-boundary is required" {
  result=$(awk '/id: scope-boundary/{found=1} found && /required: true/{print "OK"; found=0} found && /^  - type:/{found=0}' "$JA")
  [ "$result" = "OK" ]
}

@test "AT-329-0b(en): summary is required" {
  result=$(awk '/id: summary/{found=1} found && /required: true/{print "OK"; found=0} found && /^  - type:/{found=0}' "$EN")
  [ "$result" = "OK" ]
}

@test "AT-329-0b(en): outcome is required" {
  result=$(awk '/id: outcome/{found=1} found && /required: true/{print "OK"; found=0} found && /^  - type:/{found=0}' "$EN")
  [ "$result" = "OK" ]
}

@test "AT-329-0b(en): scope-boundary is required" {
  result=$(awk '/id: scope-boundary/{found=1} found && /required: true/{print "OK"; found=0} found && /^  - type:/{found=0}' "$EN")
  [ "$result" = "OK" ]
}

@test "AT-329-0b(ja): exactly 3 required fields (summary + outcome + scope-boundary only)" {
  # Count textarea fields with required: true (skip checkboxes)
  count=$(awk '
    /^  - type: textarea/{in_block=1; id=""}
    in_block && /id:/{id=$2}
    in_block && /required: true/{if(id!="") count++}
    /^  - type: checkboxes/{in_block=0}
    END{print count}
  ' "$JA")
  [ "$count" -eq 3 ]
}

@test "AT-329-0b(en): exactly 3 required fields (summary + outcome + scope-boundary only)" {
  count=$(awk '
    /^  - type: textarea/{in_block=1; id=""}
    in_block && /id:/{id=$2}
    in_block && /required: true/{if(id!="") count++}
    /^  - type: checkboxes/{in_block=0}
    END{print count}
  ' "$EN")
  [ "$count" -eq 3 ]
}

# AT-329-0c: always-sync 経路が壊れていない
# development.yml を軽量化した後も、ja/en バイリンガル構造と .github/ISSUE_TEMPLATE/ 同期が保たれる。
# tests/test_bilingual_templates.bats / tests/test_template_sync.bats が担う証跡を
# AT-329-0c として明示的にマッピングすることで将来のカバレッジ起点を確定させる。

@test "AT-329-0c(bilingual): development.yml exists in both ja and en" {
  # バイリンガル構造維持: 軽量化後も ja/en 両テンプレートが存在すること
  [ -f "$JA" ]
  [ -f "$EN" ]
}

@test "AT-329-0c(bilingual): ja and en development.yml have distinct name fields" {
  # バイリンガル構造維持: ja/en が同一 name を持たないこと
  # test_bilingual_templates の invariant を AT-329-0c 視点で明示マッピング
  ja_name=$(grep '^name:' "$JA")
  en_name=$(grep '^name:' "$EN")
  [ "$ja_name" != "$en_name" ]
}

@test "AT-329-0c(sync): en/development.yml matches .github/ISSUE_TEMPLATE/development.yml" {
  # always-sync 経路維持: en テンプレートが .github/ISSUE_TEMPLATE/ に同期されていること
  # test_template_sync の invariant を AT-329-0c 視点で明示マッピング
  target="$ROOT/.github/ISSUE_TEMPLATE/development.yml"
  [ -f "$target" ] || { echo "missing: $target"; return 1; }
  diff "$EN" "$target" || { echo "diverged: $EN vs $target"; return 1; }
}

@test "AT-329-0c(sync): ja/development.yml matches .github/ISSUE_TEMPLATE/development-ja.yml" {
  # always-sync 経路維持: ja テンプレートが .github/ISSUE_TEMPLATE/development-ja.yml に同期されていること
  # test_template_sync の invariant を AT-329-0c 視点で明示マッピング
  target="$ROOT/.github/ISSUE_TEMPLATE/development-ja.yml"
  [ -f "$target" ] || { echo "missing: $target"; return 1; }
  diff "$JA" "$target" || { echo "diverged: $JA vs $target"; return 1; }
}
