#!/usr/bin/env bash
# retrospective.sh -- Flow retrospective automation (#309)
#
# Usage:
#   retrospective.sh --issue <N> [--pr <PR>] [--dry-run] [--json-output] [--help]
#
# Arguments:
#   --issue <N>      Issue number (required unless --help)
#   --pr <PR>        PR number (optional; auto-detected via gh if omitted)
#   --dry-run        Print the retrospective report to stdout; do not append to
#                    docs/retrospective-log.jsonl or write retrospective.md
#   --json-output    Print only the JSONL record to stdout (for cross-cutting log)
#   --help           Print this usage message and exit 0
#
# Design constraints (CS-1):
#   - Zero LLM invocations (no claude binary, no Workflow)
#   - Zero blocking prompts (no read -p, no AskUserQuestion)
#   - Local aggregation completes within 5 seconds under stub gh
#
# Primary token sources (read-only):
#   - Headless worker output JSON: usage.input_tokens / usage.output_tokens / total_cost_usd
#   - autopilot-log.jsonl is NOT a token source (schema: iteration/step/verdict/fingerprint/timestamp)
#
# Friction primary sources (read-only):
#   - autopilot-log.jsonl verdict:"FAIL" entries for gate classification
#   - gh issue/pr comments (persistent signals only)
#
# No Auto-Routing: feedback candidates are listed only; no auto-filing.
set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
ISSUE_NUM=""
PR_NUM=""
DRY_RUN=false
JSON_OUTPUT=false

usage() {
  cat << 'EOF'
Usage: retrospective.sh --issue <N> [--pr <PR>] [--dry-run] [--json-output] [--help]

Generate a flow retrospective report for a completed Issue.

Options:
  --issue <N>      Issue number (required)
  --pr <PR>        PR number (optional; auto-detected if omitted)
  --dry-run        Print report to stdout; do not write files or append log
  --json-output    Print only the JSONL record to stdout
  --help           Print this help and exit

Design constraints (CS-1):
  - Zero LLM invocations (fully local, no network AI calls)
  - Zero blocking interactive prompts (fully non-interactive)
  - Local aggregation completes in 5 seconds or less under stub gh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)       ISSUE_NUM="${2:-}"; shift 2 ;;
    --pr)          PR_NUM="${2:-}"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --json-output) JSON_OUTPUT=true; shift ;;
    --help|-h)     usage; exit 0 ;;
    *)             echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$ISSUE_NUM" ]]; then
  echo "Error: --issue <N> is required." >&2
  usage
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: repo root detection
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Helper: safe integer extraction from a string (returns 0 on parse failure)
# ---------------------------------------------------------------------------
safe_int() {
  local val="${1:-}"
  # Extract first run of digits; return 0 if none found
  local n
  n=$(echo "$val" | grep -oE '^[0-9]+' | head -1)
  echo "${n:-0}"
}

# ---------------------------------------------------------------------------
# 1. Dialogue volume (turns) aggregation
# ---------------------------------------------------------------------------
# Primary source: ~/.claude/projects/<munged-cwd>/<session-id>.jsonl
# Counts type:"user" and type:"assistant" records
aggregate_turns() {
  local total_user=0 total_assistant=0
  local munged transcript_dir

  # Claude Code names the transcript dir by munging the cwd: leading dash KEPT,
  # and BOTH `/` and `.` converted to `-` (e.g. /Users/o3/github.com/x ->
  # -Users-o3-github-com-x). The prior transform stripped the leading dash and
  # left dots intact, so dotted paths (github.com) never resolved and turns=0 (#348).
  munged="$(echo "${REPO_ROOT}" | sed 's|[/.]|-|g')"
  transcript_dir="${HOME}/.claude/projects/${munged}"

  if [[ -d "$transcript_dir" ]]; then
    # One grep pass per record type across ALL transcripts (was 2 grep spawns
    # per file). On a real repo with hundreds of session logs the per-file loop
    # blew the CS-1 5s budget once the munged path started resolving (#348);
    # a single piped pass keeps it well under the limit. -o counts occurrences,
    # matching the prior per-line summation for one-record-per-line jsonl.
    local u a
    u=$(find "$transcript_dir" -maxdepth 2 -name "*.jsonl" -print0 2>/dev/null \
      | xargs -0 grep -hoE '"type":"user"' 2>/dev/null | wc -l | tr -d '[:space:]')
    a=$(find "$transcript_dir" -maxdepth 2 -name "*.jsonl" -print0 2>/dev/null \
      | xargs -0 grep -hoE '"type":"assistant"' 2>/dev/null | wc -l | tr -d '[:space:]')
    total_user=$(safe_int "$u")
    total_assistant=$(safe_int "$a")
  fi

  echo "turns: user=${total_user} assistant=${total_assistant} total=$(( total_user + total_assistant ))"
}

