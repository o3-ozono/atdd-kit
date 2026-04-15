#!/usr/bin/env bats
# tests/test_footprint_eval.bats
# Footprint regression test suite -- 7 groups (G1-G7) covering AC1-AC7
# FOOTPRINT_EVAL_DIR env var overrides the evals/footprint directory.
# All tests use $BATS_TEST_TMPDIR/evals/footprint to avoid polluting real baseline.

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/measure-footprint.sh"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures/footprint"

setup() {
  # FOOTPRINT_EVAL_DIR override -- never touch real evals/footprint/baseline.json
  export FOOTPRINT_EVAL_DIR="$BATS_TEST_TMPDIR/evals/footprint"
  mkdir -p "$FOOTPRINT_EVAL_DIR"

  # Copy fixture checkpoints into FOOTPRINT_EVAL_DIR
  cp "$FIXTURES_DIR/checkpoints/simple.yml"    "$FOOTPRINT_EVAL_DIR/simple.yml"
  cp "$FIXTURES_DIR/checkpoints/multi.yml"     "$FOOTPRINT_EVAL_DIR/multi.yml"
  cp "$FIXTURES_DIR/checkpoints/math_0.yml"    "$FOOTPRINT_EVAL_DIR/math_0.yml"
  cp "$FIXTURES_DIR/checkpoints/math_3.yml"    "$FOOTPRINT_EVAL_DIR/math_3.yml"
  cp "$FIXTURES_DIR/checkpoints/math_4.yml"    "$FOOTPRINT_EVAL_DIR/math_4.yml"
  cp "$FIXTURES_DIR/checkpoints/math_360.yml"  "$FOOTPRINT_EVAL_DIR/math_360.yml"
  # dynamic.yml is generated (not copied) so cache dirs land in BATS_TEST_TMPDIR
  # This prevents check-plugin-version.sh from writing back into the repo fixtures
  local dyn_cache_first="$BATS_TEST_TMPDIR/cache-first-run"
  local dyn_cache_no_update="$BATS_TEST_TMPDIR/cache-no-update"
  local dyn_cache_updated="$BATS_TEST_TMPDIR/cache-updated"
  mkdir -p "$dyn_cache_first" "$dyn_cache_no_update" "$dyn_cache_updated"
  # no-update and updated caches need a pre-existing version file
  printf '0.1.0\n' > "$dyn_cache_no_update/atdd-kit.version"
  printf '0.0.9\n' > "$dyn_cache_updated/atdd-kit.version"

  cat > "$FOOTPRINT_EVAL_DIR/dynamic.yml" <<DYNEOF
files:
  - tests/fixtures/footprint/simple/sample.md
dynamic:
  first_run:
    script: scripts/check-plugin-version.sh
    args:
      - tests/fixtures/footprint/dynamic
      - ${dyn_cache_first}
  no_update:
    script: scripts/check-plugin-version.sh
    args:
      - tests/fixtures/footprint/dynamic
      - ${dyn_cache_no_update}
  updated:
    script: scripts/check-plugin-version.sh
    args:
      - tests/fixtures/footprint/dynamic
      - ${dyn_cache_updated}
DYNEOF
  # Note: malformed.yml and missing_file.yml are NOT copied in setup
  # They are copied individually in G6 error-case tests to avoid breaking --update-all
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR/evals"
}

# =============================================================================
# G1: Happy path -- AC1: measure produces correct JSON schema for fixture checkpoint
# =============================================================================

@test "G1: measure outputs checkpoint field in JSON" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"checkpoint"'
}

@test "G1: measure outputs total_bytes field in JSON" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"total_bytes"'
}

@test "G1: measure outputs estimated_tokens field in JSON" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens"'
}

@test "G1: measure outputs files array in JSON" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"files"'
}

@test "G1: measure returns correct total_bytes=11 for simple fixture" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"total_bytes": 11'
}

@test "G1: measure returns estimated_tokens=4 for 11 bytes (ceil(11/3.6)=4)" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens": 4'
}

@test "G1: measure includes per-file path in files array" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"path"'
}

@test "G1: exit 0 on success" {
  run bash "$SCRIPT" measure simple
  [ "$status" -eq 0 ]
}

