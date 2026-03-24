#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jira-common.sh"

# ── jira-search ──────────────────────────────────────────────────────────────
# Usage: jira-search "<JQL query>" [max_results]

if [ $# -lt 1 ]; then
  echo "Usage: jira-search \"<JQL>\" [max_results]" >&2
  exit 1
fi

jira_check_config

JQL="$1"
MAX_RESULTS="${2:-20}"
API=$(jira_api_url)

PAYLOAD=$(jq -n \
  --arg jql "$JQL" \
  --argjson max "$MAX_RESULTS" \
  '{
    jql: $jql,
    maxResults: $max,
    fields: ["key", "summary", "status", "assignee", "issuetype", "priority"]
  }')

RESPONSE=$(jira_curl POST "${API}/search" "$PAYLOAD")

# Format output
TOTAL=$(echo "$RESPONSE" | jq -r '.total')
echo "Found $TOTAL issues (showing up to $MAX_RESULTS):"
echo ""

echo "$RESPONSE" | jq -r '
  .issues[] |
  "\(.key)\t\(.fields.issuetype.name)\t\(.fields.status.name)\t\(.fields.priority.name // "-")\t\(.fields.assignee.displayName // "Unassigned")\t\(.fields.summary)"
' | column -t -s $'\t'
