# Autonomy Levels

> **Loaded by:** discover, autopilot (QA), workflow-detail

## Overview

Autonomy levels control how many approval gates a task passes through. Claude recommends a level based on Issue analysis; the user can override.

## Level Definitions

| Level | Name | Approval Points | Use Case |
|-------|------|----------------|----------|
| Level 0 | Full Control | All gates active (AC approval + plan review + user approval + merge approval) | Important design decisions, architectural changes |
| Level 1 | Guided | AC approval + merge approval only | Normal development |
| Level 2 | Autonomous | Merge approval only | High-confidence routine tasks |
| Level 3 | Full Auto | Fully automated (user retains revert right) | Documentation updates, typo fixes |

## Recommendation Criteria

| Signal | Level 0 | Level 1 | Level 2 | Level 3 |
|--------|---------|---------|---------|---------|
| Issue type | Architecture change, new feature with unclear scope | Normal development, feature enhancement | Bug fix with clear reproduction, config change | Documentation, typo, formatting |
| Complexity | Complex (5+ files, cross-cutting) | Medium (2-5 files, clear scope) | Simple (1-2 files, isolated) | Trivial (single file, no logic) |
| Risk | High (data loss, security, breaking change) | Medium | Low | Negligible |
| Precedent | No similar past work | Similar work exists | Well-established pattern | Mechanical change |

## Gate Adjustment by Level

| Gate | Level 0 | Level 1 | Level 2 | Level 3 |
|------|---------|---------|---------|---------|
| discover AC approval | Required | Required | Required | Auto-approve |
| plan review (Reviewer) | Required | Required | Auto-approve | Auto-approve |
| User approval (after plan review) | Required | Skip (auto-approve if R1-R6 PASS) | Skip | Skip |
| PR code review | Required | Required | Required | Auto-approve |
| Merge approval | Required | Required | Required | Auto-approve |

## Label Convention

Autonomy level is stored as an Issue label: `autonomy:0`, `autonomy:1`, `autonomy:2`, `autonomy:3`.

- Claude recommends a level during discover Step 0
- User can override at any time by changing the label
- If no label is set, Level 0 (Full Control) is assumed as default

## User Override

The user always retains the right to:
- Change the autonomy level label at any time
- Add `needs-plan-revision` to revert an auto-approved plan
- Revert any merged PR
