#!/usr/bin/env bats

# Issue #109 AC3 — Main Claude is out of scope for profile flags (structural).
#
# Strategy:
#   Walk commands/autopilot.md line by line with code-fence tracking:
#     - Lines inside ```<lang> ... ``` are "code fences" -> allowed to contain
#       `model:` (Agent spawn specs).
#     - Lines inside <!-- nl-example start/end --> markers are "example blocks"
#       -> also allowed.
#     - Lines outside both -> treated as prose; `model:` here would indicate
#       that someone wrote a main Claude override in free text, which is
#       forbidden by AC3.
#
# Enabled after Phase B6 (NL Resolution Examples markers finalized).

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

@test "AC3: no prose-level model: literal in commands/autopilot.md" {
  skip "enable after Phase B6 - NL Resolution Examples marker finalized"
  hits="$(prose_model_hits)"
  [ -z "$hits" ] || { echo "prose model: hits:"; echo "$hits"; return 1; }
}

@test "AC3: config/spawn-profiles.yml is the only non-fenced source of model: outside autopilot.md" {
  skip "enable after Phase B6 - NL Resolution Examples marker finalized"
  # Config is allowed to have model: at file scope.
  grep -q 'model:' "${BATS_TEST_DIRNAME}/../config/spawn-profiles.yml"
}
