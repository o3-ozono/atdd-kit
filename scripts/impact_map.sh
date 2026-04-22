#!/usr/bin/env bash
# impact_map.sh — maps git diff to affected tests via path rules and @covers metadata
#
# Usage:
#   impact_map.sh --base <ref> --layer {L4|BATS}
#   impact_map.sh --all --layer {L4|BATS}
#   impact_map.sh --base <ref> --all --layer {L4|BATS}
#
# Options:
#   --base <ref>      git ref to diff against (required unless --all)
#   --layer <name>    test layer: L4 or BATS (required)
#   --all             force full scan (--base optional)
#   --config <path>   path to impact_rules.yml (default: $PWD/config/impact_rules.yml)
#
# Exit codes:
#   0 — success
#   1 — usage error (missing/invalid args)
#   2 — config parse error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

OPT_BASE=""
OPT_LAYER=""
OPT_ALL=0
OPT_CONFIG="${REPO_ROOT}/config/impact_rules.yml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)   OPT_BASE="$2";   shift 2 ;;
    --layer)  OPT_LAYER="$2";  shift 2 ;;
    --all)    OPT_ALL=1;       shift   ;;
    --config) OPT_CONFIG="$2"; shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done

# Validate --layer
if [[ -z "$OPT_LAYER" ]]; then
  echo "ERROR: --layer is required. Valid values: L4, BATS" >&2
  exit 1
fi

if [[ "$OPT_LAYER" != "L4" && "$OPT_LAYER" != "BATS" ]]; then
  echo "ERROR: invalid --layer '$OPT_LAYER'. Valid values: L4, BATS" >&2
  exit 1
fi

# Validate --base or --all
if [[ $OPT_ALL -eq 0 && -z "$OPT_BASE" ]]; then
  echo "ERROR: --base <ref> is required when --all is not specified" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# YAML parser for impact_rules.yml
# ---------------------------------------------------------------------------

# Parallel arrays populated by parse_impact_rules
path_globs=()
l4_targets=()
bats_tags=()

