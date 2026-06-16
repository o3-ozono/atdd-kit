> **Loaded by:** `autopilot` skill (FS-2 loader-split — content moved from `skills/autopilot/SKILL.md` ## Responsibility Boundary, #304).

# autopilot — Role Map and Responsibility Boundary

## Responsibility Boundary

Each concern in the autopilot convergence loop has a single owner:

| Concern | Owner |
|---------|-------|
| Looping the flow skills to the satisfaction oracle | **autopilot** (this skill) |
| Each artifact's generation | the flow skills (unchanged) |
| The review verdict | reviewing-deliverables (single-pass primitive) |
| Requirements approval / design approval / merge (the three User gates) | the human |
| Parallel-session conflict, `in-progress` label | skill-gate |

autopilot **does not** permanently change the flow skills, **does not** approve its own requirements or design, and **does not** merge — merging is the User gate (AL-1).

For the full Iron Law (AL-1…AL-6) that constrains the above, see `docs/methodology/autopilot-iron-law.md`.
