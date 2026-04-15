#!/usr/bin/env bash
# measure-footprint.sh — static context/token footprint measurement for atdd-kit checkpoints
#
# Usage:
#   measure-footprint.sh measure <name>          Measure checkpoint, output JSON
#   measure-footprint.sh --check [<name>]        Check regression vs baseline (default: all)
#   measure-footprint.sh --update [<name>]       Update baseline (default: all)
#   measure-footprint.sh --compute-tokens <n>    Print ceil(n/3.6) — test helper
#
# Environment:
#   FOOTPRINT_EVAL_DIR   Override evals/footprint directory (used by tests)
#
# Exit codes:
#   0 — success / PASS
#   1 — REGRESSION
#   2 — error (unknown checkpoint / malformed YAML / missing file / bad baseline)
#
# YAML format (pure-bash, no external tools):
#   files:
#     - repo/root/relative/path.md
#   dynamic:                         (optional)
#     sub_name:
#       script: scripts/foo.sh
#       args:
#         - arg1
#         - arg2
#
# baseline.json format (one entry per line inside top-level object):
#   {
#     "checkpoint": {"total_bytes": N, "estimated_tokens": N, "updated_at": "ISO8601"},
#     ...
#   }
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Single override env var — tests set FOOTPRINT_EVAL_DIR to a temp path
EVAL_DIR="${FOOTPRINT_EVAL_DIR:-${REPO_ROOT}/evals/footprint}"
BASELINE_FILE="${EVAL_DIR}/baseline.json"

# ---------------------------------------------------------------------------
# Math helper
# ---------------------------------------------------------------------------

compute_tokens() {
  local bytes="$1"
  awk -v b="$bytes" 'BEGIN { x = b / 3.6; t = int(x); print (t < x) ? t+1 : t }'
}

# ---------------------------------------------------------------------------
# Pure-bash YAML parser
#
# Supports:
#   files:\n  - path          -> files_list array
#   dynamic:\n  key:\n    script: ...\n    args:\n      - arg
#
# Caller must declare arrays before calling parse_yaml:
#   files_list, dyn_keys, dyn_scripts, dyn_args (parallel arrays)
# ---------------------------------------------------------------------------

