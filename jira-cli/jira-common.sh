#!/usr/bin/env bash
# jira-common.sh — Shared Jira auth and HTTP helpers
# Source this file from other jira-* scripts.

JIRA_URL="${JIRA_URL:-}"
JIRA_USERNAME="${JIRA_USERNAME:-}"
JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"
JIRA_AUTH_TYPE="${JIRA_AUTH_TYPE:-cloud}"

jira_check_config() {
  if [ -z "$JIRA_URL" ]; then
    echo "ERROR: JIRA_URL is not set." >&2
    exit 1
  fi
  if [ -z "$JIRA_API_TOKEN" ]; then
    echo "ERROR: JIRA_API_TOKEN is not set." >&2
    exit 1
  fi
}

jira_api_url() {
  if [ "$JIRA_AUTH_TYPE" = "datacenter" ]; then
    echo "${JIRA_URL}/rest/api/2"
  else
    echo "${JIRA_URL}/rest/api/3"
  fi
}

jira_agile_url() {
  echo "${JIRA_URL}/rest/agile/1.0"
}

jira_curl() {
  local method="$1"
  local endpoint="$2"
  shift 2
  local data="${1:-}"

  local auth_header
  if [ "$JIRA_AUTH_TYPE" = "datacenter" ]; then
    auth_header="Authorization: Bearer $JIRA_API_TOKEN"
  else
    local encoded
    encoded=$(echo -n "${JIRA_USERNAME}:${JIRA_API_TOKEN}" | base64)
    auth_header="Authorization: Basic $encoded"
  fi

  local curl_args=(
    -s
    -w "\n%{http_code}"
    -X "$method"
    -H "$auth_header"
    -H "Content-Type: application/json"
    -H "Accept: application/json"
  )

  if [ -n "$data" ]; then
    curl_args+=(-d "$data")
  fi

  local response
  response=$(curl "${curl_args[@]}" "$endpoint" 2>&1)
  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 400 ]]; then
    local error_msg
    error_msg=$(echo "$body" | jq -r '.errorMessages[0] // .message // "Unknown error"' 2>/dev/null || echo "$body")
    echo "ERROR: HTTP $http_code — $error_msg" >&2
    return 1
  fi

  echo "$body"
}
