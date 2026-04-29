#!/usr/bin/env bash
# Verify GitHub Projects v2 Kanban Board setup for atdd-kit (#168)
#
# Automated verification for AC2 and AC5.
# AC1, AC3, AC4 require visual confirmation (screenshots).
#
# Usage: ./scripts/verify-project.sh <project-number>

set -euo pipefail

PROJECT_NUM="${1:?usage: verify-project.sh <project-number>}"
OWNER="o3-ozono"
REPO="o3-ozono/atdd-kit"
SCRUMBAN_DOC="docs/methodology/scrumban.md"
PASS=0
FAIL=0

pass() { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }

echo "=== verify-project.sh: Issue #168 AC2 + AC5 ==="
echo ""

# ---------------------------------------------------------------------------
# AC2: PROJECT_COUNT == OPEN_COUNT and required fields non-null
# ---------------------------------------------------------------------------
echo "--- AC2: Item count and required field coverage ---"

PROJECT_ITEMS_JSON=$(gh project item-list "$PROJECT_NUM" --owner "$OWNER" \
    --format json --limit 200)
PROJECT_COUNT=$(echo "$PROJECT_ITEMS_JSON" | jq '.items | length')

OPEN_COUNT=$(gh issue list --repo "$REPO" --state open --json number \
    --limit 200 | jq 'length')

if [ "$PROJECT_COUNT" -eq "$OPEN_COUNT" ]; then
    pass "AC2-a: PROJECT_COUNT ($PROJECT_COUNT) == OPEN_COUNT ($OPEN_COUNT)"
else
    fail "AC2-a: PROJECT_COUNT ($PROJECT_COUNT) != OPEN_COUNT ($OPEN_COUNT)"
fi

# Check for items missing Status, Skill, or Impact
# Use jq if/else to avoid set -e interference with subshell pipe
MISSING_FIELDS=$(echo "$PROJECT_ITEMS_JSON" | jq -r '
    .items[] |
    . as $item |
    {
        number: .content.number,
        status: (
            if (.fieldValues.nodes // [] | map(select(.field.name == "Status")) | length) > 0
            then "ok" else "MISSING" end
        ),
        skill: (
            if (.fieldValues.nodes // [] | map(select(.field.name == "Skill")) | length) > 0
            then "ok" else "MISSING" end
        ),
        impact: (
            if (.fieldValues.nodes // [] | map(select(.field.name == "Impact")) | length) > 0
            then "ok" else "MISSING" end
        )
    } |
    select(.status == "MISSING" or .skill == "MISSING" or .impact == "MISSING") |
    "#\(.number): status=\(.status) skill=\(.skill) impact=\(.impact)"
' 2>/dev/null || echo "")

if [ -z "$MISSING_FIELDS" ]; then
    pass "AC2-b: All items have non-null Status, Skill, and Impact"
else
    fail "AC2-b: Items with missing required fields:"
    echo "$MISSING_FIELDS" | while read -r line; do echo "       $line"; done
fi

# Check no Closed Issues in project
CLOSED_IN_PROJECT=$(echo "$PROJECT_ITEMS_JSON" | jq -r '
    .items[] | select(.content.state == "CLOSED") | "#\(.content.number)"
' 2>/dev/null || echo "")

if [ -z "$CLOSED_IN_PROJECT" ]; then
    pass "AC2-c: No Closed Issues in project"
else
    fail "AC2-c: Closed Issues found in project: $(echo "$CLOSED_IN_PROJECT" | tr '\n' ' ')"
fi

echo ""

# ---------------------------------------------------------------------------
# AC5: scrumban.md has GitHub Project section with URL / fields / mapping
# ---------------------------------------------------------------------------
echo "--- AC5: scrumban.md GitHub Project section ---"

# AC5-a: live Project URL
if grep -qE 'github\.com/users/o3-ozono/projects/[0-9]+' "$SCRUMBAN_DOC"; then
    PROJECT_URL=$(grep -oE 'https://github\.com/users/o3-ozono/projects/[0-9]+' "$SCRUMBAN_DOC" | head -1)
    # Verify URL is accessible
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token ${GH_TOKEN:-}" "$PROJECT_URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        pass "AC5-a: Project URL is accessible ($PROJECT_URL)"
    else
        fail "AC5-a: Project URL returned HTTP $HTTP_CODE ($PROJECT_URL)"
    fi
else
    fail "AC5-a: No Project URL found in $SCRUMBAN_DOC"
fi

# AC5-b: all 7 fields defined
REQUIRED_FIELDS=("Status" "Skill" "Phase" "Size" "Impact" "Epic" "Iteration")
for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -q "$field" "$SCRUMBAN_DOC"; then
        pass "AC5-b: Field '$field' documented in scrumban.md"
    else
        fail "AC5-b: Field '$field' NOT found in scrumban.md"
    fi
done

# Iteration must be noted as Web UI only
if grep -q 'Web UI' "$SCRUMBAN_DOC"; then
    pass "AC5-b: Iteration 'Web UI only' note present"
else
    fail "AC5-b: 'Web UI' note for Iteration not found"
fi

# AC5-c: Status↔label mapping with intentional gap
if grep -qi 'intentional gap\|Intentional gap' "$SCRUMBAN_DOC"; then
    pass "AC5-c: Intentional gap noted for Status↔label mapping"
else
    fail "AC5-c: 'intentional gap' not documented in scrumban.md"
fi

# GitHub Project section header
if grep -q '## GitHub Project' "$SCRUMBAN_DOC"; then
    pass "AC5: '## GitHub Project' section exists"
else
    fail "AC5: '## GitHub Project' section missing"
fi

# ---------------------------------------------------------------------------
# AC4: Iteration date ranges via GraphQL
# ---------------------------------------------------------------------------
echo ""
echo "--- AC4: Iteration field date ranges (GraphQL) ---"

ITER_JSON=$(gh api graphql -f query="
{
  user(login: \"$OWNER\") {
    projectV2(number: $PROJECT_NUM) {
      fields(first: 20) {
        nodes {
          ... on ProjectV2IterationField {
            name
            configuration {
              iterations {
                id
                title
                startDate
                duration
              }
            }
          }
        }
      }
    }
  }
}" 2>/dev/null || echo "{}")

ITER_COUNT=$(echo "$ITER_JSON" | jq -r '
    [.data.user.projectV2.fields.nodes[] | select(.name == "Iteration")] | length
' 2>/dev/null || echo "0")

if [ "$ITER_COUNT" -gt "0" ]; then
    pass "AC4: Iteration field found in project"
    echo "       Iteration options:"
    echo "$ITER_JSON" | jq -r '
        .data.user.projectV2.fields.nodes[] |
        select(.name == "Iteration") |
        .configuration.iterations[] |
        "         \(.title): startDate=\(.startDate) duration=\(.duration)d"
    ' 2>/dev/null || true
else
    fail "AC4: Iteration field not found — create via Web UI first"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL ==="
if [ "$FAIL" -eq 0 ]; then
    echo "All checks PASSED."
    exit 0
else
    echo "Some checks FAILED. Review output above."
    exit 1
fi