# Phase breakdown from autopilot-log.jsonl
# NOTE: autopilot-log.jsonl is used only for phase/step boundary signals, NOT for tokens.
aggregate_phases() {
  local found_log=""
  for f in "${REPO_ROOT}/docs/issues/${ISSUE_NUM}-"*/autopilot-log.jsonl; do
    [[ -f "$f" ]] && found_log="$f" && break
  done

  if [[ -n "$found_log" ]]; then
    local phases
    phases=$(grep -oE '"step":"[^"]*"' "$found_log" 2>/dev/null | sort | uniq -c | awk '{print $2, "x"$1}' || true)
    echo "phase breakdown: ${phases:-unknown}"
  else
    echo "phase breakdown: best-effort (autopilot-log.jsonl not found -- manual flow or not generated)"
  fi
}

# ---------------------------------------------------------------------------
# 2. Token cost aggregation (headless worker output JSON is the primary source)
# ---------------------------------------------------------------------------
# Primary: worker output JSON files containing total_cost_usd (usage.input_tokens / output_tokens)
# autopilot-log.jsonl schema = {iteration, step, verdict, fingerprint, timestamp} -- no tokens
aggregate_tokens() {
  local input_tokens=0 output_tokens=0 total_cost=""
  local found=false

  # Search headless worker output JSON files (contain total_cost_usd)
  local search_dirs=("${REPO_ROOT}" "${HOME}/.claude")

  for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
      if grep -q '"total_cost_usd"' "$f" 2>/dev/null; then
        local inp out cost
        inp=$(grep -oE '"input_tokens"[[:space:]]*:[[:space:]]*[0-9]+' "$f" 2>/dev/null | grep -oE '[0-9]+$' | head -1 || true)
        out=$(grep -oE '"output_tokens"[[:space:]]*:[[:space:]]*[0-9]+' "$f" 2>/dev/null | grep -oE '[0-9]+$' | head -1 || true)
        cost=$(grep -oE '"total_cost_usd"[[:space:]]*:[[:space:]]*[0-9.]+' "$f" 2>/dev/null | grep -oE '[0-9.]+$' | head -1 || true)
        input_tokens=$(( input_tokens + $(safe_int "$inp") ))
        output_tokens=$(( output_tokens + $(safe_int "$out") ))
        total_cost="${cost:-}"
        found=true
      fi
    done < <(find "$dir" -maxdepth 3 -name "*.json" -print0 2>/dev/null)
  done

  if $found; then
    echo "tokens: input=${input_tokens} output=${output_tokens} total=$(( input_tokens + output_tokens )) cost_usd=${total_cost:-unknown}"
  else
    echo "tokens: best-effort (headless worker log not found -- interactive session or log absent)"
  fi
}

# ---------------------------------------------------------------------------
# 3. PR diff lines (for normalization)
# ---------------------------------------------------------------------------
get_pr_diff_lines() {
  local pr="${1:-}"

  if [[ -z "$pr" ]]; then
    # Auto-detect most recently merged PR for this issue; gh output varies by stub
    local gh_out
    gh_out=$(gh pr list --state merged --search "is:merged" 2>/dev/null | head -1 || true)
    pr=$(echo "$gh_out" | grep -oE '^[0-9]+' | head -1 || true)
  fi

  if [[ -n "$pr" ]]; then
    # Fetch PR JSON (--json flag) and extract additions/deletions via jq
    local pr_json additions deletions
    pr_json=$(gh pr view "$pr" --json additions,deletions 2>/dev/null || true)
    additions=$(echo "$pr_json" | jq -r '.additions // empty' 2>/dev/null | head -1 || true)
    deletions=$(echo "$pr_json" | jq -r '.deletions // empty' 2>/dev/null | head -1 || true)
    local a_int d_int total
    a_int=$(safe_int "$additions")
    d_int=$(safe_int "$deletions")
    total=$(( a_int + d_int ))
    echo "diff: pr=${pr} additions=${a_int} deletions=${d_int} total=${total}"
  else
    echo "diff: best-effort (PR not found or gh unavailable)"
  fi
}

