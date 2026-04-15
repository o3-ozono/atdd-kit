#!/usr/bin/env bats

# =============================================================================
# Footprint Eval Tests — AC1-AC7
# Covers: happy path / math / baseline lifecycle / threshold / dynamic /
#         error cases / E2E regression
# =============================================================================

SCRIPT="./scripts/measure-footprint.sh"
FIXTURES_DIR="./tests/fixtures/footprint"

setup() {
  # Use a temp dir for baseline.json to avoid polluting evals/footprint/baseline.json
  export FOOTPRINT_BASELINE_DIR="${BATS_TEST_TMPDIR}/baseline"
  mkdir -p "${FOOTPRINT_BASELINE_DIR}"

  # Copy checkpoint YAML into temp dir with the name the script expects (<name>.yml)
  export FOOTPRINT_EVALS_DIR="${BATS_TEST_TMPDIR}/evals"
  mkdir -p "${FOOTPRINT_EVALS_DIR}"
  cp "${FIXTURES_DIR}/simple/checkpoint.yml" "${FOOTPRINT_EVALS_DIR}/simple.yml"

  # Ensure cache-first-run is an empty directory (git doesn't track empty dirs)
  mkdir -p "${FIXTURES_DIR}/dynamic/cache-first-run"
}

# ---------------------------------------------------------------------------
# Group 1: Happy path — AC1 measure produces correct JSON schema
# ---------------------------------------------------------------------------

@test "G1: measure outputs checkpoint key in JSON" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"checkpoint"'
}

@test "G1: measure outputs total_bytes key in JSON" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"total_bytes"'
}

@test "G1: measure outputs estimated_tokens key in JSON" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens"'
}

@test "G1: measure outputs files array in JSON" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"files"'
}

@test "G1: measure returns correct total_bytes for simple fixture (11 bytes)" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"total_bytes": 11'
}

@test "G1: measure returns estimated_tokens=4 for 11 bytes (ceil(11/3.6)=4)" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"estimated_tokens": 4'
}

@test "G1: measure includes per-file path in files array" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"path"'
}

@test "G1: exit 0 on success" {
  run "${SCRIPT}" measure simple
  [ "$status" -eq 0 ]
}

