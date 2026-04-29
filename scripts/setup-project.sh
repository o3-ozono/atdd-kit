#!/usr/bin/env bash
# GitHub Projects v2 Kanban Board setup for atdd-kit (#168)
#
# Usage: ./scripts/setup-project.sh [--dry-run]
#
# IMPORTANT: Run Step 5 (item-add) and Step 6 (bulk-set) again just before
# PR merge to capture any Issues opened after initial setup.
#
# Prerequisites:
#   gh auth status must show project scope.
#   Run: gh auth refresh -s read:project,project
#   Or set GH_TOKEN with project scope in .claude/settings.local.json

set -euo pipefail

OWNER="o3-ozono"
REPO="o3-ozono/atdd-kit"
PROJECT_TITLE="atdd-kit"
DRY_RUN="${1:-}"

log() { echo "[setup-project] $*"; }
dry_run_echo() { echo "  [dry-run] $*"; }

# ---------------------------------------------------------------------------
# Step 0: Verify scope and detect existing project
# ---------------------------------------------------------------------------
log "Step 0: Checking gh auth scope..."
if ! gh auth status 2>&1 | grep -q 'project'; then
    echo "ERROR: 'project' scope missing. Run: gh auth refresh -s read:project,project"
    echo "Or update GH_TOKEN in .claude/settings.local.json with a PAT that has project scope."
    exit 1
fi

log "Checking for existing project '$PROJECT_TITLE'..."
# PROJECT_NUM = numeric number (for item-list, field-list, item-add)
# PROJECT_ID  = GraphQL node ID "PVT_xxx" (for item-edit --project-id)
PROJECT_NUM=$(gh project list --owner "$OWNER" --format json \
    | jq -r --arg t "$PROJECT_TITLE" '.projects[] | select(.title == $t) | .number' \
    | head -1)
PROJECT_ID=$(gh project list --owner "$OWNER" --format json \
    | jq -r --arg t "$PROJECT_TITLE" '.projects[] | select(.title == $t) | .id' \
    | head -1)

# ---------------------------------------------------------------------------
# Step 1: Create project if not exists
# ---------------------------------------------------------------------------
if [ -z "$PROJECT_NUM" ]; then
    log "Step 1: Creating project '$PROJECT_TITLE'..."
    if [ "$DRY_RUN" = "--dry-run" ]; then
        dry_run_echo "gh project create --owner $OWNER --title $PROJECT_TITLE"
    else
        gh project create --owner "$OWNER" --title "$PROJECT_TITLE"
        PROJECT_NUM=$(gh project list --owner "$OWNER" --format json \
            | jq -r --arg t "$PROJECT_TITLE" '.projects[] | select(.title == $t) | .number' \
            | head -1)
        PROJECT_ID=$(gh project list --owner "$OWNER" --format json \
            | jq -r --arg t "$PROJECT_TITLE" '.projects[] | select(.title == $t) | .id' \
            | head -1)
    fi
else
    log "Step 1: Project '$PROJECT_TITLE' already exists (number=$PROJECT_NUM). Reusing."
fi
log "  PROJECT_NUM=$PROJECT_NUM  PROJECT_ID=$PROJECT_ID"

# Update scrumban.md with the actual project URL (idempotent)
SCRUMBAN_DOC="docs/methodology/scrumban.md"
PROJECT_URL="https://github.com/users/${OWNER}/projects/${PROJECT_NUM}"
if [ "$DRY_RUN" = "--dry-run" ]; then
    dry_run_echo "sed replace projects/<TBD> -> projects/${PROJECT_NUM} in $SCRUMBAN_DOC"
elif grep -q "projects/<TBD>" "$SCRUMBAN_DOC"; then
    sed -i.bak "s|projects/<TBD>|projects/${PROJECT_NUM}|g" "$SCRUMBAN_DOC"
    rm "${SCRUMBAN_DOC}.bak"
    log "[INFO] Updated $SCRUMBAN_DOC with project URL: $PROJECT_URL"
elif grep -q "$PROJECT_URL" "$SCRUMBAN_DOC"; then
    log "[INFO] $SCRUMBAN_DOC already has correct project URL"
else
    log "[WARN] $SCRUMBAN_DOC URL state unclear — please update manually"
fi

# ---------------------------------------------------------------------------
# Step 2: Create Status field (Single-select, 8 options)
# ---------------------------------------------------------------------------
log "Step 2: Creating Status field..."
STATUS_OPTIONS="Backlog,Shaped (Pitch済),Ready (DoR満),In Discover,In Plan,In ATDD,In Review (PR),Done"

if gh project field-list "$PROJECT_NUM" --owner "$OWNER" --format json \
    | jq -e '.fields[] | select(.name == "Status")' > /dev/null 2>&1; then
    log "  Status field already exists. Skipping."