# ---------------------------------------------------------------------------
# 4. Friction points (gate rejections) extraction
# ---------------------------------------------------------------------------
# Primary persistent sources (read-only):
#   (a) autopilot-log.jsonl -- verdict:"FAIL" entries for gate step classification
#   (b) gh issue view / gh pr view comments -- persistent signals from all channels
# Note: transient in-memory variables are not accessible post-Workflow completion.
extract_friction() {
  local req_friction="" design_friction="" impl_friction="" merge_friction=""

  # (a) autopilot-log.jsonl verdict:"FAIL"
  for f in "${REPO_ROOT}/docs/issues/${ISSUE_NUM}-"*/autopilot-log.jsonl; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line; do
      if echo "$line" | grep -q '"verdict":"FAIL"'; then
        local step step_lc
        step=$(echo "$line" | grep -oE '"step":"[^"]*"' | grep -oE '"[^"]*"$' | tr -d '"')
        # bash 3.2 (macOS default) has no ${var,,}; lowercase via tr for portability.
        step_lc=$(printf '%s' "$step" | tr '[:upper:]' '[:lower:]')
        # Map each flow-skill step to its phase/gate bucket (#348). The design
        # steps (extracting-user-stories / writing-plan-and-tests) converge before
        # the design gate; running-atdd-cycle is impl-phase (a non-gate inner loop);
        # merge-family steps map to the merge gate. The prior default catch-all
        # dumped every unmatched step (incl. extracting-user-stories & running-atdd-cycle)
        # into merge, polluting the merge bucket. Non-gate steps now go to `impl`.
        case "$step_lc" in
          *req*|*defin*|*require*) req_friction="${req_friction:+$req_friction,}${step}" ;;
          *design*|*plan*|*writing*|*user-stor*) design_friction="${design_friction:+$design_friction,}${step}" ;;
          *atdd*|*cycle*) impl_friction="${impl_friction:+$impl_friction,}${step}" ;;
          *merge*|*deploy*|*review*) merge_friction="${merge_friction:+$merge_friction,}${step}" ;;
          *) impl_friction="${impl_friction:+$impl_friction,}${step}" ;;
        esac
      fi
    done < "$f"
  done

  # (b) Issue/PR comments via gh (persistent signal, read-only)
  local issue_comment_count=0 pr_comment_count=0
  local ic pc
  ic=$(gh issue view "${ISSUE_NUM}" --comments 2>/dev/null | grep -icE 'reject|deny|needs.revision|差し戻し' || true)
  issue_comment_count=$(safe_int "$ic")
  # PR comments are a persistent friction signal too (design send-back / merge hand-off
  # remarks land on the PR under the all-channel-sync convention). AT-309-6 Given (b).
  if [[ -n "${PR_NUM:-}" ]]; then
    pc=$(gh pr view "${PR_NUM}" --comments 2>/dev/null | grep -icE 'reject|deny|needs.revision|差し戻し' || true)
    pr_comment_count=$(safe_int "$pc")
  fi

  local total_comment_count=$(( issue_comment_count + pr_comment_count ))
  local gate_note=""
  [[ "$total_comment_count" -gt 0 ]] && gate_note="(${total_comment_count} rejection-related comments found)"

  echo "friction: requirements=${req_friction:-none} design=${design_friction:-none} impl=${impl_friction:-none} merge=${merge_friction:-none} ${gate_note}"
}

# ---------------------------------------------------------------------------
# 5. Feedback candidates (No Auto-Routing -- listing only, no auto-filing)
# ---------------------------------------------------------------------------
list_feedback_candidates() {
  echo "feedback candidates: review friction points above and consider filing skill-fix Issues manually (no auto-routing)"
}

# ---------------------------------------------------------------------------
# Main aggregation
# ---------------------------------------------------------------------------
turns_info="$(aggregate_turns)"
phase_info="$(aggregate_phases)"
token_info="$(aggregate_tokens)"
pr_info="$(get_pr_diff_lines "${PR_NUM:-}")"
friction_info="$(extract_friction)"
candidates_info="$(list_feedback_candidates)"

# Extract numeric values for JSONL
_extract_val() {
  # _extract_val "key=VAL ..." "key" -- returns empty string if not found (always exits 0)
  local result
  result=$(echo "${1:-}" | grep -oE "${2}=[^[:space:]]+" | head -1 | cut -d= -f2 || true)
  echo "${result:-}"
}

pr_num_val="${PR_NUM:-}"
if [[ -z "$pr_num_val" ]]; then
  pr_num_val="$(_extract_val "$pr_info" "pr")"
fi