@test "G1: exit 2 on unknown checkpoint" {
  run "${SCRIPT}" measure nonexistent-checkpoint-xyz
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Group 2: Math — tokens = ceil(bytes / 3.6) at 4 boundaries
# ---------------------------------------------------------------------------

@test "G2: 0 bytes -> 0 tokens" {
  run "${SCRIPT}" --compute-tokens 0
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "G2: 3 bytes -> 1 token (ceil(3/3.6)=1)" {
  run "${SCRIPT}" --compute-tokens 3
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "G2: 4 bytes -> 2 tokens (ceil(4/3.6)=2)" {
  run "${SCRIPT}" --compute-tokens 4
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

@test "G2: 360 bytes -> 100 tokens (ceil(360/3.6)=100, exact)" {
  run "${SCRIPT}" --compute-tokens 360
  [ "$status" -eq 0 ]
  [ "$output" -eq 100 ]
}

# ---------------------------------------------------------------------------
# Group 3: Baseline lifecycle — --update writes atomically; --check never modifies
# ---------------------------------------------------------------------------

@test "G3: --update creates baseline.json" {
  run "${SCRIPT}" --update simple
  [ "$status" -eq 0 ]
  [ -f "${FOOTPRINT_BASELINE_DIR}/baseline.json" ]
}

@test "G3: baseline.json contains checkpoint key after --update" {
  "${SCRIPT}" --update simple
  grep -q '"checkpoint"' "${FOOTPRINT_BASELINE_DIR}/baseline.json" || \
    grep -q '"simple"' "${FOOTPRINT_BASELINE_DIR}/baseline.json"
}

@test "G3: baseline.json contains updated_at ISO8601 field" {
  "${SCRIPT}" --update simple
  grep -q '"updated_at"' "${FOOTPRINT_BASELINE_DIR}/baseline.json"
}

@test "G3: --check does not modify baseline.json (checksum unchanged)" {
  "${SCRIPT}" --update simple
  local before
  before=$(md5sum "${FOOTPRINT_BASELINE_DIR}/baseline.json" 2>/dev/null || md5 -q "${FOOTPRINT_BASELINE_DIR}/baseline.json")
  "${SCRIPT}" --check simple || true
  local after
  after=$(md5sum "${FOOTPRINT_BASELINE_DIR}/baseline.json" 2>/dev/null || md5 -q "${FOOTPRINT_BASELINE_DIR}/baseline.json")
  [ "$before" = "$after" ]
}

@test "G3: --update uses atomic write (temp file not left behind)" {
  run "${SCRIPT}" --update simple
  [ "$status" -eq 0 ]
  # No .tmp or .XXXXXX files should remain in the baseline dir
  local leftover
  leftover=$(find "${FOOTPRINT_BASELINE_DIR}" -name "*.tmp" -o -name "baseline.json.*" 2>/dev/null | wc -l | tr -d ' ')
  [ "$leftover" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Group 4: Threshold (AC5) — boundaries, OR semantics, baseline=0
# ---------------------------------------------------------------------------

@test "G4: PASS when current equals baseline (no increase)" {
  "${SCRIPT}" --update simple
  run "${SCRIPT}" --check simple
  [ "$status" -eq 0 ]
}

@test "G4: REGRESSION exit 1 when bytes exceed +10% threshold" {
  # Create a baseline with a tiny byte count so +10% fires easily
  cat > "${FOOTPRINT_BASELINE_DIR}/baseline.json" << 'EOF'
{"simple":{"total_bytes":10,"estimated_tokens":3,"updated_at":"2026-01-01T00:00:00Z","files":[]}}
EOF
  # simple fixture has 11 bytes — 11 > 10*1.10=11.0 is NOT strictly >, need 12+ to trigger
  # So override fixture to force regression: inject a baseline of 9 bytes
  cat > "${FOOTPRINT_BASELINE_DIR}/baseline.json" << 'EOF'
{"simple":{"total_bytes":9,"estimated_tokens":3,"updated_at":"2026-01-01T00:00:00Z","files":[]}}
EOF
  # 11 > 9*1.10=9.9 => REGRESSION
  run "${SCRIPT}" --check simple
  [ "$status" -eq 1 ]
}

@test "G4: PASS when just below +10% threshold" {
  # baseline=10, current=11: 11 > 10*1.10=11.0 is false (not strictly >)
  cat > "${FOOTPRINT_BASELINE_DIR}/baseline.json" << 'EOF'
{"simple":{"total_bytes":10,"estimated_tokens":3,"updated_at":"2026-01-01T00:00:00Z","files":[]}}
EOF
  run "${SCRIPT}" --check simple
  # 11 > 11.0 is false => PASS (only token threshold matters)
  # token: ceil(11/3.6)=4, baseline=3, 4-3=1 <= 500 => PASS
  [ "$status" -eq 0 ]
}

@test "G4: REGRESSION exit 1 when tokens exceed +500 threshold (OR semantics)" {
  # baseline with 0 bytes / 0 tokens to test +500 token branch
  # but baseline_bytes=0 so percent is skipped; token delta = 4-0 = 4 <= 500 => PASS for fixture
  # Use artificially high baseline_tokens to test the >500 case from below:
  # Set baseline tokens very high then lower it (can't easily with fixture size)
  # Instead: set baseline estimated_tokens such that current-baseline > 500
  # current = 4 tokens, so baseline must be negative (impossible)
  # Real test: set baseline_tokens=-500 is impossible; test is structural
  # Use a large fixture instead — create temp file > 500*3.6=1800 bytes
  local big_file="${BATS_TEST_TMPDIR}/big.md"
  python3 -c "print('x' * 1801)" > "${big_file}" 2>/dev/null || \
    printf '%1801s' | tr ' ' 'x' > "${big_file}"
  cat > "${FOOTPRINT_EVALS_DIR}/bigtest.yml" << EOF
files:
  - ${big_file}
EOF
  cat > "${FOOTPRINT_BASELINE_DIR}/baseline.json" << 'EOF'
{"bigtest":{"total_bytes":1,"estimated_tokens":1,"updated_at":"2026-01-01T00:00:00Z","files":[]}}
EOF
  run "${SCRIPT}" --check bigtest
  # big_file ~ 1802 bytes; tokens = ceil(1802/3.6) = 501; 501-1=500 NOT >500, need 502+
  # Use 1803 bytes: ceil(1803/3.6)=501; 501-1=500 still not >500
  # Use 1805 bytes: ceil(1805/3.6)=502; 502-1=501 >500 => REGRESSION
  local big_file2="${BATS_TEST_TMPDIR}/big2.md"
  printf '%1805s' | tr ' ' 'x' > "${big_file2}"
  cat > "${FOOTPRINT_EVALS_DIR}/bigtest.yml" << EOF
files:
  - ${big_file2}
EOF
  run "${SCRIPT}" --check bigtest
  [ "$status" -eq 1 ]
}

@test "G4: baseline=0 bytes skips percent threshold; only token threshold applies" {
  cat > "${FOOTPRINT_BASELINE_DIR}/baseline.json" << 'EOF'
{"simple":{"total_bytes":0,"estimated_tokens":0,"updated_at":"2026-01-01T00:00:00Z","files":[]}}
EOF
  run "${SCRIPT}" --check simple
  # baseline_bytes=0 => skip percent; token delta = 4-0=4 <= 500 => PASS
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Group 5: Dynamic sub-checkpoint (AC3)
# ---------------------------------------------------------------------------

@test "G5: dynamic section in JSON when checkpoint has dynamic entries" {
  run "${SCRIPT}" measure session-start-fixture
  # Skip if session-start-fixture does not exist (we'll create it in Cycle 5)
  skip "Requires session-start-fixture with dynamic section — created in Cycle 5"
}

@test "G5: FIRST_RUN fixture captured in dynamic.first_run" {
  skip "Requires dynamic fixture setup — created in Cycle 5"
}

@test "G5: NO_UPDATE fixture captured in dynamic.no_update" {
  skip "Requires dynamic fixture setup — created in Cycle 5"
}

@test "G5: UPDATED fixture captured in dynamic.updated" {
  skip "Requires dynamic fixture setup — created in Cycle 5"
}

# ---------------------------------------------------------------------------
# Group 6: Error cases — exit 2
# ---------------------------------------------------------------------------

@test "G6: exit 2 on unknown checkpoint name" {
  run "${SCRIPT}" measure totally-unknown-checkpoint-xyz
  [ "$status" -eq 2 ]
}

@test "G6: exit 2 on malformed YAML (missing files: key)" {
  cat > "${FOOTPRINT_EVALS_DIR}/bad.yml" << 'EOF'
not_files:
  - something.md
EOF
  run "${SCRIPT}" measure bad
  [ "$status" -eq 2 ]
}

@test "G6: exit 2 on missing referenced file" {
  cat > "${FOOTPRINT_EVALS_DIR}/missing.yml" << 'EOF'
files:
  - this/file/does/not/exist.md
EOF
  run "${SCRIPT}" measure missing
  [ "$status" -eq 2 ]
}

@test "G6: exit 2 on missing baseline when --check is used" {
  run "${SCRIPT}" --check simple
  # No baseline.json exists in FOOTPRINT_BASELINE_DIR
  [ "$status" -eq 2 ]
}

@test "G6: exit 2 on corrupted baseline.json" {
  echo "not valid json {{{" > "${FOOTPRINT_BASELINE_DIR}/baseline.json"
  run "${SCRIPT}" --check simple
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Group 7: E2E regression — fixture grows past threshold -> --check exits 1
# ---------------------------------------------------------------------------

@test "G7: E2E -- small fixture passes, then grown fixture triggers regression" {
  # Establish baseline with small fixture (11 bytes)
  "${SCRIPT}" --update simple

  # Grow the fixture beyond +10% — add content to make it bigger than 11*1.10=12.1, so 13+ bytes
  # We'll create a 'grown' checkpoint that points to a bigger file
  local grown_file="${BATS_TEST_TMPDIR}/grown.md"
  printf '%013d\n' 0 > "${grown_file}"  # 14 chars + newline = 15 bytes
  cat > "${FOOTPRINT_EVALS_DIR}/grown.yml" << EOF
files:
  - ${grown_file}
EOF

  # Set baseline for 'grown' to 11 bytes (same as simple)
  # First measure 'grown', then set a lower baseline
  local current_bytes
  current_bytes=$(wc -c < "${grown_file}" | tr -d ' ')
  local lower_bytes=$(( current_bytes * 9 / 10 ))  # 90% of current = below threshold

  "${SCRIPT}" --update grown  # updates baseline with current value
  # Overwrite baseline with lower value to simulate regression
  cat > "${FOOTPRINT_BASELINE_DIR}/baseline.json" << EOF
{"grown":{"total_bytes":${lower_bytes},"estimated_tokens":3,"updated_at":"2026-01-01T00:00:00Z","files":[]}}
EOF

  run "${SCRIPT}" --check grown
  [ "$status" -eq 1 ]
}

@test "G7: regression output includes per-file bytes_delta" {
  local grown_file="${BATS_TEST_TMPDIR}/grown2.md"
  printf '%020d\n' 0 > "${grown_file}"  # 21 chars + newline = 22 bytes
  cat > "${FOOTPRINT_EVALS_DIR}/grown2.yml" << EOF
files:
  - ${grown_file}
EOF
  cat > "${FOOTPRINT_BASELINE_DIR}/baseline.json" << 'EOF'
{"grown2":{"total_bytes":1,"estimated_tokens":1,"updated_at":"2026-01-01T00:00:00Z","files":[]}}
EOF
  run "${SCRIPT}" --check grown2
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'bytes_delta\|delta'
}
