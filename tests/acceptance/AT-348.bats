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

# ---------------------------------------------------------------------------
# Part 2: friction classification maps FAIL steps to the correct gate bucket.
#   Decision (cause-agreement gate, 案B): design-phase steps -> design,
#   impl-phase step (running-atdd-cycle) -> a dedicated `impl` bucket,
#   merge-family steps -> merge. No blind default catch-all into merge.
# ---------------------------------------------------------------------------

_p2_temp_repo() {
  local t; t=$(mktemp -d)
  mkdir -p "${t}/scripts" "${t}/docs/issues/1-demo"
  cp "$(repo_root)/${RETRO_SCRIPT}" "${t}/scripts/retrospective.sh"
  chmod +x "${t}/scripts/retrospective.sh"
  echo "$t"
}

@test "AT-348-2: extracting-user-stories FAIL classified as design friction (not merge)" {
  local t gh; t=$(_p2_temp_repo); gh=$(_stub_gh)
  trap "rm -rf '${t}' '${gh}'" RETURN
  cat > "${t}/docs/issues/1-demo/autopilot-log.jsonl" << 'LOG'
{"iteration":1,"step":"extracting-user-stories","verdict":"FAIL","fingerprint":"x","timestamp":"t"}
LOG
  local out fr
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --dry-run 2>&1 || true)
  fr=$(echo "$out" | grep -E '^friction:')
  echo "$fr" | grep -qE 'design=[^ ]*extracting-user-stories' || { echo "FAIL: US not classified as design: $fr"; return 1; }
  echo "$fr" | grep -qE 'merge=[^ ]*extracting-user-stories' && { echo "FAIL: US leaked into merge bucket: $fr"; return 1; }
  return 0
}

@test "AT-348-3: running-atdd-cycle FAIL classified into a dedicated impl bucket (not merge)" {
  local t gh; t=$(_p2_temp_repo); gh=$(_stub_gh)
  trap "rm -rf '${t}' '${gh}'" RETURN
  cat > "${t}/docs/issues/1-demo/autopilot-log.jsonl" << 'LOG'
{"iteration":1,"step":"running-atdd-cycle","verdict":"FAIL","fingerprint":"x","timestamp":"t"}
{"iteration":2,"step":"running-atdd-cycle","verdict":"FAIL","fingerprint":"y","timestamp":"t"}
LOG
  local out fr
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --dry-run 2>&1 || true)
  fr=$(echo "$out" | grep -E '^friction:')
  echo "$fr" | grep -qE 'impl=[^ ]*running-atdd-cycle' || { echo "FAIL: impl bucket missing running-atdd-cycle: $fr"; return 1; }
  echo "$fr" | grep -qE 'merge=[^ ]*running-atdd-cycle' && { echo "FAIL: running-atdd-cycle leaked into merge bucket: $fr"; return 1; }
  return 0
}

@test "AT-348-4: merge-family steps still classified as merge friction (no regression)" {
  local t gh; t=$(_p2_temp_repo); gh=$(_stub_gh)
  trap "rm -rf '${t}' '${gh}'" RETURN
  cat > "${t}/docs/issues/1-demo/autopilot-log.jsonl" << 'LOG'
{"iteration":1,"step":"writing-plan-and-tests","verdict":"FAIL","fingerprint":"x","timestamp":"t"}
{"iteration":2,"step":"merging-and-deploying","verdict":"FAIL","fingerprint":"y","timestamp":"t"}
LOG
  local out fr
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --dry-run 2>&1 || true)
  fr=$(echo "$out" | grep -E '^friction:')
  echo "$fr" | grep -qE 'design=[^ ]*writing-plan-and-tests' || { echo "FAIL: plan not classified as design: $fr"; return 1; }
  echo "$fr" | grep -qE 'merge=[^ ]*merging-and-deploying' || { echo "FAIL: merge not classified: $fr"; return 1; }
  return 0
}
