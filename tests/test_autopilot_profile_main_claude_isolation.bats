#!/usr/bin/env bats
# @covers: commands/autopilot.md
# Issue #122 AC10 — Main Claude is always session default, across all 4 combos:
#   (custom absent / custom present) × (--profile absent / --profile present)
#
# Strategy:
#   Walk commands/autopilot.md line by line with code-fence tracking:
#     - Lines inside ```<lang> ... ``` are "code fences" -> allowed to contain
#       `model:` (Agent spawn specs).
#     - Lines inside <!-- nl-example start/end --> markers are "example blocks"
#       -> also allowed.
#     - Lines outside both -> treated as prose; `model:` here would indicate
#       that someone wrote a main Claude override in free text, which is
#       forbidden by AC10.

AUTOPILOT="${BATS_TEST_DIRNAME}/../commands/autopilot.md"

prose_model_hits() {
  awk '
    BEGIN { in_fence=0; in_nl=0 }
    /^```/ { in_fence = !in_fence; next }
    /<!-- nl-example start -->/ { in_nl=1; next }
    /<!-- nl-example end -->/   { in_nl=0; next }
    !in_fence && !in_nl && /model:/ { print NR": "$0 }
  ' "$AUTOPILOT"
}

@test "autopilot.md exists" {
  [ -f "$AUTOPILOT" ]
}

@test "AC10: no prose-level model: literal in commands/autopilot.md" {
  hits="$(prose_model_hits)"
  [ -z "$hits" ] || { echo "prose model: hits:"; echo "$hits"; return 1; }
}

@test "AC10: autopilot.md asserts main Claude keeps session default across all combos" {
  # Must explicitly note that main Claude (orchestrator) is unaffected by
  # custom presence or --profile presence.
  grep -qiE 'main Claude.*session default|orchestrator.*session default|main Claude.*unaffected|main Claude.*always keeps' "$AUTOPILOT"
}

@test "AC10: legacy config/spawn-profiles.yml is no longer referenced as a model source" {
  ! grep -q 'config/spawn-profiles.yml' "$AUTOPILOT"
}
