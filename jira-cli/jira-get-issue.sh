#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/jira-common.sh"

# ── jira-get-issue ───────────────────────────────────────────────────────────
# Usage: jira-get-issue <ISSUE-KEY>

if [ $# -lt 1 ]; then
  echo "Usage: jira-get-issue <ISSUE-KEY>" >&2
  exit 1
fi

jira_check_config

KEY="$1"
FIELDS="summary,status,assignee,description,issuetype,priority,labels,subtasks,parent,components,fixVersions"
API=$(jira_api_url)

RESPONSE=$(jira_curl GET "${API}/issue/${KEY}?fields=${FIELDS}")

# Format output
echo "$RESPONSE" | jq -r '
  "Issue:       \(.key)",
  "Type:        \(.fields.issuetype.name // "N/A")",
  "Status:      \(.fields.status.name // "N/A")",
  "Priority:    \(.fields.priority.name // "N/A")",
  "Assignee:    \(.fields.assignee.displayName // "Unassigned")",
  "Summary:     \(.fields.summary // "N/A")",
  "Labels:      \((.fields.labels // []) | join(", "))",
  "Parent:      \(.fields.parent.key // "None")",
  "Components:  \((.fields.components // []) | map(.name) | join(", "))",
  "",
  "Description:",
  (.fields.description // "No description" | if type == "object" then
    [.. | .text? // empty] | join("")
  else
    .
  end)
'
