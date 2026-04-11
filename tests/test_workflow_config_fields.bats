#!/usr/bin/env bats

# workflow-config.yml now only requires the platform field.
# Templates (workflow-config.yml.tmpl) no longer exist.

@test "workflow-config.yml.tmpl does not exist (templates abolished)" {
  [[ ! -f "templates/workflow-config.yml.tmpl" ]]
}

@test "session-start writes workflow-config with platform field" {
  grep -q 'platform' skills/session-start/SKILL.md
}

@test "session-start does not reference language field in workflow-config" {
  ! grep -q 'language.*workflow-config\|workflow-config.*language' skills/session-start/SKILL.md
}
