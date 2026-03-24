#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jira-common.sh"

# ── jira-get-sprint ──────────────────────────────────────────────────────────
# Usage: jira-get-sprint <BOARD-ID>

if [ $# -lt 1 ]; then
  echo "Usage: jira-get-sprint <BOARD-ID>" >&2
  exit 1
fi

jira_check_config

BOARD_ID="$1"
AGILE_URL=$(jira_agile_url)

# Get active sprint
SPRINT_RESPONSE=$(jira_curl GET "${AGILE_URL}/board/${BOARD_ID}/sprint?state=active")
SPRINT_ID=$(echo "$SPRINT_RESPONSE" | jq -r '.values[0].id // empty')
SPRINT_NAME=$(echo "$SPRINT_RESPONSE" | jq -r '.values[0].name // "N/A"')

if [ -z "$SPRINT_ID" ]; then
  echo "No active sprint found for board $BOARD_ID."
  exit 0
fi

echo "Sprint: $SPRINT_NAME (ID: $SPRINT_ID)"
echo ""

# Get issues in sprint
ISSUES_RESPONSE=$(jira_curl GET "${AGILE_URL}/sprint/${SPRINT_ID}/issue?fields=key,summary,status,assignee,issuetype,priority")

echo "$ISSUES_RESPONSE" | jq -r '
  .issues[] |
  "\(.key)\t\(.fields.issuetype.name)\t\(.fields.status.name)\t\(.fields.assignee.displayName // "Unassigned")\t\(.fields.summary)"
' | column -t -s $'\t'