parse_yaml() {
  local yml="$1"
  local section="" dyn_key="" in_args=0
  local dyn_idx=-1

  while IFS= read -r line; do
    # Top-level sections
    if [[ "$line" == "files:" ]]; then
      section="files"; in_args=0; continue
    fi
    if [[ "$line" == "dynamic:" ]]; then
      section="dynamic"; in_args=0; continue
    fi

    case "$section" in
      files)
        if [[ "$line" =~ ^"  - "(.*) ]]; then
          files_list+=("${BASH_REMATCH[1]}")
        fi
        ;;
      dynamic)
        # Sub-key line: "  key:" (2-space indent, name, colon, nothing else)
        if [[ "$line" =~ ^"  "([A-Za-z0-9_-]+)":"$ ]]; then
          dyn_key="${BASH_REMATCH[1]}"
          dyn_keys+=("$dyn_key")
          dyn_scripts+=("")
          dyn_args+=("")
          dyn_idx=$(( ${#dyn_keys[@]} - 1 ))
          in_args=0
          continue
        fi
        # script: value
        if [[ "$line" =~ ^"    script: "(.*) ]]; then
          dyn_scripts[$dyn_idx]="${BASH_REMATCH[1]}"
          in_args=0
          continue
        fi
        # args: (start of args list)
        if [[ "$line" == "    args:" ]]; then
          in_args=1
          continue
        fi
        # arg item
        if [[ $in_args -eq 1 && "$line" =~ ^"      - "(.*) ]]; then
          local arg="${BASH_REMATCH[1]}"
          if [[ -z "${dyn_args[$dyn_idx]}" ]]; then
            dyn_args[$dyn_idx]="$arg"
          else
            # tab-delimited to avoid space ambiguity in paths
            dyn_args[$dyn_idx]="${dyn_args[$dyn_idx]}	$arg"
          fi
        fi
        ;;
    esac
  done < "$yml"
}

# ---------------------------------------------------------------------------
# Measure a single checkpoint
# ---------------------------------------------------------------------------

do_measure() {
  local name="$1"
  local yml="${EVAL_DIR}/${name}.yml"

  if [[ ! -f "$yml" ]]; then
    echo "ERROR: checkpoint '${name}' not found: ${yml}" >&2
    exit 2
  fi

  local files_list=()
  local dyn_keys=() dyn_scripts=() dyn_args=()
  parse_yaml "$yml"

  # Must have at least files: or dynamic: content
  if [[ ${#files_list[@]} -eq 0 && ${#dyn_keys[@]} -eq 0 ]]; then
    echo "ERROR: malformed YAML '${yml}' — no files: or dynamic: section" >&2
    exit 2
  fi

  # Measure static files
  local total_bytes=0
  local files_json="["
  local first=1

  for f in "${files_list[@]}"; do
    local abs="${REPO_ROOT}/${f}"
    if [[ ! -f "$abs" ]]; then
      echo "ERROR: referenced file not found: ${abs}" >&2
      exit 2
    fi
    local b t
    b=$(wc -c < "$abs" | tr -d ' ')
    t=$(compute_tokens "$b")
    if [[ $first -eq 1 ]]; then
      files_json+="{\"path\": \"${f}\", \"bytes\": ${b}, \"tokens\": ${t}}"
      first=0
    else
      files_json+=", {\"path\": \"${f}\", \"bytes\": ${b}, \"tokens\": ${t}}"
    fi
    total_bytes=$(( total_bytes + b ))
  done
  files_json+="]"

  local total_tokens
  total_tokens=$(compute_tokens "$total_bytes")

  # Measure dynamic sub-checkpoints
  local dyn_json=""
  if [[ ${#dyn_keys[@]} -gt 0 ]]; then
    dyn_json=', "dynamic": {'
    local dfirst=1
    local i
    for (( i=0; i<${#dyn_keys[@]}; i++ )); do
      local dname="${dyn_keys[$i]}"
      local dscript="${dyn_scripts[$i]}"
      local dargs_str="${dyn_args[$i]}"

      # Split tab-delimited args
      local dargs=()
      if [[ -n "$dargs_str" ]]; then
        IFS=$'\t' read -ra dargs <<< "$dargs_str"
      fi

      local dbytes=0
      if [[ -n "$dscript" ]]; then
        local cmd_abs="${REPO_ROOT}/${dscript}"
        if [[ -f "$cmd_abs" ]]; then
          local tmp_out
          tmp_out=$(mktemp)
          if "${cmd_abs}" "${dargs[@]}" > "$tmp_out" 2>/dev/null; then
            dbytes=$(wc -c < "$tmp_out" | tr -d ' ')
          fi
          rm -f "$tmp_out"
        fi
      fi

      local dtokens
      dtokens=$(compute_tokens "$dbytes")

      if [[ $dfirst -eq 1 ]]; then
        dyn_json+="\"${dname}\": {\"bytes\": ${dbytes}, \"tokens\": ${dtokens}}"
        dfirst=0
      else
        dyn_json+=", \"${dname}\": {\"bytes\": ${dbytes}, \"tokens\": ${dtokens}}"
      fi
    done
    dyn_json+="}"
  fi

  printf '{"checkpoint": "%s", "total_bytes": %d, "estimated_tokens": %d, "files": %s%s}\n' \
    "$name" "$total_bytes" "$total_tokens" "$files_json" "$dyn_json"
}

# ---------------------------------------------------------------------------
# Baseline read/write
# ---------------------------------------------------------------------------

# Extract a numeric (possibly negative) field from baseline.json
# Supports both single-line and multi-line JSON format.
# baseline_get <checkpoint> <field>  ->  integer or empty string
baseline_get() {
  local cp="$1" field="$2"
  [[ -f "$BASELINE_FILE" ]] || return 0

  # Strategy: find the line with "cp": and scan forward until we find "field": N
  local in_block=0
  local val=""
  local depth=0

  while IFS= read -r line; do
    if [[ $in_block -eq 0 ]]; then
      # Look for the checkpoint key opening
      if printf '%s' "$line" | grep -q "\"${cp}\":"; then
        in_block=1
        depth=0
        # Count braces on this line
        local opens closes
        opens=$(printf '%s' "$line" | tr -cd '{' | wc -c | tr -d ' ')
        closes=$(printf '%s' "$line" | tr -cd '}' | wc -c | tr -d ' ')
        depth=$(( depth + opens - closes ))
        # Check if field is on same line
        if printf '%s' "$line" | grep -q "\"${field}\":"; then
          val=$(printf '%s' "$line" | sed "s/.*\"${field}\": *\(-*[0-9][0-9]*\).*/\1/")
          if ! printf '%s' "$val" | grep -q '"'; then
            echo "$val"
            return 0
          fi
        fi
        # depth=0 means single-line entry
        [[ $depth -le 0 ]] && in_block=0
      fi
    else
      # Inside the checkpoint block
      local opens closes
      opens=$(printf '%s' "$line" | tr -cd '{' | wc -c | tr -d ' ')
      closes=$(printf '%s' "$line" | tr -cd '}' | wc -c | tr -d ' ')
      depth=$(( depth + opens - closes ))

      if printf '%s' "$line" | grep -q "\"${field}\":"; then
        val=$(printf '%s' "$line" | sed "s/.*\"${field}\": *\(-*[0-9][0-9]*\).*/\1/")
        if ! printf '%s' "$val" | grep -q '"'; then
          echo "$val"
          return 0
        fi
      fi

      # Exit block when depth goes to 0 or below
      [[ $depth -le 0 ]] && in_block=0
    fi
  done < "$BASELINE_FILE"

  echo ""
}

# Write/update baseline.json for one checkpoint atomically (temp + rename, same FS)
# baseline_write <name> <measure_json>
baseline_write() {
  local name="$1"
  local mjson="$2"

  local tb et
  tb=$(printf '%s' "$mjson" | grep -o '"total_bytes": [0-9]*' | grep -o '[0-9]*$')
  et=$(printf '%s' "$mjson" | grep -o '"estimated_tokens": [0-9]*' | grep -o '[0-9]*$')

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Single-line entry
  local entry="  \"${name}\": {\"total_bytes\": ${tb}, \"estimated_tokens\": ${et}, \"updated_at\": \"${ts}\"}"

  mkdir -p "$(dirname "$BASELINE_FILE")"
  local tmp
  tmp=$(mktemp "${BASELINE_FILE}.XXXXXX")

  if [[ ! -f "$BASELINE_FILE" ]]; then
    printf '{\n%s\n}\n' "$entry" > "$tmp"
  else
    # Stream through existing file; replace matching line or append before }
    local found=0
    local buf=""
    while IFS= read -r raw; do
      if printf '%s' "$raw" | grep -q "\"${name}\":"; then
        # Preserve trailing comma if the original line had one (means more entries follow)
        if [[ "${raw: -1}" == "," ]]; then
          printf '%s,\n' "$entry" >> "$tmp"
        else
          printf '%s\n' "$entry" >> "$tmp"
        fi
        found=1
      else
        if [[ "$raw" == "}" && "$found" -eq 0 ]]; then
          # Append: add comma to previous non-empty line if needed
          if [[ -n "$buf" && "${buf: -1}" != "," && "$buf" != "{" ]]; then
            # rewrite last line with comma
            # truncate tmp by one line and rewrite it
            local lines
            lines=$(wc -l < "$tmp" | tr -d ' ')
            if [[ "$lines" -gt 0 ]]; then
              # Replace last line in tmp with buf+comma
              local tmp2
              tmp2=$(mktemp "${BASELINE_FILE}.XXXXXX")
              head -n $(( lines - 1 )) "$tmp" > "$tmp2"
              printf '%s,\n' "$buf" >> "$tmp2"
              mv "$tmp2" "$tmp"
            fi
          fi
          printf '%s\n' "$entry" >> "$tmp"
          printf '%s\n' "$raw" >> "$tmp"
          found=1
          buf="$raw"
          continue
        fi
        printf '%s\n' "$raw" >> "$tmp"
        buf="$raw"
      fi
    done < "$BASELINE_FILE"
  fi

  mv "$tmp" "$BASELINE_FILE"
}

# ---------------------------------------------------------------------------
# Check regression
# ---------------------------------------------------------------------------

do_check() {
  local name="$1"

  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "ERROR: baseline.json not found: ${BASELINE_FILE}" >&2
    exit 2
  fi

  # Basic corruption check: must start with {
  local first_char
  first_char=$(head -c1 "$BASELINE_FILE" 2>/dev/null | tr -d '[:space:]')
  if [[ "$first_char" != "{" ]]; then
    echo "ERROR: baseline.json corrupted (does not start with {)" >&2
    exit 2
  fi
  if ! grep -q '}' "$BASELINE_FILE" 2>/dev/null; then
    echo "ERROR: baseline.json corrupted (no closing })" >&2
    exit 2
  fi

  local cjson
  cjson=$(do_measure "$name")

  local cb ct
  cb=$(printf '%s' "$cjson" | grep -o '"total_bytes": [0-9]*' | grep -o '[0-9]*$')
  ct=$(printf '%s' "$cjson" | grep -o '"estimated_tokens": [0-9]*' | grep -o '[0-9]*$')

  local bb bt
  bb=$(baseline_get "$name" "total_bytes")
  bt=$(baseline_get "$name" "estimated_tokens")

  if [[ -z "$bb" || -z "$bt" ]]; then
    echo "ERROR: no baseline entry for checkpoint '${name}'" >&2
    exit 2
  fi

  local regression=0
  local reason=""
  local bytes_delta=$(( cb - bb ))
  local token_delta=$(( ct - bt ))

  # Percent threshold — skip when baseline_bytes == 0
  if [[ "$bb" -gt 0 ]]; then
    local over
    over=$(awk -v cb="$cb" -v bb="$bb" 'BEGIN { print (cb > bb * 1.10) ? 1 : 0 }')
    if [[ "$over" -eq 1 ]]; then
      regression=1
      local pct
      pct=$(awk -v cb="$cb" -v bb="$bb" 'BEGIN { printf "%.1f", (cb - bb) * 100.0 / bb }')
      reason="bytes +${pct}% > 10%"
    fi
  fi

  # Token threshold — strictly > 500
  if [[ "$token_delta" -gt 500 ]]; then
    regression=1
    reason="${reason:+${reason}; }token_delta +${token_delta} > 500"
  fi

  if [[ "$regression" -eq 1 ]]; then
    echo "REGRESSION: ${name}"
    echo "  current:  bytes=${cb} tokens=${ct}"
    echo "  baseline: bytes=${bb} tokens=${bt}"
    echo "  bytes_delta=${bytes_delta} tokens_delta=${token_delta}"
    echo "  reason: ${reason}"
    exit 1
  else
    echo "PASS: ${name} bytes=${cb} tokens=${ct} (baseline bytes=${bb} tokens=${bt})"
  fi
}

# ---------------------------------------------------------------------------
# List checkpoints
# ---------------------------------------------------------------------------

list_checkpoints() {
  local found=0
  for yml in "${EVAL_DIR}"/*.yml; do
    [[ -f "$yml" ]] || continue
    basename "$yml" .yml
    found=1
  done
  if [[ $found -eq 0 ]]; then
    echo "ERROR: no checkpoint YAMLs in ${EVAL_DIR}" >&2
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  echo "Usage: measure-footprint.sh <measure|--check|--update|--compute-tokens> [args]" >&2
  exit 2
fi

case "$1" in
  --compute-tokens)
    [[ $# -ge 2 ]] || { echo "Usage: --compute-tokens <bytes>" >&2; exit 2; }
    compute_tokens "$2"
    ;;

  measure)
    [[ $# -ge 2 ]] || { echo "Usage: measure <name>" >&2; exit 2; }
    do_measure "$2"
    ;;

  --check)
    if [[ $# -ge 2 && -n "${2:-}" ]]; then
      do_check "$2"
    else
      # No name — check all
      while IFS= read -r cp; do
        do_check "$cp"
      done < <(list_checkpoints)
    fi
    ;;

  --update)
    if [[ $# -ge 2 && -n "${2:-}" ]]; then
      mjson=$(do_measure "$2")
      baseline_write "$2" "$mjson"
      echo "Updated baseline for '${2}'"
    else
      # Update all
      while IFS= read -r cp; do
        mjson=$(do_measure "$cp")
        baseline_write "$cp" "$mjson"
        echo "Updated baseline for '${cp}'"
      done < <(list_checkpoints)
    fi
    ;;

  *)
    echo "ERROR: unknown command '${1}'" >&2
    exit 2
    ;;
esac
