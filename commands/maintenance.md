---
description: "On-demand rule and documentation health check. Creates or updates a maintenance Issue."
---

# Maintenance Command

Run an on-demand health check of CLAUDE.md, rules, and documentation freshness. Always creates or updates a maintenance Issue with the results.

## Step 1: Gather Metrics

### 1-1: CLAUDE.md Line Count

Count the number of lines in `CLAUDE.md`:

```bash
wc -l < CLAUDE.md
```

- If over 150 lines: status = "⚠ Over limit"
- Otherwise: status = "OK"

### 1-2: Rules Line Count

Count total lines across all `.md` files in `.claude/rules/`:

```bash
find .claude/rules -name "*.md" -exec cat {} + 2>/dev/null | wc -l
```

### 1-3: Total Line Count

Sum of CLAUDE.md + rules lines.

- If over 300 lines: status = "⚠ Over limit"
- Otherwise: status = "OK"

### 1-4: Staleness Detection (90+ days)

For each `.md` file in `docs/`, `CLAUDE.md`, and `.claude/rules/`:

1. Get the last commit date: `git log -1 --format="%cs" -- <file>`
2. Calculate age in days
3. If age > 90 days: add to stale list

### 1-5: MEMORY.md Staleness Check

Read `MEMORY.md` (if it exists in `.claude/` or the project memory directory) and list entries that may be outdated based on current project state.

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

1. Search for an existing open maintenance Issue:

```bash
gh issue list --label "automated" --search "[Maintenance]" --state open --json number -q '.[0].number'
```

2. If found: update the existing Issue body with `gh issue edit <number> --body-file`
3. If not found: create a new Issue with `gh issue create --title "[Maintenance] Rule and documentation health check" --label "automated,type:documentation" --body-file`

## Step 4: Report

Show the results in the terminal and report the Issue number:

```
Maintenance check complete.
- CLAUDE.md: [count] lines ([status])
- Rules total: [count] lines
- Total: [total] lines ([status])
- Stale files: [count]
- Issue: #[number] (created/updated)
```