parse_impact_rules() {
  local yml="$1"

  if [[ ! -f "$yml" ]]; then
    echo "ERROR: config file not found: '$yml'" >&2
    exit 2
  fi

  local in_rules=0
  local has_rules_section=0
  local line_num=0

  while IFS= read -r line; do
    (( line_num++ )) || true
    # skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*#.*$ ]] && continue
    [[ -z "${line// }" ]] && continue

    if [[ "$line" == "rules:" ]]; then
      has_rules_section=1
      in_rules=1
      continue
    fi

    if [[ $in_rules -eq 1 ]]; then
      if [[ "$line" =~ ^"  - path: "(.+)$ ]]; then
        path_globs+=("${BASH_REMATCH[1]}")
        l4_targets+=("")
        bats_tags+=("")
        continue
      fi
      if [[ "$line" =~ ^"    l4: "(.+)$ ]]; then
        local idx=$(( ${#path_globs[@]} - 1 ))
        if [[ $idx -lt 0 ]]; then
          echo "ERROR: malformed YAML '$yml' — 'l4:' without preceding 'path:' at line $line_num" >&2
          exit 2
        fi
        l4_targets[$idx]="${BASH_REMATCH[1]}"
        continue
      fi
      if [[ "$line" =~ ^"    bats: "(.*)$ ]]; then
        local idx=$(( ${#path_globs[@]} - 1 ))
        if [[ $idx -lt 0 ]]; then
          echo "ERROR: malformed YAML '$yml' — 'bats:' without preceding 'path:' at line $line_num" >&2
          exit 2
        fi
        local raw_bats="${BASH_REMATCH[1]}"
        # strip surrounding YAML double-quotes if present
        if [[ "$raw_bats" =~ ^'"'(.*)'"'$ ]]; then
          raw_bats="${BASH_REMATCH[1]}"
        fi
        bats_tags[$idx]="$raw_bats"
        continue
      fi
      # top-level key (non-rules) resets in_rules
      if [[ "$line" =~ ^[a-zA-Z] ]]; then
        in_rules=0
      fi
    fi
  done < "$yml"

  if [[ $has_rules_section -eq 0 ]]; then
    echo "ERROR: malformed YAML '$yml' — missing 'rules:' section" >&2
    exit 2
  fi

  if [[ ${#path_globs[@]} -eq 0 ]]; then
    echo "ERROR: malformed YAML '$yml' — no rules entries found" >&2
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Get diff files from git
# ---------------------------------------------------------------------------

get_diff_files() {
  local base="$1"
  local git_out
  # capture stderr so invalid ref shows in our error, not raw git noise
  if ! git_out=$(git -C "$REPO_ROOT" diff --name-status --diff-filter=ACMRDT "${base}..HEAD" 2>&1); then
    echo "ERROR: failed to diff against '${base}'" >&2
    return 1
  fi
  printf '%s\n' "$git_out" \
    | awk -F'\t' '/^R/ { print $2; print $3; next } { print $2 }'
}

# ---------------------------------------------------------------------------
# Full layer test sets
# ---------------------------------------------------------------------------

get_all_l4() {
  local i
  for (( i=0; i<${#l4_targets[@]}; i++ )); do
    local val="${l4_targets[$i]}"
    [[ -z "$val" ]] && continue
    for name in $val; do
      printf '%s\n' "$name"
    done
  done | sort -u
}

get_all_bats() {
  find "$REPO_ROOT/tests" -name "*.bats" | sort
}

# ---------------------------------------------------------------------------
# @covers scanner
# ---------------------------------------------------------------------------

scan_covers() {
  local changed_file="$1"
  local bats_file
  while IFS= read -r bats_file; do
    local header
    header=$(head -n 5 "$bats_file")
    local matched=0
    while IFS= read -r cov_line; do
      [[ "$cov_line" =~ ^#[[:space:]]*@covers:[[:space:]]*(.+)$ ]] || continue
      local glob="${BASH_REMATCH[1]}"
      # bash fnmatch: exact path, prefix glob, or simple glob
      # shellcheck disable=SC2254
      if [[ "$changed_file" == $glob ]]; then
        matched=1
        break
      fi
    done <<< "$header"
    if [[ $matched -eq 1 ]]; then
      printf '%s\n' "$bats_file"
    fi
  done < <(find "$REPO_ROOT/tests" -name "*.bats")
}

# ---------------------------------------------------------------------------
# Path rule resolver
# ---------------------------------------------------------------------------

resolve_path_rules() {
  local changed_file="$1"
  local layer="$2"
  local i
  for (( i=0; i<${#path_globs[@]}; i++ )); do
    local g="${path_globs[$i]}"
    # shellcheck disable=SC2254
    if [[ "$changed_file" == $g ]]; then
      case "$layer" in
        L4)
          local name
          for name in ${l4_targets[$i]}; do
            printf '%s\n' "$name"
          done
          ;;
        BATS)
          local tag="${bats_tags[$i]}"
          [[ -z "$tag" ]] && continue
          # bats tag is "@covers <token>" — find matching bats files
          local token="${tag#@covers }"
          local bats_file
          while IFS= read -r bats_file; do
            local header
            header=$(head -n 5 "$bats_file")
            while IFS= read -r cov_line; do
              [[ "$cov_line" =~ ^#[[:space:]]*@covers:[[:space:]]*(.+)$ ]] || continue
              local cov="${BASH_REMATCH[1]}"
              if [[ "$cov" == "$token" || "$cov" == *"$token"* ]]; then
                printf '%s\n' "$bats_file"
                break
              fi
            done <<< "$header"
          done < <(find "$REPO_ROOT/tests" -name "*.bats")
          ;;
      esac
    fi
  done
}

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

# Load config (needed for full scan L4 too)
parse_impact_rules "$OPT_CONFIG"

# Full scan mode
if [[ $OPT_ALL -eq 1 ]]; then
  case "$OPT_LAYER" in
    L4)   get_all_l4  | sort -u ;;
    BATS) get_all_bats | sort -u ;;
  esac
  exit 0
fi

# Diff-based mode: run git diff in current shell so error propagates via set -e
_raw_diff=$(get_diff_files "$OPT_BASE")
diff_files=()
while IFS= read -r f; do
  [[ -n "$f" ]] && diff_files+=("$f")
done <<< "$_raw_diff"
unset _raw_diff

# Empty diff → empty stdout, exit 0
if [[ ${#diff_files[@]} -eq 0 ]]; then
  exit 0
fi

# Classify each diff file
unmatched=()
results=()

for f in "${diff_files[@]}"; do
  local_matched=0

  # Check path rules
  rule_results=$(resolve_path_rules "$f" "$OPT_LAYER")
  if [[ -n "$rule_results" ]]; then
    while IFS= read -r r; do
      results+=("$r")
    done <<< "$rule_results"
    local_matched=1
  fi

  # Check @covers (BATS layer only)
  if [[ "$OPT_LAYER" == "BATS" ]]; then
    cover_results=$(scan_covers "$f")
    if [[ -n "$cover_results" ]]; then
      while IFS= read -r r; do
        results+=("$r")
      done <<< "$cover_results"
      local_matched=1
    fi
  fi

  if [[ $local_matched -eq 0 ]]; then
    unmatched+=("$f")
  fi
done

# Fallback: any unmatched file triggers full scan
if [[ ${#unmatched[@]} -gt 0 ]]; then
  printf 'FALLBACK: unmatched files:\n' >&2
  for f in "${unmatched[@]}"; do
    printf '  %s\n' "$f" >&2
  done
  case "$OPT_LAYER" in
    L4)   get_all_l4  | sort -u ;;
    BATS) get_all_bats | sort -u ;;
  esac
  exit 0
fi

# Output union + dedup + sorted
if [[ ${#results[@]} -gt 0 ]]; then
  printf '%s\n' "${results[@]}" | sort -u
fi
