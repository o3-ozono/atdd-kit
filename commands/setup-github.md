---
description: "Set up GitHub issue templates, PR template, and labels for the project."
---

# setup-github — GitHub Project Setup

Sets up GitHub issue templates, PR template, and workflow labels.

## What This Command Does

1. Copy issue templates from plugin to `.github/ISSUE_TEMPLATE/`
2. Copy PR template to `.github/pull_request_template.md`
3. Create GitHub labels for the workflow state machine

## Steps

### Step 1: Copy Issue Templates

Copy from `${CLAUDE_PLUGIN_ROOT}/templates/issue/` to `.github/ISSUE_TEMPLATE/`:

| Source | Destination |
|--------|-------------|
| `templates/issue/en/development.yml` | `.github/ISSUE_TEMPLATE/development.yml` |
| `templates/issue/en/bug-report.yml` | `.github/ISSUE_TEMPLATE/bug-report.yml` |
| `templates/issue/en/research.yml` | `.github/ISSUE_TEMPLATE/research.yml` |
| `templates/issue/en/documentation.yml` | `.github/ISSUE_TEMPLATE/documentation.yml` |
| `templates/issue/en/refactoring.yml` | `.github/ISSUE_TEMPLATE/refactoring.yml` |
| `templates/issue/ja/development.yml` | `.github/ISSUE_TEMPLATE/development-ja.yml` |
| `templates/issue/ja/bug-report.yml` | `.github/ISSUE_TEMPLATE/bug-report-ja.yml` |
| `templates/issue/ja/research.yml` | `.github/ISSUE_TEMPLATE/research-ja.yml` |
| `templates/issue/ja/documentation.yml` | `.github/ISSUE_TEMPLATE/documentation-ja.yml` |
| `templates/issue/ja/refactoring.yml` | `.github/ISSUE_TEMPLATE/refactoring-ja.yml` |

### Step 2: Copy PR Template

Copy `${CLAUDE_PLUGIN_ROOT}/templates/pr/en/pull_request_template.md` to `.github/pull_request_template.md`.

### Step 3: Create Labels

```bash
gh label create "in-progress" --color "0E8A16" --force
gh label create "ready-to-implement" --color "1D76DB" --force
gh label create "ready-for-plan-review" --color "FBCA04" --force
gh label create "ready-for-user-approval" --color "D93F0B" --force
gh label create "ready-for-PR-review" --color "0075CA" --force
gh label create "needs-plan-revision" --color "E4E669" --force
gh label create "needs-pr-revision" --color "E4E669" --force
gh label create "type:development" --color "A2EEEF" --force
gh label create "type:bug" --color "D73A4A" --force
gh label create "type:documentation" --color "0075CA" --force
gh label create "type:research" --color "D4C5F9" --force
gh label create "refactoring" --color "BFDADC" --force
gh label create "implementing" --color "0E8A16" --force
```

### Step 4: Summary

```
GitHub setup complete:
- Issue templates: [count] files
- PR template: created
- Labels: 13 created
```
