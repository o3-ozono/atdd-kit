---
description: "Set up CI workflow by composing base workflow with addon CI fragments."
---

# setup-ci — CI Workflow Setup

Generates `.github/workflows/pr.yml` by composing the base CI workflow with addon-specific job fragments.

## Steps

### Step 1: Read Base Workflow

Read `${CLAUDE_PLUGIN_ROOT}/templates/ci/base.yml` — this provides the platform-agnostic structure (changes detection, ci-gate).

### Step 2: Read Addon CI Fragments

Read `.claude/workflow-config.yml` to get the `platform` list. For each platform:

1. Check if `${CLAUDE_PLUGIN_ROOT}/addons/<platform>/ci/` exists
2. Read the CI job fragment (e.g., `addons/ios/ci/build-and-test.yml`)

### Step 3: Compose Workflow

Merge the base workflow with addon fragments:

1. Insert addon job definitions into the `jobs:` section (between `changes` and `ci-gate`)
2. Update `ci-gate.needs` to include all addon job names (e.g., `[changes, build-and-test]`)
3. If no addons have CI fragments, the base workflow is used as-is

### Step 4: Write Output

Write the composed workflow to `.github/workflows/pr.yml`.

### Step 5: Summary

```
CI workflow generated:
- Base: templates/ci/base.yml
- Addons: [list of addon CI fragments included]
- Output: .github/workflows/pr.yml
```