else
    if [ "$DRY_RUN" = "--dry-run" ]; then
        dry_run_echo "gh project field-create $PROJECT_NUM --owner $OWNER --name Status --data-type SINGLE_SELECT --single-select-options '$STATUS_OPTIONS'"
    else
        gh project field-create "$PROJECT_NUM" --owner "$OWNER" \
            --name "Status" --data-type SINGLE_SELECT \
            --single-select-options "$STATUS_OPTIONS"
    fi
fi

# ---------------------------------------------------------------------------
# Step 3: Create 5 custom fields (Skill, Phase, Size = SINGLE_SELECT; Impact, Epic = TEXT)
# ---------------------------------------------------------------------------
log "Step 3: Creating custom fields..."

create_single_select_field() {
    local name="$1" options="$2"
    if gh project field-list "$PROJECT_NUM" --owner "$OWNER" --format json \
        | jq -e --arg n "$name" '.fields[] | select(.name == $n)' > /dev/null 2>&1; then
        log "  $name field already exists. Skipping."
    else
        if [ "$DRY_RUN" = "--dry-run" ]; then
            dry_run_echo "gh project field-create ... --name $name --data-type SINGLE_SELECT"
        else
            gh project field-create "$PROJECT_NUM" --owner "$OWNER" \
                --name "$name" --data-type SINGLE_SELECT \
                --single-select-options "$options"
        fi
    fi
}

create_text_field() {
    local name="$1"
    if gh project field-list "$PROJECT_NUM" --owner "$OWNER" --format json \
        | jq -e --arg n "$name" '.fields[] | select(.name == $n)' > /dev/null 2>&1; then
        log "  $name field already exists. Skipping."
    else
        if [ "$DRY_RUN" = "--dry-run" ]; then
            dry_run_echo "gh project field-create ... --name $name --data-type TEXT"
        else
            gh project field-create "$PROJECT_NUM" --owner "$OWNER" \
                --name "$name" --data-type TEXT
        fi
    fi
}

create_single_select_field "Skill" "discover,plan,atdd,verify,ship,bug,issue,express,ideate,debugging,N/A"
create_single_select_field "Phase" "discover,plan,atdd,verify,ship"
create_single_select_field "Size" "S,M,L,XL"
create_text_field "Impact"
create_text_field "Epic"

# ---------------------------------------------------------------------------
# Step 4: Iteration field — Web UI only
# ---------------------------------------------------------------------------
log "Step 4: Iteration field must be created manually in Web UI."
log "  URL: https://github.com/users/$OWNER/projects/$PROJECT_NUM/settings/fields"
log "  Add field → Iteration → options: Now (current..+4w) / Next (+4w..+8w) / Later (+8w..+12w)"
log "  Press ENTER once Iteration field is created to continue..."
if [ "$DRY_RUN" != "--dry-run" ]; then
    read -r
fi

# ---------------------------------------------------------------------------
# Step 5: Add all Open Issues to project (re-run before PR merge)
# ---------------------------------------------------------------------------
log "Step 5: Adding all Open Issues to project..."
log "  NOTE: Re-run Step 5+6 just before PR merge to capture any new Issues."

if [ "$DRY_RUN" = "--dry-run" ]; then
    dry_run_echo "Would add all open issues to project $PROJECT_NUM"
else
    gh issue list --repo "$REPO" --state open --json number --limit 200 \
        | jq -r '.[].number' \
        | while read -r num; do
            ISSUE_URL="https://github.com/${REPO}/issues/${num}"
            log "  Adding issue #${num}..."
            gh project item-add "$PROJECT_NUM" --owner "$OWNER" --url "$ISSUE_URL" 2>/dev/null \
                || log "  Issue #${num} already in project or error — skipping."
        done
fi

# ---------------------------------------------------------------------------
# Step 6: Bulk-set field values per Issue (re-run before PR merge)
# ---------------------------------------------------------------------------
log "Step 6: Bulk-setting field values..."

# Retrieve field IDs (needed for item-edit)
FIELDS_JSON=$(gh project field-list "$PROJECT_NUM" --owner "$OWNER" --format json)

get_field_id() {
    echo "$FIELDS_JSON" | jq -r --arg n "$1" '.fields[] | select(.name == $n) | .id'
}

get_option_id() {
    local field_name="$1" option_name="$2"
    echo "$FIELDS_JSON" | jq -r \
        --arg f "$field_name" --arg o "$option_name" \
        '.fields[] | select(.name == $f) | .options[] | select(.name == $o) | .id' 2>/dev/null \
        || echo ""
}

STATUS_FIELD_ID=$(get_field_id "Status")
SKILL_FIELD_ID=$(get_field_id "Skill")
IMPACT_FIELD_ID=$(get_field_id "Impact")
EPIC_FIELD_ID=$(get_field_id "Epic")
ITERATION_FIELD_ID=$(get_field_id "Iteration")

