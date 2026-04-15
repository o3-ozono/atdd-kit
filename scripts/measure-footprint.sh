#!/usr/bin/env bash
# Usage:
#   measure-footprint.sh measure <name>
#   measure-footprint.sh --check [<name>]
#   measure-footprint.sh --update [<name>]
#   measure-footprint.sh --compute-tokens <bytes>   (internal helper, also used by tests)
#
# Environment variables (override defaults for testing):
#   FOOTPRINT_EVALS_DIR    — directory containing <name>.yml files
#                            (default: evals/footprint relative to repo root)
#   FOOTPRINT_BASELINE_DIR — directory containing baseline.json
#                            (default: evals/footprint relative to repo root)
#
# Exit codes:
#   0 — success / PASS
#   1 — REGRESSION detected
#   2 — error (unknown checkpoint, malformed YAML, missing file, missing baseline, etc.)
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Determine repo root (directory containing this script's parent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default directories (overridable for tests)
EVALS_DIR="${FOOTPRINT_EVALS_DIR:-${REPO_ROOT}/evals/footprint}"
BASELINE_DIR="${FOOTPRINT_BASELINE_DIR:-${REPO_ROOT}/evals/footprint}"
BASELINE_FILE="${BASELINE_DIR}/baseline.json"

# Compute ceil(bytes / 3.6) using awk — POSIX, no bash floating point needed
# bash 3.2 compatible: no declare -A used anywhere in this script
compute_tokens() {
  local bytes="$1"
  awk "BEGIN { x = ${bytes} / 3.6; t = int(x); print (t < x) ? t+1 : t }"
}

# Pure-bash YAML parser for the flat schema:
#   files:
#     - path/to/file
#   dynamic:
#     - name: sub_name
#       cmd: script.sh
#       fixture: path/to/fixture
#       cache: path/to/cache
#
# Indentation: exactly 2 spaces for list items, 4 spaces for sub-keys
# No external YAML tool required.
parse_yaml() {
  local yml_file="$1"
  local section=""
  local current_name=""

  # Reset output arrays (caller must declare these before calling)
  # files_list: indexed array of file paths
  # dynamic_names / dynamic_fixtures / dynamic_caches: parallel arrays

  while IFS= read -r line; do
    case "$line" in
      "files:")
        section="files"
        ;;
      "dynamic:")
        section="dynamic"
        ;;
      "  - "*)
        local val="${line#  - }"
        if [[ "$section" == "files" ]]; then
          files_list+=("$val")
        fi
        ;;
      "    - "*)
        # nested list item under dynamic — reset current entry
        current_name=""
        ;;
      "    name: "*)
        current_name="${line#    name: }"
        dynamic_names+=("$current_name")
        dynamic_fixtures+=("")
        dynamic_caches+=("")
        dynamic_cmds+=("")
        ;;
      "    cmd: "*)
        if [[ -n "$current_name" && ${#dynamic_names[@]} -gt 0 ]]; then
          local idx=$(( ${#dynamic_names[@]} - 1 ))
          dynamic_cmds[$idx]="${line#    cmd: }"
        fi
        ;;
      "    fixture: "*)
        if [[ -n "$current_name" && ${#dynamic_names[@]} -gt 0 ]]; then
          local idx=$(( ${#dynamic_names[@]} - 1 ))
          dynamic_fixtures[$idx]="${line#    fixture: }"
        fi
        ;;
      "    cache: "*)
        if [[ -n "$current_name" && ${#dynamic_names[@]} -gt 0 ]]; then
          local idx=$(( ${#dynamic_names[@]} - 1 ))
          dynamic_caches[$idx]="${line#    cache: }"
        fi
        ;;
    esac
  done < "$yml_file"
}

# Build a JSON object for one file entry
file_json_entry() {
  local path="$1" bytes="$2" tokens="$3"
  printf '{"path": "%s", "bytes": %d, "tokens": %d}' "$path" "$bytes" "$tokens"
}

# Measure a single checkpoint and print JSON to stdout
do_measure() {
  local name="$1"
  local yml_file="${EVALS_DIR}/${name}.yml"

  if [[ ! -f "$yml_file" ]]; then
    echo "ERROR: checkpoint '${name}' not found (expected: ${yml_file})" >&2
    exit 2
  fi

  # Parse YAML
  local files_list=()
  local dynamic_names=() dynamic_fixtures=() dynamic_caches=() dynamic_cmds=()
  parse_yaml "$yml_file"

  # Validate: files: section must exist (even if empty is acceptable for dynamic-only checkpoints)
  # If both files and dynamic are empty, that's malformed
  if [[ ${#files_list[@]} -eq 0 && ${#dynamic_names[@]} -eq 0 ]]; then
    echo "ERROR: malformed YAML in '${yml_file}' — no 'files:' or 'dynamic:' section found" >&2
    exit 2
  fi

  # Measure files
  local total_bytes=0
  local files_json_parts=()

  for f in "${files_list[@]}"; do
    local abs_path="${REPO_ROOT}/${f}"
    if [[ ! -f "$abs_path" ]]; then
      echo "ERROR: referenced file not found: ${abs_path}" >&2
      exit 2
    fi
    local fbytes
    fbytes=$(wc -c < "$abs_path" | tr -d ' ')
    local ftokens
    ftokens=$(compute_tokens "$fbytes")
    files_json_parts+=("$(file_json_entry "$f" "$fbytes" "$ftokens")")
    total_bytes=$(( total_bytes + fbytes ))
  done

  local total_tokens
  total_tokens=$(compute_tokens "$total_bytes")

  # Build files JSON array
  local files_json="["
  local first=1
  for entry in "${files_json_parts[@]}"; do
    if [[ $first -eq 1 ]]; then
      files_json+="$entry"
      first=0
    else
      files_json+=", $entry"
    fi
  done
  files_json+="]"

  # Measure dynamic sub-checkpoints
  local dynamic_json=""
  if [[ ${#dynamic_names[@]} -gt 0 ]]; then
    dynamic_json=', "dynamic": {'
    local dfirst=1
    local i
    for (( i=0; i<${#dynamic_names[@]}; i++ )); do
      local dname="${dynamic_names[$i]}"
      local dfixture="${dynamic_fixtures[$i]}"
      local dcache="${dynamic_caches[$i]}"
      local dcmd="${dynamic_cmds[$i]}"

      # Build absolute paths
      local abs_fixture="${REPO_ROOT}/${dfixture}"
      local abs_cache="${REPO_ROOT}/${dcache}"

      # Run the dynamic command against fixture (capture stdout only)
      local stdout_bytes=0
      if [[ -n "$dcmd" ]]; then
        local cmd_path="${REPO_ROOT}/scripts/${dcmd}"
        if [[ -f "$cmd_path" ]]; then
          local tmp_out="${BATS_TEST_TMPDIR:-/tmp}/dynamic_out_${dname}_$$"
          if "${cmd_path}" "${abs_fixture}" "${abs_cache}" > "$tmp_out" 2>/dev/null; then
            stdout_bytes=$(wc -c < "$tmp_out" | tr -d ' ')
          fi
          rm -f "$tmp_out"
        fi
      fi

      local dtokens
      dtokens=$(compute_tokens "$stdout_bytes")

      if [[ $dfirst -eq 1 ]]; then
        dynamic_json+="\"${dname}\": {\"bytes\": ${stdout_bytes}, \"tokens\": ${dtokens}}"
        dfirst=0
      else
        dynamic_json+=", \"${dname}\": {\"bytes\": ${stdout_bytes}, \"tokens\": ${dtokens}}"
      fi
    done
    dynamic_json+="}"
  fi

  # Output JSON
  printf '{"checkpoint": "%s", "total_bytes": %d, "estimated_tokens": %d, "files": %s%s}\n' \
    "$name" "$total_bytes" "$total_tokens" "$files_json" "$dynamic_json"
}

# Read a value from baseline.json for a given checkpoint key
# Returns empty string if not found or file malformed
baseline_get() {
  local checkpoint="$1" key="$2"
  if [[ ! -f "$BASELINE_FILE" ]]; then
    return 0
  fi
  # Pure-bash extraction: look for "checkpoint": { ... "key": VALUE
  # Simple single-line grep approach — baseline.json is written by this script
  # so format is predictable (one JSON object per line would be ideal, but
  # we write pretty JSON with newlines — use grep + sed)
  local val
  # Extract the block for this checkpoint, then get the key
  # Strategy: find line with "checkpoint_name": { and scan until matching }
  val=$(awk -v cp="\"${checkpoint}\"" -v k="\"${key}\"" '
    BEGIN { found=0; depth=0 }
    found && /"'"${key}"'"/ {
      match($0, /: ?([0-9]+|"[^"]*")/, arr)
      gsub(/"/, "", arr[1])
      print arr[1]
      exit
    }
    $0 ~ cp { found=1 }
  ' "$BASELINE_FILE" 2>/dev/null || true)
  echo "$val"
}

# Write/update baseline.json for a checkpoint atomically
baseline_write() {
  local name="$1"
  local measure_json="$2"

  # Read existing baseline or start fresh
  local existing="{}"
  if [[ -f "$BASELINE_FILE" ]]; then
    existing=$(cat "$BASELINE_FILE")
  fi

  # Add updated_at timestamp
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build entry: merge measure_json with updated_at
  # measure_json ends with } — insert updated_at before closing brace
  local entry="${measure_json%\}}, \"updated_at\": \"${ts}\"}"

  # Merge into existing JSON
  # Use awk to inject the new checkpoint entry
  local new_json
  new_json=$(awk -v cp="\"${name}\"" -v entry="$entry" '
    BEGIN { inserted=0 }
    {
      if (!inserted && $0 ~ cp) {
        # Replace existing entry block — skip until matching }
        depth=0
        while ((getline line) > 0) {
          for (i=1; i<=length(line); i++) {
            c = substr(line,i,1)
            if (c == "{") depth++
            if (c == "}") {
              depth--
              if (depth < 0) break
            }
          }
          if (depth < 0) break
        }
        sub(cp ":", cp ": " entry ",", $0) || 1
        inserted=1
        print
        next
      }
      print
    }
  ' <<< "$existing" 2>/dev/null || echo "$existing")

  # If checkpoint not found in existing, inject it
  if ! echo "$new_json" | grep -q "\"${name}\""; then
    # Insert before last }
    new_json="${new_json%\}}  \"${name}\": ${entry}\n}"
    # Handle empty object
    if [[ "$existing" == "{}" ]]; then
      new_json="{\"${name}\": ${entry}}"
    fi
  fi

  # Atomic write: temp file in same directory + rename
  local tmp
  tmp=$(mktemp "${BASELINE_FILE}.XXXXXX")
  printf '%s\n' "$new_json" > "$tmp"
  mv "$tmp" "$BASELINE_FILE"
}

# Check regression for a checkpoint
do_check() {
  local name="$1"

  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "ERROR: baseline.json not found at ${BASELINE_FILE}" >&2
    exit 2
  fi

  # Validate baseline.json is not corrupted (basic check)
  if ! grep -q '{' "$BASELINE_FILE" 2>/dev/null; then
    echo "ERROR: baseline.json appears corrupted" >&2
    exit 2
  fi

  # Get current measurement
  local current_json
  current_json=$(do_measure "$name")

  # Extract current values
  local current_bytes current_tokens
  current_bytes=$(echo "$current_json" | grep -o '"total_bytes": [0-9]*' | grep -o '[0-9]*$')
  current_tokens=$(echo "$current_json" | grep -o '"estimated_tokens": [0-9]*' | grep -o '[0-9]*$')

  # Extract baseline values
  local baseline_bytes baseline_tokens
  baseline_bytes=$(baseline_get "$name" "total_bytes")
  baseline_tokens=$(baseline_get "$name" "estimated_tokens")

  if [[ -z "$baseline_bytes" || -z "$baseline_tokens" ]]; then
    echo "ERROR: no baseline entry found for checkpoint '${name}'" >&2
    exit 2
  fi

  # Compute regression
  local regression=0
  local reason=""

  # Percent threshold (skip if baseline_bytes == 0)
  if [[ "$baseline_bytes" -gt 0 ]]; then
    # Check: current_bytes > baseline_bytes * 1.10
    # Use awk for float comparison
    local over_percent
    over_percent=$(awk "BEGIN { print (${current_bytes} > ${baseline_bytes} * 1.10) ? 1 : 0 }")
    if [[ "$over_percent" -eq 1 ]]; then
      regression=1
      local pct
      pct=$(awk "BEGIN { printf \"%.1f\", (${current_bytes} - ${baseline_bytes}) * 100.0 / ${baseline_bytes} }")
      reason="bytes exceeded +10% threshold (+${pct}%)"
    fi
  fi

  # Token threshold: current_tokens - baseline_tokens > 500
  local token_delta=$(( current_tokens - baseline_tokens ))
  if [[ "$token_delta" -gt 500 ]]; then
    regression=1
    if [[ -n "$reason" ]]; then
      reason="${reason}; token delta +${token_delta} > 500"
    else
      reason="token delta +${token_delta} > 500"
    fi
  fi

  if [[ "$regression" -eq 1 ]]; then
    echo "REGRESSION: ${name} — ${reason}"
    echo "  current:  bytes=${current_bytes}, tokens=${current_tokens}"
    echo "  baseline: bytes=${baseline_bytes}, tokens=${baseline_tokens}"
    echo "  bytes_delta=$(( current_bytes - baseline_bytes )) tokens_delta=${token_delta}"
    exit 1
  else
    echo "PASS: ${name} — bytes=${current_bytes} tokens=${current_tokens} (baseline: bytes=${baseline_bytes} tokens=${baseline_tokens})"
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  echo "Usage: measure-footprint.sh <measure|--check|--update|--compute-tokens> [<name>|<bytes>]" >&2
  exit 2
fi

case "$1" in
  --compute-tokens)
    if [[ $# -lt 2 ]]; then
      echo "Usage: measure-footprint.sh --compute-tokens <bytes>" >&2
      exit 2
    fi
    compute_tokens "$2"
    exit 0
    ;;

  measure)
    if [[ $# -lt 2 ]]; then
      echo "Usage: measure-footprint.sh measure <name>" >&2
      exit 2
    fi
    do_measure "$2"
    ;;

  --check)
    if [[ $# -lt 2 ]]; then
      echo "Usage: measure-footprint.sh --check <name>" >&2
      exit 2
    fi
    do_check "$2"
    ;;

  --update)
    if [[ $# -lt 2 ]]; then
      echo "Usage: measure-footprint.sh --update <name>" >&2
      exit 2
    fi
    measure_json=$(do_measure "$2")
    baseline_write "$2" "$measure_json"
    echo "Updated baseline for '${2}'"
    ;;

  *)
    echo "ERROR: unknown command '$1'" >&2
    echo "Usage: measure-footprint.sh <measure|--check|--update|--compute-tokens> [args]" >&2
    exit 2
    ;;
esac