# =============================================================================
# G2: Math -- tokens = ceil(bytes / 3.6) at 4 boundaries
# =============================================================================

@test "G2: 0 bytes -> 0 tokens" {
  run bash "$SCRIPT" measure math_0
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens": 0'
}

@test "G2: 3 bytes -> 1 token (ceil(3/3.6) = ceil(0.833) = 1)" {
  run bash "$SCRIPT" measure math_3
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens": 1'
}

@test "G2: 4 bytes -> 2 tokens (ceil(4/3.6) = ceil(1.111) = 2)" {
  run bash "$SCRIPT" measure math_4
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens": 2'
}

@test "G2: 360 bytes -> 100 tokens (ceil(360/3.6) = 100 exact, no rounding)" {
  run bash "$SCRIPT" measure math_360
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens": 100'
}

# =============================================================================
# G3: Baseline lifecycle -- --update writes atomically; --check never modifies
# =============================================================================

@test "G3: --update creates baseline.json in FOOTPRINT_EVAL_DIR" {
  run bash "$SCRIPT" --update simple
  [ "$status" -eq 0 ]
  [ -f "$FOOTPRINT_EVAL_DIR/baseline.json" ]
}

@test "G3: baseline.json is keyed by checkpoint name after --update" {
  bash "$SCRIPT" --update simple
  grep -q '"simple"' "$FOOTPRINT_EVAL_DIR/baseline.json"
}

@test "G3: baseline.json contains updated_at in ISO8601 format" {
  bash "$SCRIPT" --update simple
  grep -q '"updated_at"' "$FOOTPRINT_EVAL_DIR/baseline.json"
  grep '"updated_at"' "$FOOTPRINT_EVAL_DIR/baseline.json" | grep -qE '"[0-9]{4}-[0-9]{2}-[0-9]{2}T'
}

@test "G3: --check does not modify baseline.json (checksum stable)" {
  bash "$SCRIPT" --update simple
  local before after
  before=$(md5sum "$FOOTPRINT_EVAL_DIR/baseline.json" 2>/dev/null || md5 -q "$FOOTPRINT_EVAL_DIR/baseline.json")
  bash "$SCRIPT" --check simple || true
  after=$(md5sum "$FOOTPRINT_EVAL_DIR/baseline.json" 2>/dev/null || md5 -q "$FOOTPRINT_EVAL_DIR/baseline.json")
  [ "$before" = "$after" ]
}

@test "G3: --update without name argument updates all checkpoints" {
  run bash "$SCRIPT" --update
  [ "$status" -eq 0 ]
  [ -f "$FOOTPRINT_EVAL_DIR/baseline.json" ]
  # Verify multiple entries were written (simple + multi + math_* + dynamic = 6 checkpoints)
  grep -q '"simple"' "$FOOTPRINT_EVAL_DIR/baseline.json"
  grep -q '"multi"' "$FOOTPRINT_EVAL_DIR/baseline.json"
  # JSON must remain valid after multi-entry write
  python3 -c "import json,sys; json.load(open('$FOOTPRINT_EVAL_DIR/baseline.json'))"
}

# =============================================================================
# G4: Threshold (AC5) -- +10% and +500 tokens boundaries, OR semantics, baseline=0
# =============================================================================

@test "G4: PASS when current equals baseline (no increase)" {
  bash "$SCRIPT" --update simple
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 0 ]
}

@test "G4: PASS when bytes just at 10% threshold (baseline=10, current=11: 11 > 11.0 is false)" {
  cp "$FIXTURES_DIR/baselines/just_below.json" "$FOOTPRINT_EVAL_DIR/baseline.json"
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 0 ]
}

@test "G4: REGRESSION exit 1 when bytes exceed 10% threshold (baseline=9, current=11: 11 > 9.9)" {
  cp "$FIXTURES_DIR/baselines/just_above.json" "$FOOTPRINT_EVAL_DIR/baseline.json"
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 1 ]
}

@test "G4: REGRESSION output includes bytes_delta" {
  cp "$FIXTURES_DIR/baselines/just_above.json" "$FOOTPRINT_EVAL_DIR/baseline.json"
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi 'bytes_delta\|bytes delta\|REGRESSION'
}

