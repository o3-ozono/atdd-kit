#!/usr/bin/env bats
# @covers: scripts/retrospective.sh
#
# Acceptance Tests for Issue #348 -- retrospective.sh defects:
#   Part 1: Dialogue Volume 恒久ゼロ化 (munged-path mismatch)
#   Part 2: friction 分類異常 (impl/US steps mis-bucketed into merge)
#
# These are regression tests: red against the pre-fix script, green after.
# Unlike AT-309-3/6-behavioral (whose fixtures reuse the SAME broken transform
# and so are self-consistent), these fixtures encode the REAL Claude Code
# naming/gate convention so the defect is actually observable.

bats_require_minimum_version 1.5.0

RETRO_SCRIPT="scripts/retrospective.sh"

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

_stub_gh() {
  local d; d=$(mktemp -d)
  printf '#!/usr/bin/env bash\necho '\''{}'\''\nexit 0\n' > "${d}/gh"
  chmod +x "${d}/gh"
  echo "$d"
}

# ---------------------------------------------------------------------------
# Part 1: munged-path — real Claude Code transcript dir naming
#   Convention: keep the leading dash, convert BOTH `/` and `.` to `-`.
#   The repo path deliberately contains a dot (mimics `github.com`) so both
#   the leading-dash rule AND the dot-conversion rule are exercised in one test.
# ---------------------------------------------------------------------------

@test "AT-348-1: transcript dir resolved via real Claude Code munge (leading dash kept + dots converted)" {
  local base t gh munged
  base=$(mktemp -d)
  t="${base}/github.com-repo"           # dot in path -> exercises the dot rule
  mkdir -p "${t}/scripts" "${t}/docs/issues/1-demo"
  cp "$(repo_root)/${RETRO_SCRIPT}" "${t}/scripts/retrospective.sh"
  chmod +x "${t}/scripts/retrospective.sh"
  gh=$(_stub_gh)
  trap "rm -rf '${base}' '${gh}'" RETURN

  # REAL convention: leading dash kept, both `/` and `.` -> `-`
  munged=$(echo "${t}" | sed 's|[/.]|-|g')
  mkdir -p "${t}/.claude/projects/${munged}"
  printf '{"type":"user"}\n{"type":"assistant"}\n{"type":"assistant"}\n' \
    > "${t}/.claude/projects/${munged}/sess.jsonl"

  local out
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qE 'turns: user=1 assistant=2 total=3' || {
    echo "FAIL: turns miscounted -- munged-path did not resolve the real transcript dir"
    echo "$out" | grep -i turns
    return 1
  }
}
