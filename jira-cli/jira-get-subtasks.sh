#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jira-common.sh"

# ── jira-get-subtasks ────────────────────────────────────────────────────────
# Usage: jira-get-subtasks <ISSUE-KEY>

if [ $# -lt 1 ]; then
  echo "Usage: jira-get-subtasks <ISSUE-KEY>" >&2
  exit 1
fi

jira_check_config

KEY="$1"
API=$(jira_api_url)

RESPONSE=$(jira_curl GET "${API}/issue/${KEY}?fields=subtasks,summary")

SUMMARY=$(echo "$RESPONSE" | jq -r '.fields.summary // "N/A"')
echo "Subtasks of $KEY: $SUMMARY"
echo ""

SUBTASK_COUNT=$(echo "$RESPONSE" | jq '.fields.subtasks | length')

if [ "$SUBTASK_COUNT" -eq 0 ]; then
  echo "  No subtasks."
  exit 0
fi

echo "$RESPONSE" | jq -r '
  .fields.subtasks[] |
  "\(.key)\t\(.fields.status.name)\t\(.fields.summary)"
' | column -t -s $'\t'