@test "G4: PASS when token_delta exactly 500 (not strictly greater than 500)" {
  # current_tokens = 4 (simple fixture); baseline_tokens = 4 - 500 = -496
  # delta = 500 -> NOT >500 -> PASS (only percent check fires: same bytes -> PASS)
  cat > "$FOOTPRINT_EVAL_DIR/baseline.json" <<'JSON'
{"simple":{"checkpoint":"simple","total_bytes":11,"estimated_tokens":-496,"files":[],"updated_at":"2026-01-01T00:00:00Z"}}
JSON
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 0 ]
}

@test "G4: REGRESSION exit 1 when token_delta is 501 (strictly greater than 500)" {
  # current_tokens = 4; baseline_tokens = 4 - 501 = -497
  cat > "$FOOTPRINT_EVAL_DIR/baseline.json" <<'JSON'
{"simple":{"checkpoint":"simple","total_bytes":11,"estimated_tokens":-497,"files":[],"updated_at":"2026-01-01T00:00:00Z"}}
JSON
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 1 ]
}

@test "G4: baseline_bytes=0 skips percent threshold; token delta 4 <= 500 -> PASS" {
  cp "$FIXTURES_DIR/baselines/zero_base.json" "$FOOTPRINT_EVAL_DIR/baseline.json"
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 0 ]
}

@test "G4: OR semantics -- token regression alone triggers failure when bytes are equal" {
  # bytes same (11=11), but token delta = 501 -> REGRESSION
  cat > "$FOOTPRINT_EVAL_DIR/baseline.json" <<'JSON'
{"simple":{"checkpoint":"simple","total_bytes":11,"estimated_tokens":-497,"files":[],"updated_at":"2026-01-01T00:00:00Z"}}
JSON
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 1 ]
}

@test "G4: PASS outputs one-line summary" {
  bash "$SCRIPT" --update simple
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -qiE 'PASS|OK|no regression'
}

@test "G4: missing baseline on --check exits 2" {
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 2 ]
}

# =============================================================================
# G5: Dynamic sub-checkpoint (AC3) -- 3 fixture cases + liveness check
# =============================================================================

@test "G5: measure dynamic checkpoint produces JSON with dynamic field" {
  run bash "$SCRIPT" measure dynamic
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"dynamic"'
}

@test "G5: dynamic first_run sub-checkpoint is captured with bytes and tokens" {
  run bash "$SCRIPT" measure dynamic
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"first_run"'
}

@test "G5: dynamic no_update sub-checkpoint is captured" {
  run bash "$SCRIPT" measure dynamic
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"no_update"'
}

@test "G5: dynamic updated sub-checkpoint is captured" {
  run bash "$SCRIPT" measure dynamic
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"updated"'
}

@test "G5: liveness -- check-plugin-version.sh is actually executed (not faked)" {
  # Inject a sentinel that would only appear if the real script runs
  run bash "$SCRIPT" measure dynamic
  [ "$status" -eq 0 ]
  # FIRST_RUN / NO_UPDATE / UPDATED appear in real output of check-plugin-version.sh
  # These strings should appear in the dynamic captured bytes (indirectly via size > 0)
  # Verify first_run sub has bytes > 0 (script was actually called)
  echo "$output" | grep -A2 '"first_run"' | grep -qE '"bytes": [1-9]'
}

# =============================================================================
# G6: Error cases -- exit 2 for various failure modes
# =============================================================================

@test "G6: unknown checkpoint exits 2" {
  run bash "$SCRIPT" measure nonexistent_checkpoint_xyz_abc
  [ "$status" -eq 2 ]
}

@test "G6: malformed YAML (missing files: key) exits 2" {
  cp "$FIXTURES_DIR/checkpoints/malformed.yml" "$FOOTPRINT_EVAL_DIR/malformed.yml"
  run bash "$SCRIPT" measure malformed
  [ "$status" -eq 2 ]
}

@test "G6: missing referenced file exits 2" {
  cp "$FIXTURES_DIR/checkpoints/missing_file.yml" "$FOOTPRINT_EVAL_DIR/missing_file.yml"
  run bash "$SCRIPT" measure missing_file
  [ "$status" -eq 2 ]
}