# Static Issue → field value map (manually reviewed)
# Format: "ISSUE_NUM|STATUS|SKILL|IMPACT|EPIC"
declare -a ISSUE_MAP=(
    "173|Backlog|N/A|methodology|#165"
    "172|Backlog|N/A|methodology|#165"
    "171|Backlog|discover|quality|#165"
    "170|Backlog|N/A|automation|#165"
    "169|In ATDD|discover|quality|#165"
    "168|In ATDD|N/A|visibility|#165"
    "165|Backlog|N/A|methodology|"
    "163|Backlog|N/A|visibility|#165"
    "162|In Review (PR)|discover|quality|#165"
    "161|Backlog|N/A|quality|#165"
    "159|Backlog|N/A|quality|#165"
    "158|Backlog|N/A|quality|#165"
    "149|Backlog|N/A|quality|#165"
    "148|In ATDD|discover|quality|#165"
    "147|Backlog|express|quality|#165"
    "146|Backlog|issue|quality|#165"
    "145|Backlog|ideate|quality|#165"
    "144|Backlog|debugging|quality|#165"
    "143|Backlog|bug|quality|#165"
    "142|Backlog|ship|quality|#165"
    "141|Backlog|verify|quality|#165"
    "137|Backlog|atdd|quality|#165"
    "117|Backlog|N/A|quality|#65"
    "73|Backlog|N/A|quality|#65"
    "71|In ATDD|atdd|quality|#65"
    "63|Backlog|N/A|methodology|"
    "14|Backlog|plan|quality|#65"
)

# Default Iteration values per Status
get_iteration() {
    local status="$1"
    case "$status" in
        "In Discover"|"In Plan"|"In ATDD"|"In Review (PR)") echo "Now" ;;
        "Ready (DoR満)"|"Shaped (Pitch済)") echo "Next" ;;
        *) echo "Later" ;;
    esac
}

if [ "$DRY_RUN" != "--dry-run" ]; then
    # Build item lookup: issue number → project item ID
    ITEMS_JSON=$(gh project item-list "$PROJECT_NUM" --owner "$OWNER" --format json --limit 200)

    for entry in "${ISSUE_MAP[@]}"; do
        IFS='|' read -r issue_num status skill impact epic <<< "$entry"

        ITEM_ID=$(echo "$ITEMS_JSON" \
            | jq -r --argjson n "$issue_num" \
                '.items[] | select(.content.number == $n) | .id' 2>/dev/null || echo "")

        if [ -z "$ITEM_ID" ]; then
            log "  Issue #${issue_num} not found in project — skipping field set."
            continue
        fi

        log "  Setting fields for Issue #${issue_num} (item=$ITEM_ID)..."

        # Status (SINGLE_SELECT — use --single-select-option-id)
        STATUS_OPT_ID=$(get_option_id "Status" "$status")
        if [ -n "$STATUS_OPT_ID" ] && [ -n "$STATUS_FIELD_ID" ]; then
            gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" \
                --field-id "$STATUS_FIELD_ID" \
                --single-select-option-id "$STATUS_OPT_ID" 2>/dev/null || true
        fi

        # Skill (SINGLE_SELECT — use --single-select-option-id)
        SKILL_OPT_ID=$(get_option_id "Skill" "$skill")
        if [ -n "$SKILL_OPT_ID" ] && [ -n "$SKILL_FIELD_ID" ]; then
            gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" \
                --field-id "$SKILL_FIELD_ID" \
                --single-select-option-id "$SKILL_OPT_ID" 2>/dev/null || true
        fi

        # Impact (TEXT)
        if [ -n "$IMPACT_FIELD_ID" ] && [ -n "$impact" ]; then
            gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" \
                --field-id "$IMPACT_FIELD_ID" --text "$impact" 2>/dev/null || true
        fi

        # Epic (TEXT)
        if [ -n "$EPIC_FIELD_ID" ] && [ -n "$epic" ]; then
            gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" \
                --field-id "$EPIC_FIELD_ID" --text "$epic" 2>/dev/null || true
        fi

        # Iteration (use --iteration-id)
        ITER_VALUE=$(get_iteration "$status")
        ITER_ID=$(echo "$FIELDS_JSON" | jq -r \
            --arg o "$ITER_VALUE" \
            '.fields[] | select(.name == "Iteration") | .configuration.iterations[] | select(.title == $o) | .id' \
            2>/dev/null || echo "")
        if [ -n "$ITER_ID" ] && [ -n "$ITERATION_FIELD_ID" ]; then
            gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" \
                --field-id "$ITERATION_FIELD_ID" \
                --iteration-id "$ITER_ID" 2>/dev/null || true
        fi
    done
fi

# ---------------------------------------------------------------------------
# Step 7: Create 3 views — Web UI only
# ---------------------------------------------------------------------------
log "Step 7: Views must be created manually in Web UI."
log "  URL: https://github.com/users/$OWNER/projects/$PROJECT_NUM"
log "  1. Board view: Grouping = Status, Card fields: add Skill"
log "  2. Table view: Filter = status:!=Done"
log "  3. Roadmap view: Timeline axis = Iteration, Card display: add Impact"

log ""
log "Setup complete. Run scripts/verify-project.sh to verify AC2 and AC5."
log "Remember: Re-run Step 5+6 (item-add + bulk-set) just before PR merge."
