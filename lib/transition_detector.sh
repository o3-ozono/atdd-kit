#!/usr/bin/env bash
# transition_detector.sh -- detect whether an autopilot discover->AC Review
# Round transition was executed "same-turn" or "cross-turn" from a
# stream-json transcript.
#
# Issue #162 (regression of #83/#101).
#
# Usage:
#   bash lib/transition_detector.sh <transcript.jsonl> [--skill-name <name>]
#
#   --skill-name   Skill tool input.skill to look for (default: atdd-kit:discover)
#
# Behavior:
#   1. Reads a Claude Code `--output-format stream-json` transcript
#      (newline-delimited JSON).
#   2. Filters the session timeline to { assistant, user } messages whose
#      parent_tool_use_id is null (top-level, main Claude only). system,
#      rate_limit_event, and result entries are skipped.
#   3. Assigns a 1-based chronological index to each kept entry.
#   4. Finds the first assistant message that contains a tool_use with
#      name=="Skill" and input.skill=="<skill-name>".
#   5. Locates the immediately following user tool_result for that tool_use
#      (the "skill-result carrier"), and the assistant message that follows
#      that user message.
#   6. Counts Agent tool_use entries (name=="Agent") in that next assistant
#      message's content array.
#   6b. Aggregates tool_use names across ALL assistant messages from the
#       "next" one onward, stopping at the first user message that looks
#       like a real new user input (text-type content that does NOT start
#       with the runtime-injected skill-body marker "Base directory for
#       this skill:"). This handles headless `claude -p` mode where one
#       response turn is split across multiple assistant messages
#       (thinking + text + tool_use), with skill-body injection appearing
#       as an intervening user-text message that is NOT a real turn
#       boundary.
#   7. Emits a JSON object with the fields below to stdout and exits 0.
#
#   If the Skill tool_use is not found, emits an "error" JSON with
#   error == "skill_tool_use_not_found" and exits 2.
#
# Output JSON schema (stdout):
#   {
#     "skill_tool_use_id": "toolu_abc123" | null,
#     "skill_result_user_msg_index": <int> | null,
#     "next_assistant_msg_index": <int> | null,
#     "next_assistant_tool_uses": ["Agent","Agent",...],
#     "aggregated_tool_uses": ["Agent","Agent",...],
#     "same_turn_spawn": <bool>,
#     "intervening_user_msgs": <int>,
#     "error": "<code>"         # only present on failure
#   }
#
# Exit codes:
#   0 — success (same-turn or cross-turn both produce JSON output)
#   1 — usage error (missing argument, unreadable file, invalid option)
#   2 — parse error or target Skill tool_use not found
#
# Dependencies: bash, jq.

set -euo pipefail

SCRIPT_NAME="transition_detector.sh"
DEFAULT_SKILL="atdd-kit:discover"

usage() {
  echo "Usage: bash lib/${SCRIPT_NAME} <transcript.jsonl> [--skill-name <name>]" >&2
}

INPUT=""
SKILL_NAME="$DEFAULT_SKILL"

while [ $# -gt 0 ]; do
  case "$1" in
    --skill-name)
      shift
      [ $# -gt 0 ] || { usage; exit 1; }
      SKILL_NAME="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -z "$INPUT" ]; then
        INPUT="$1"
      else
        echo "ERROR: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$INPUT" ]; then
  usage
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "ERROR: input file not found: $INPUT" >&2
  exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

