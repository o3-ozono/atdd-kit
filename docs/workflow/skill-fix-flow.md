# skill-fix Flow Reference

## Overview

The `skill-fix` flow allows reporting atdd-kit skill defects during an active session without interrupting the current work. It launches a background subagent that creates a new Issue and drives it to `ready-to-go` by invoking `writing-plan-and-tests` with the `--skill-fix` flag (inline plan mode, quality gates retained).

## Strategy: β (background subagent, Skill-chain only)

The subagent runs with `isolation: worktree` + `run_in_background: true` and uses the **Skill tool chain only** — it does not use the Agent tool (see Spike Results below). Quality gates are retained throughout:

1. **Scope minimization**: the subagent only creates an Issue and runs the target skill plus `writing-plan-and-tests --skill-fix`.
2. **Audit trail**: every skill-fix-created Issue body carries a `<!-- skill-fix-audit: ... -->` marker.
3. **Quality gate retention**: MUST-1/2/3 + UX U1-U5 + Interruption I1-I4 all execute under `--skill-fix`.
4. **BLOCKED termination**: any gate FAIL → `blocked-ac` label + blocker comment, no `ready-to-go`.

## Trigger Conditions

| Path | Condition | Action |
|------|-----------|--------|
| Explicit | User runs `/atdd-kit:skill-fix` | Start interview immediately |
| Implicit | Message contains skill name + intent verb (both required) | Ask one confirmation question |

**Skill names**: defining-requirements / extracting-user-stories / writing-plan-and-tests / running-atdd-cycle / reviewing-deliverables / merging-and-deploying / bug / session-start

**Intent verbs**: 改善 / 修正 / バグ / おかしい / 直したい / fix / improve / broken / wrong

## Flow

```
(main session)
  └─ Phase 1: trigger detected → interview Q1/Q2/Q3
      └─ Phase 2: duplicate check (main session, 4-class)
          └─ Phase 3: parallel activity guard (inflight registry)
              └─ Phase 4: dispatch subagent (isolation: worktree, run_in_background: true)
                  ├─ (subagent) gh issue create → new issue <new_n>
                  ├─ (subagent) append audit marker
                  ├─ (subagent) run target skill → RED baseline or GREEN fallback
                  ├─ (subagent) post evidence comment
                  ├─ (subagent) /atdd-kit:writing-plan-and-tests <new_n> --skill-fix
                  │    ├─ quality gate PASS → gh issue edit <new_n> --add-label ready-to-go
                  │    └─ quality gate FAIL → blocked-ac label + blocker comment
                  └─ (subagent) exit
(main session resumes immediately — non-blocking)
  └─ Phase 5: at next phase boundary, check <new_n> labels → 1-line report
```

## Failure Path

When subagent exits FAILED/BLOCKED/timeout:

1. Main session reports at next phase boundary: `skill-fix dispatch failed: #N (phase=<last_phase>) / link: <URL>`
2. `gh issue comment <new_n>` posts `failed: <reason>` (distinct from `blocked-ac`)
3. Subagent handles worktree cleanup before exit

## Env Contract (Spike-verified)

| Variable | Behavior | Spike Result |
|----------|----------|--------------|
| `ATDD_AUTOPILOT_WORKTREE` | **NOT inherited** (subagent uses its own isolated worktree path) | unset |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Inherited | `1` |
| `GH_TOKEN` | Inherited | set |
| `PWD` | Subagent's isolated worktree | agent-XXXXXXXX |

## Spike Results

The following was observed in an isolated worktree with `run_in_background: true` + `isolation: worktree`:

### (i) run_in_background: true completion notification
- **OK** — `<task-notification>` delivered to main session on next turn

### (ii) Nested Agent tool spawn
- **BLOCKED** — Agent tool not present in child agent's tool set (structural absence, no workaround)
- This is why a nested-Agent strategy was abandoned and the Skill-chain-only β strategy was adopted

### (iii) env inheritance behavior
- `ATDD_AUTOPILOT_WORKTREE`: **unset** (child worktree path used instead)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`: `1` (inherited)
- `GH_TOKEN`: set (inherited)
- `PWD`: child agent's isolated worktree (`agent-ad280666`)

### (iv) Next-turn message delivery
- **OK** — completion result delivered on next turn as `<task-notification>`

## Audit Marker Regex

```
^<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #[0-9]+ at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z -->$
```

## Related Files

| File | Role |
|------|------|
| `skills/skill-fix/SKILL.md` | Main skill definition |
| `commands/skill-fix.md` | Explicit invocation entry |
| `lib/skill_fix_dispatch.sh` | Shell functions: dispatch, inflight registry, env, cleanup |
| `templates/workflow/blocked_ac_comment.md` | Blocker comment template |
| `skills/writing-plan-and-tests/SKILL.md` | Invoked with `--skill-fix` (inline plan mode, quality gates retained) |

## Known Limitations

### Inflight Registry Race Condition (deferred)

The inflight registry (`lib/skill_fix_dispatch.sh`) uses a file-based approach with 1-entry-per-line format. Within a single session this is safe (sequential dispatch). However, the following are **out of scope** and deferred to a follow-up Issue:

1. **Atomic RMW**: `register_inflight` uses `>>` append (safe for concurrent appends) but `deregister_inflight` uses `sed -i` (non-atomic under concurrent delete). A `flock`-based wrapper would eliminate the race.
2. **Exact-match query**: `query_inflight` uses `grep "\"skill\": \"${skill}\""` which is exact-match on the field value. The surrounding JSON structure (1 entry per line) prevents prefix collisions.

**Design rationale for deferral**: skill-fix is triggered interactively in a single session; the inflight check → dispatch sequence is synchronous. True parallel dispatch from the same session requires the user to simultaneously complete two separate 3-question interviews, which is not a realistic use case.

**Follow-up scope**: `flock`-based atomic RMW + parallel bats test harness.
