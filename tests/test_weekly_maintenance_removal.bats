#!/usr/bin/env bats

# AC1: cron ワークフローと関連ファイルの完全削除を検証
# AC3: init / workflow-config テンプレートから weekly_maintenance が削除されていることを検証

@test "AC1: no weekly-maintenance workflow in .github/workflows/" {
  [ ! -f .github/workflows/weekly-maintenance.yml ]
}

@test "AC1: no weekly-maintenance-template in .github/" {
  [ ! -f .github/weekly-maintenance-template.md ]
}

@test "AC1: no weekly-maintenance templates in plugin templates/workflows/" {
  [ ! -f templates/workflows/weekly-maintenance.yml ]
  [ ! -f templates/workflows/weekly-maintenance-template.md ]
}

@test "AC1: no weekly_maintenance in workflow-config.yml" {
  ! grep -q 'weekly_maintenance' .claude/workflow-config.yml
}

@test "AC1: no weekly_maintenance references outside commands/ and CHANGELOG" {
  # grep で weekly_maintenance を検索、commands/ と CHANGELOG.md と tests/ を除外
  result=$(grep -r 'weekly_maintenance' --include='*.md' --include='*.yml' --include='*.tmpl' --include='*.bats' \
    --exclude-dir='.git' --exclude-dir='.tmp' . \
    | grep -v '^./commands/' \
    | grep -v '^./CHANGELOG.md' \
    | grep -v '^./tests/test_weekly_maintenance_removal.bats' \
    | grep -v '^./tests/README.md' \
    || true)
  [ -z "$result" ]
}

@test "AC3: workflow-config template no longer exists" {
  [[ ! -f templates/workflow-config.yml.tmpl ]]
}

@test "AC3: init skill no longer exists" {
  [[ ! -d skills/init ]]
}

@test "AC2: maintenance command exists" {
  [ -f commands/maintenance.md ]
}

@test "AC4: maintenance command includes line count check" {
  grep -qi 'CLAUDE.md.*line\|行数\|wc -l\|line.count' commands/maintenance.md
}

@test "AC4: maintenance command includes staleness detection" {
  grep -qi 'stale\|陳腐化\|90.*day\|90.*日' commands/maintenance.md
}

@test "AC4: maintenance command includes Issue creation" {
  grep -qi 'issue.*create\|Issue.*作成\|gh issue' commands/maintenance.md
}