# Step 1-3: build the filtered timeline as a JSON array.
# - Keep only type ∈ {assistant, user} with parent_tool_use_id null.
# - Assign 1-based chronological index.
# - For each entry, record: idx, type, content (array), and any Agent / Skill
#   tool_uses with their ids.
timeline=$(jq -s -c '
  [ .[]
    | select(.type == "assistant" or .type == "user")
    | select((.parent_tool_use_id // null) == null)
  ]
  | to_entries
  | map(
      .value as $v
      | {
          idx: (.key + 1),
          type: $v.type,
          content: ($v.message.content // [])
        }
    )
' "$INPUT") || {
  echo "ERROR: failed to parse transcript: $INPUT" >&2
  exit 2
}

if [ -z "$timeline" ] || [ "$timeline" = "null" ]; then
  timeline='[]'
fi

# Step 4: find the first Skill tool_use with input.skill == $SKILL_NAME
# in any assistant message.
skill_hit=$(jq -c --arg skill "$SKILL_NAME" '
  [ .[] | select(.type == "assistant") as $msg
    | $msg.content[]?
    | select(.type == "tool_use" and .name == "Skill")
    | select(.input.skill == $skill)
    | { tool_use_id: .id, assistant_idx: $msg.idx }
  ]
  | .[0] // null
' <<< "$timeline")

if [ -z "$skill_hit" ] || [ "$skill_hit" = "null" ]; then
  # Skill tool_use not found.
  jq -c -n --arg err "skill_tool_use_not_found" --arg skill "$SKILL_NAME" '
    {
      skill_tool_use_id: null,
      skill_result_user_msg_index: null,
      next_assistant_msg_index: null,
      next_assistant_tool_uses: [],
      aggregated_tool_uses: [],
      same_turn_spawn: false,
      intervening_user_msgs: 0,
      error: $err,
      skill_searched: $skill
    }
  '
  exit 2
fi

skill_tool_use_id=$(jq -r '.tool_use_id' <<< "$skill_hit")
skill_assistant_idx=$(jq -r '.assistant_idx' <<< "$skill_hit")

# Step 5: find the user tool_result message carrying this tool_use_id,
# and the assistant message that follows it in the filtered timeline.
# We also count intervening user messages between the skill assistant message
# and the carrier user message (normally 0 or 1 — just the tool_result itself).
#
# Output:
#   skill_result_user_msg_index   — index of the user msg carrying tool_result
#   next_assistant_msg_index      — index of the first assistant msg after that
#   next_assistant_content        — the content array of that assistant msg
#   intervening_user_msgs         — user msgs strictly between next_assistant_msg
#                                    and the carrier (should be 0 in same-turn case)
context=$(jq -c --arg tid "$skill_tool_use_id" --argjson sidx "$skill_assistant_idx" '
  # Find the user message that carries tool_result with this tool_use_id.
  . as $tl
  | [ $tl[] | select(.type == "user")
      | select(.content[]? | (.type? == "tool_result" and .tool_use_id? == $tid))
      | .idx
    ] as $carriers
  | ($carriers[0] // null) as $carrier_idx
  | if $carrier_idx == null then
      {
        skill_result_user_msg_index: null,
        next_assistant_msg_index: null,
        next_assistant_content: [],
        aggregated_tool_uses: [],
        intervening_user_msgs: 0
      }
    else
      # Find the first assistant msg with idx > $carrier_idx.
      ([ $tl[] | select(.type == "assistant") | select(.idx > $carrier_idx) ] | .[0]) as $next_asst
      | if $next_asst == null then
          {
            skill_result_user_msg_index: $carrier_idx,
            next_assistant_msg_index: null,
            next_assistant_content: [],
            aggregated_tool_uses: [],
            intervening_user_msgs: 0
          }
        else
          # Find the next real user input (text-type, not runtime-injected
          # skill-body) AFTER $next_asst. This bounds the "current response
          # turn" in headless mode where one response is split across
          # multiple assistant messages with auto-injected user msgs
          # (skill body, parallel-tool interleaves) between them.
          ([ $tl[] | select(.type == "user")
             | select(.idx > $next_asst.idx)
             | select(
                 (.content[0]? // null) as $c
                 | $c != null
                 and ($c.type? == "text")
                 and ((($c.text // "") | startswith("Base directory for this skill:")) | not)
               )
             | .idx
           ] | sort | .[0] // null) as $turn_end_idx
          | (if $turn_end_idx == null then 999999999 else $turn_end_idx end) as $turn_end
          | ([ $tl[] | select(.type == "assistant")
               | select(.idx >= $next_asst.idx and .idx < $turn_end)
             ]) as $turn_assistants
          | {
            skill_result_user_msg_index: $carrier_idx,
            next_assistant_msg_index: $next_asst.idx,
            next_assistant_content: $next_asst.content,
            aggregated_tool_uses:
              [ $turn_assistants[].content[]?
                | select(.type == "tool_use") | .name ],
            intervening_user_msgs:
              ([ $tl[] | select(.type == "user")
                 | select(.idx > $carrier_idx and .idx < $next_asst.idx)
               ] | length)
          }
        end
    end
' <<< "$timeline")

# Step 6: count Agent tool_use in next assistant message content (legacy
# field, single-msg view) and aggregated across all assistant msgs in the
# current response turn (new field, multi-msg view for headless mode).
tool_uses=$(jq -c '
  .next_assistant_content
  | [ .[] | select(.type == "tool_use") | .name ]
' <<< "$context")

aggregated_tool_uses=$(jq -c '.aggregated_tool_uses // []' <<< "$context")

agent_uses_aggregated=$(jq -c '[ .[] | select(. == "Agent") ]' <<< "$aggregated_tool_uses")
agent_count_aggregated=$(jq 'length' <<< "$agent_uses_aggregated")

skill_result_user_msg_index=$(jq -r '.skill_result_user_msg_index' <<< "$context")
next_assistant_msg_index=$(jq -r '.next_assistant_msg_index' <<< "$context")
intervening_user_msgs=$(jq -r '.intervening_user_msgs' <<< "$context")

# Step 7: same_turn_spawn is true iff aggregated Agent tool_uses across the
# current response turn (bounded by the next real user input that is NOT a
# runtime-injected skill body) is >= 1. The legacy delta == 1 check was
# dropped because in headless mode skill execution injects a "Base directory
# for this skill:" user-text message between the tool_result carrier and
# the model's next assistant message, making delta naturally 2 even when
# the spawn is functionally same-turn.
same_turn=false
if [ "$next_assistant_msg_index" != "null" ] && [ "$skill_result_user_msg_index" != "null" ]; then
  if [ "$agent_count_aggregated" -ge 1 ]; then
    same_turn=true
  fi
fi

# Emit the final JSON.
jq -c -n \
  --arg tid "$skill_tool_use_id" \
  --argjson sidx "${skill_result_user_msg_index}" \
  --argjson nidx "${next_assistant_msg_index}" \
  --argjson tu "$tool_uses" \
  --argjson agg "$aggregated_tool_uses" \
  --argjson st "$same_turn" \
  --argjson iu "$intervening_user_msgs" '
  {
    skill_tool_use_id: $tid,
    skill_result_user_msg_index: $sidx,
    next_assistant_msg_index: $nidx,
    next_assistant_tool_uses: $tu,
    aggregated_tool_uses: $agg,
    same_turn_spawn: $st,
    intervening_user_msgs: $iu
  }
'

exit 0
