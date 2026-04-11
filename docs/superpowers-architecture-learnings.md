# Architectural Learnings from superpowers (Future Work)

Reference: Issue #82

These patterns from [obra/superpowers](https://github.com/obra/superpowers) require deeper design work before implementation. They are documented here as future candidates.

## 1. Fresh Subagent Per Task (Item #15)

**Pattern:** When implementing multiple ACs, dispatch a fresh subagent for each AC. No context carryover between ACs prevents implementation bias.

**Current state:** autopilot (Dev) runs atdd in a single session for all ACs.

**Design considerations:**
- Requires Task tool or Agent tool per AC
- Controller must curate context (Issue body, AC, plan, target files) per dispatch
- Review subagents (spec compliance, code quality) also get fresh context
- Risk: increased token usage vs. benefit of isolation

**When to implement:** When AC count per Issue routinely exceeds 3 and cross-contamination becomes observable.

## 2. Integration Tests for Skills (Item #17)

**Pattern:** Execute real Claude Code sessions in headless mode, parse `.jsonl` transcripts, verify skill chains fired correctly.

**Current state:** BATS tests verify skill structure. auto-eval runs skill-creator evals. No end-to-end session verification.

**Design considerations:**
- `claude --headless` with controlled prompts
- Parse transcript for: Skill tool invocations, correct ordering, gate enforcement
- Token cost per integration test run (~10-30 min per test)
- CI integration: run on skill-changing PRs only

**When to implement:** After skill eval coverage reaches 80%+ across core skills.

## 3. CI-Enforced Eval Blocking (Item #18)

**Pattern:** Skill changes that drop pass_rate by 10%+ are automatically blocked in CI.

**Current state:** autopilot (QA) triggers auto-eval and blocks merge manually. No CI pipeline enforcement.

**Design considerations:**
- GitHub Actions workflow that runs auto-eval on `skills/*/SKILL.md` changes
- Compare against committed `baseline.json`
- Block merge via required status check
- Cost: each eval run requires Claude API calls

**When to implement:** When the project has a CI pipeline (GitHub Actions).

## 4. Parallel Subagent Execution (Item #24)

**Pattern:** When multiple independent ACs exist, dispatch parallel subagents for simultaneous implementation.

**Current state:** ACs are implemented sequentially in the atdd skill.

**Design considerations:**
- Only safe when ACs touch different files (no shared state)
- Requires dependency analysis from plan skill
- Merge conflicts between parallel branches
- Token cost multiplier

**When to implement:** When Issue complexity regularly involves 4+ independent ACs touching separate modules.