@test "G6: --check with no baseline.json exits 2" {
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 2 ]
}

@test "G6: --check with corrupted baseline.json exits 2" {
  cp "$FIXTURES_DIR/baselines/corrupted.json" "$FOOTPRINT_EVAL_DIR/baseline.json"
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 2 ]
}

@test "G6: error messages go to stderr not stdout" {
  run --separate-stderr bash "$SCRIPT" measure nonexistent_checkpoint_xyz_abc
  [ "$status" -eq 2 ]
  # stdout should be empty on error; error text must be on stderr
  [ -z "$output" ]
  echo "$stderr" | grep -qi 'error\|not found'
}

@test "G6: --check without checkpoint name and missing baseline exits 2" {
  run bash "$SCRIPT" --check
  [ "$status" -eq 2 ]
}

# =============================================================================
# G7: E2E regression + AC2 static checks + AC6 static check
# =============================================================================

@test "G7: E2E -- bloated file triggers regression (exit 1)" {
  local e2e_dir="$BATS_TEST_TMPDIR/evals_e2e/footprint"
  mkdir -p "$e2e_dir"
  cp "$FIXTURES_DIR/e2e/bloated.yml" "$e2e_dir/bloated.yml"
  # baseline: 10 bytes; bloated_file.txt = 11001 bytes -> 11001 > 10*1.10=11 -> REGRESSION
  cat > "$e2e_dir/baseline.json" <<'JSON'
{"bloated":{"checkpoint":"bloated","total_bytes":10,"estimated_tokens":3,"files":[],"updated_at":"2026-01-01T00:00:00Z"}}
JSON
  FOOTPRINT_EVAL_DIR="$e2e_dir" run bash "$SCRIPT" --check bloated
  [ "$status" -eq 1 ]
}

@test "G7: E2E -- normal file passes regression check after --update" {
  local e2e_dir="$BATS_TEST_TMPDIR/evals_e2e2/footprint"
  mkdir -p "$e2e_dir"
  cp "$FIXTURES_DIR/e2e/normal.yml" "$e2e_dir/normal.yml"
  FOOTPRINT_EVAL_DIR="$e2e_dir" bash "$SCRIPT" --update normal
  FOOTPRINT_EVAL_DIR="$e2e_dir" run bash "$SCRIPT" --check normal
  [ "$status" -eq 0 ]
}

@test "G7: E2E -- full cycle: --update then --check passes" {
  run bash "$SCRIPT" --update simple
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --check simple
  [ "$status" -eq 0 ]
}

# AC2 static checks
@test "AC2: evals/footprint/session-start.yml exists" {
  [ -f "$REPO_ROOT/evals/footprint/session-start.yml" ]
}

@test "AC2: evals/footprint/autopilot.yml exists" {
  [ -f "$REPO_ROOT/evals/footprint/autopilot.yml" ]
}

@test "AC2: all paths in session-start.yml files: list resolve to real files" {
  local yml="$REPO_ROOT/evals/footprint/session-start.yml"
  [ -f "$yml" ]
  local in_files=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^files: ]]; then
      in_files=1
      continue
    fi
    if [[ $in_files -eq 1 ]]; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
        local path="${BASH_REMATCH[1]}"
        [ -f "$REPO_ROOT/$path" ] || { echo "Missing: $path" >&2; return 1; }
      elif [[ "$line" =~ ^[^[:space:]] && ! "$line" =~ ^[[:space:]]*- ]]; then
        in_files=0
      fi
    fi
  done < "$yml"
}

@test "AC2: evals/footprint/README.md documents YAML schema and distinguishes from behavioral eval" {
  [ -f "$REPO_ROOT/evals/footprint/README.md" ]
  grep -q 'files:' "$REPO_ROOT/evals/footprint/README.md"
  grep -qi 'behavioral.*pass_rate\|pass_rate.*eval\|behavioral.*eval' "$REPO_ROOT/evals/footprint/README.md"
}

# AC6 static check
@test "AC6: pr.yml paths-filter config category includes evals/**" {
  grep -q 'evals/\*\*' "$REPO_ROOT/.github/workflows/pr.yml"
}
