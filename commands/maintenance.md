---
description: "On-demand rule and documentation health check. Creates or updates a maintenance Issue."
---

# Maintenance Command

On-demand health check of CLAUDE.md, rules, and documentation freshness. Creates or updates a maintenance Issue.

## Step 1: Gather Metrics

1. `wc -l < CLAUDE.md` → warn if > 150 lines
2. `find .claude/rules -name "*.md" -exec cat {} + 2>/dev/null | wc -l` → warn if total > 300 lines
3. For each `.md` in `docs/`, `CLAUDE.md`, `.claude/rules/`: `git log -1 --format="%cs" -- <file>`. Age > 90 days → stale list.
4. Read `MEMORY.md` (if exists), list potentially outdated entries.

## Step 2: Generate Issue Body

Format the results as a maintenance Issue body:

```markdown
## Maintenance Check (on-demand)

This Issue was created by `/atdd-kit:maintenance`.

> **Rationale:** [Evaluating AGENTS.md (ETH Zurich, 2026)](https://arxiv.org/abs/2602.11988) reports that context file bloat reduces success rates by 2-3% and increases inference costs by 20%+. "Write only the minimum essential information" is the only effective approach.

### 1. Pruning

**Litmus test: "If I delete this line, will Claude make a mistake?" — If No, delete it.**

| File | Lines | Recommended Limit | Status |
|------|-------|-------------------|--------|
| CLAUDE.md | [count] | 150 | [status] |
| .claude/rules/ total | [count] | — | — |
| **Total** | **[total]** | **300** | [status] |

**Deletion criteria (based on research):**
- Lines that explicitly state what Claude does by default → **Delete** (no effect, wastes tokens)
- Descriptions duplicated in docs/ or skills → **Delete** (duplication is harmful)
- Repository overview / directory structure descriptions → **Delete** (no effect on code discovery)
- Generic coding conventions (Claude already knows) → **Delete**

**Keep:**
- Project-specific tool requirements Claude cannot guess (xcodebuild flags, simulator names, etc.)
- Project-specific constraints (merge freezes, test-first rules, non-standard rules)
- Corrections for specific patterns Claude has gotten wrong

**Checklist:**
- [ ] Apply litmus test to every line of CLAUDE.md, delete unnecessary lines
- [ ] Check .claude/rules/ files for unnecessary/duplicate rules, delete if found
- [ ] MEMORY.md staleness check (delete entries irrelevant to current phase)
- [ ] Check for contradictions between rules (CLAUDE.md ↔ rules/ ↔ docs/process/)

### 2. Document Freshness (90+ days without update)

[stale file list or "None"]

- [ ] Review the stale files above and verify content matches current state
- [ ] Update if inconsistent, propose deletion if unnecessary

### Completion Criteria

Check all boxes above, then close this Issue.
If changes were made, commit before closing.
```

## Step 3: Create or Update Issue

`gh issue list --label "automated" --search "[Maintenance]" --state open --json number -q '.[0].number'`

- Found: `gh issue edit <number> --body-file`
- Not found: `gh issue create --title "[Maintenance] Rule and documentation health check" --label "automated,type:documentation" --body-file`

## Step 4: Report

Show summary (CLAUDE.md lines, rules total, stale file count, Issue number) in terminal.
