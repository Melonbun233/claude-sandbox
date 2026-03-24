#!/usr/bin/env bash
set -euo pipefail

# ── Jira connection setup ────────────────────────────────────────────────────
# Validates Jira connectivity. Read-only scripts are pre-installed.

JIRA_URL="${JIRA_URL:-}"

if [ -z "$JIRA_URL" ]; then
  echo "  JIRA_URL not set, skipping Jira setup."
  exit 0
fi

JIRA_AUTH_TYPE="${JIRA_AUTH_TYPE:-cloud}"
JIRA_USERNAME="${JIRA_USERNAME:-}"
JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"

if [ -z "$JIRA_API_TOKEN" ]; then
  echo "  WARN: JIRA_API_TOKEN not set, Jira queries will fail."
  exit 0
fi

# Determine API version
if [ "$JIRA_AUTH_TYPE" = "datacenter" ]; then
  API_PATH="/rest/api/2/serverInfo"
else
  API_PATH="/rest/api/3/serverInfo"
fi

echo "  Validating Jira connection ($JIRA_AUTH_TYPE)..."

# Build auth header
if [ "$JIRA_AUTH_TYPE" = "datacenter" ]; then
  AUTH_HEADER="Authorization: Bearer $JIRA_API_TOKEN"
else
  ENCODED=$(echo -n "${JIRA_USERNAME}:${JIRA_API_TOKEN}" | base64)
  AUTH_HEADER="Authorization: Basic $ENCODED"
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -H "$AUTH_HEADER" -H "Content-Type: application/json" "${JIRA_URL}${API_PATH}" 2>&1) || {
  echo "  WARN: Could not reach Jira at $JIRA_URL"
  exit 0
}

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  VERSION=$(echo "$BODY" | jq -r '.version // "unknown"')
  echo "  Connected to Jira ($JIRA_URL) — version $VERSION"
else
  echo "  WARN: Jira returned HTTP $HTTP_CODE"
fi
