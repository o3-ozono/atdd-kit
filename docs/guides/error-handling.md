# Error Handling Rules

> **Loaded by:** autopilot (Dev), atdd

When an error occurs, **do not jump to a workaround.**

## Steps

1. **Quick investigation** -- Read the error message carefully. Check official docs and GitHub Issues for known solutions.
2. **Parallel deep investigation** -- Spawn multiple investigation sub-agents to research the cause and explore alternatives in parallel.
3. **Present to user** -- If the straightforward fix doesn't work, present findings and alternatives to the user for approval.

## Prohibited

- Jumping to an alternative implementation the moment you see an error
- Applying a workaround without identifying the root cause
- Changing approach without reporting to the user
