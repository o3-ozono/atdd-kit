#!/usr/bin/env bats
# @covers: docs/**
# Issue #64: docs/ ディレクトリ構成の再編

# AC1: 既存ファイルが正しいサブディレクトリに移動される

@test "AC1: guides/commit-guide.md exists" {
  [ -f "docs/guides/commit-guide.md" ]
}

@test "AC1: guides/review-guide.md exists" {
  [ -f "docs/guides/review-guide.md" ]
}

@test "AC1: guides/doc-sync-checklist.md exists" {
  [ -f "docs/guides/doc-sync-checklist.md" ]
}

@test "AC1: guides/error-handling.md exists" {
  [ -f "docs/guides/error-handling.md" ]
}

@test "AC1: guides/getting-started.md exists" {
  [ -f "docs/guides/getting-started.md" ]
}

@test "AC1: guides/skill-authoring-guide.md exists" {
  [ -f "docs/guides/skill-authoring-guide.md" ]
}

@test "AC1: guides/skill-status-spec.md exists" {
  [ -f "docs/guides/skill-status-spec.md" ]
}

@test "AC1: methodology/atdd-guide.md exists" {
  [ -f "docs/methodology/atdd-guide.md" ]
}

@test "AC1: methodology/bug-fix-process.md exists" {
  [ -f "docs/methodology/bug-fix-process.md" ]
}

@test "AC1: workflow/workflow-detail.md exists" {
  [ -f "docs/workflow/workflow-detail.md" ]
}

@test "AC1: workflow/issue-ready-flow.md exists" {
  [ -f "docs/workflow/issue-ready-flow.md" ]
}

# v3.0.0 (#206/#207): workflow/autonomy-levels.md deleted — autopilot and its
# autonomy levels were removed in the v1.0 migration. The AC6 old_files guards
# still list "autonomy-levels" so any stale reference to the deleted doc is caught.

# AC2: 全参照パスが更新される

@test "AC2: skills reference docs/guides/skill-status-spec.md not old path" {
  ! grep -r 'docs/skill-status-spec\.md' skills/
}

@test "AC2: skills reference docs/methodology/atdd-guide.md not old path" {
  ! grep -r 'docs/atdd-guide\.md' skills/
}

@test "AC2: commands reference docs/guides/skill-status-spec.md not old path" {
  ! grep -r 'docs/skill-status-spec\.md' commands/
}

@test "AC2: commands reference docs/workflow/workflow-detail.md not old path" {
  ! grep -r '\.\.\/docs\/workflow-detail\.md' commands/
}

@test "AC2: rules reference updated paths" {
  ! grep -q 'docs/doc-sync-checklist\.md' rules/atdd-kit.md
  ! grep -q '[^/]workflow-detail\.md' rules/atdd-kit.md || \
    grep -q 'docs/workflow/workflow-detail\.md' rules/atdd-kit.md
}

@test "AC2: README.md references docs/guides/getting-started.md" {
  grep -q 'docs/guides/getting-started\.md' README.md
}

@test "AC2: README.md references docs/workflow/workflow-detail.md" {
  grep -q 'docs/workflow/workflow-detail\.md' README.md
}

# AC3: docs/README.md が新構成を反映する

@test "AC3: docs/README.md has guides section" {
  grep -qi 'guides' docs/README.md
}

@test "AC3: docs/README.md has methodology section" {
  grep -qi 'methodology' docs/README.md
}

@test "AC3: docs/README.md has workflow section" {
  grep -qi 'workflow' docs/README.md
}

# AC4: DEVELOPMENT.md の Repository Structure が更新される

@test "AC4: DEVELOPMENT.md mentions guides/ subdirectory" {
  grep -q 'guides/' DEVELOPMENT.md
}

@test "AC4: DEVELOPMENT.md mentions methodology/ subdirectory" {
  grep -q 'methodology/' DEVELOPMENT.md
}

@test "AC4: DEVELOPMENT.md mentions workflow/ subdirectory" {
  grep -q 'workflow/' DEVELOPMENT.md
}

# AC5: 不要項目が削除される

@test "AC5: superpowers-architecture-learnings.md is deleted" {
  [ ! -f "docs/superpowers-architecture-learnings.md" ]
}

@test "AC5: docs/plans/ directory is deleted" {
  [ ! -d "docs/plans" ]
}

@test "AC5: docs/process/ directory is deleted" {
  [ ! -d "docs/process" ]
}

# AC6: 旧パスへの参照がゼロ

@test "AC6: no old docs/ file references in skills (excluding CHANGELOG)" {
  local old_files="commit-guide review-guide doc-sync-checklist error-handling getting-started skill-authoring-guide skill-status-spec atdd-guide bug-fix-process workflow-detail issue-ready-flow autonomy-levels"
  local fail=0
  for f in $old_files; do
    if grep -r "docs/${f}\.md" skills/ --include="*.md" 2>/dev/null | grep -q .; then
      echo "STALE reference to docs/${f}.md in skills/" >&2
      fail=1
    fi
  done
  [ "$fail" -eq 0 ]
}

@test "AC6: no old docs/ file references in commands (excluding CHANGELOG)" {
  local old_files="commit-guide review-guide doc-sync-checklist error-handling getting-started skill-authoring-guide skill-status-spec atdd-guide bug-fix-process workflow-detail issue-ready-flow autonomy-levels"
  local fail=0
  for f in $old_files; do
    if grep -r "docs/${f}\.md" commands/ --include="*.md" 2>/dev/null | grep -q .; then
      echo "STALE reference to docs/${f}.md in commands/" >&2
      fail=1
    fi
  done
  [ "$fail" -eq 0 ]
}

@test "AC6: no old docs/ flat references in rules/atdd-kit.md" {
  ! grep -q 'docs/commit-guide\.md\|docs/review-guide\.md\|docs/doc-sync-checklist\.md' rules/atdd-kit.md
}

# #267 AT-001: deliverable presentation is Draft-PR based (US-1)
# Given: docs/workflow/workflow-detail.md
# When: the Execution Mode deliverable rule is inspected
# Then: the legacy comment-based rule is gone and the Draft-PR-diff rule exists

@test "#267 AT-001: legacy comment-based deliverable rule is gone from workflow-detail.md" {
  ! grep -q 'never written to ad-hoc repository paths' docs/workflow/workflow-detail.md
}

@test "#267 AT-001: Draft PR diff rule + comments-as-notifications-only rule exist in workflow-detail.md" {
  grep -q 'Draft PR diff' docs/workflow/workflow-detail.md
  grep -q 'state-change notifications and approval requests only' docs/workflow/workflow-detail.md
}