token_input="$(_extract_val "$token_info" "input")"
token_output="$(_extract_val "$token_info" "output")"
diff_total="$(_extract_val "$pr_info" "total")"

# Normalized ratio (tokens / diff lines)
normalized_ratio="null"
if [[ -n "$token_input" ]] && [[ -n "$token_output" ]] && [[ -n "$diff_total" ]] && [[ "$diff_total" -gt 0 ]]; then
  normalized_ratio=$(echo "scale=2; (${token_input} + ${token_output}) / ${diff_total}" | bc 2>/dev/null || echo "null")
fi

# ---------------------------------------------------------------------------
# JSON output mode (for cross-cutting JSONL append)
# ---------------------------------------------------------------------------
if $JSON_OUTPUT; then
  pr_json_val="${pr_num_val:-null}"
  [[ "$pr_json_val" =~ ^[0-9]+$ ]] || pr_json_val="null"
  inp_json="${token_input:-null}"
  [[ "$inp_json" =~ ^[0-9]+$ ]] || inp_json="null"
  out_json="${token_output:-null}"
  [[ "$out_json" =~ ^[0-9]+$ ]] || out_json="null"
  diff_json="${diff_total:-null}"
  [[ "$diff_json" =~ ^[0-9]+$ ]] || diff_json="null"

  printf '{"issue":%s,"pr":%s,"tokens":{"input":%s,"output":%s},"diff_lines":%s,"normalized_ratio":%s,"friction":"%s","feedback_candidates":"%s"}\n' \
    "${ISSUE_NUM}" "${pr_json_val}" "${inp_json}" "${out_json}" "${diff_json}" \
    "${normalized_ratio}" \
    "$(echo "$friction_info" | tr '"' "'")" \
    "$(echo "$candidates_info" | tr '"' "'")"
  exit 0
fi

# ---------------------------------------------------------------------------
# Human-readable report (--dry-run: stdout only; default: write file)
# ---------------------------------------------------------------------------
DATE_STR="$(date '+%Y-%m-%d')"
REPORT="# Retrospective: Issue #${ISSUE_NUM}

<!-- Auto-generated by scripts/retrospective.sh on ${DATE_STR} -->

## Dialogue Volume (Turns)

${turns_info}
${phase_info}

## Token Cost

${token_info}

## Previous-Run Comparison (Normalized)

${pr_info}
Normalized ratio: ${normalized_ratio} tokens/diff-line

## Friction Points (Gate Classifications)

${friction_info}

## Improvement Candidates (skill-fix Candidates)

${candidates_info}
"

if $DRY_RUN; then
  printf '%s\n' "$REPORT"
  exit 0
fi

# Write to issue directory
local_issue_dir=""
for d in "${REPO_ROOT}/docs/issues/${ISSUE_NUM}-"*/; do
  [[ -d "$d" ]] && local_issue_dir="$d" && break
done

if [[ -n "$local_issue_dir" ]]; then
  printf '%s\n' "$REPORT" > "${local_issue_dir}/retrospective.md"
  echo "Retrospective written to: ${local_issue_dir}/retrospective.md"
else
  echo "Warning: docs/issues/${ISSUE_NUM}-*/ not found. Printing to stdout." >&2
  printf '%s\n' "$REPORT"
fi

# Append to cross-cutting JSONL (append-only)
pr_json_val="${pr_num_val:-null}"
[[ "$pr_json_val" =~ ^[0-9]+$ ]] || pr_json_val="null"
inp_json="${token_input:-null}"
[[ "$inp_json" =~ ^[0-9]+$ ]] || inp_json="null"
out_json="${token_output:-null}"
[[ "$out_json" =~ ^[0-9]+$ ]] || out_json="null"
diff_json="${diff_total:-null}"
[[ "$diff_json" =~ ^[0-9]+$ ]] || diff_json="null"

JSONL_FILE="${REPO_ROOT}/docs/retrospective-log.jsonl"
printf '{"issue":%s,"pr":%s,"tokens":{"input":%s,"output":%s},"diff_lines":%s,"normalized_ratio":%s,"friction":"%s","feedback_candidates":"%s"}\n' \
  "${ISSUE_NUM}" "${pr_json_val}" "${inp_json}" "${out_json}" "${diff_json}" \
  "${normalized_ratio}" \
  "$(echo "$friction_info" | tr '"' "'")" \
  "$(echo "$candidates_info" | tr '"' "'")" \
  >> "${JSONL_FILE}"

echo "Appended to: ${JSONL_FILE}"
