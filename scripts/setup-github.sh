#!/usr/bin/env bash
set -euo pipefail

# ── GitHub authentication setup ──────────────────────────────────────────────
# Reads github_servers from workspace.yaml, authenticates gh CLI per server.
# Supports per-server ssl_verify: false to skip TLS verification.

CONFIG_FILE="/etc/claude-dev/config/workspace.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "  No workspace.yaml found, skipping GitHub setup."
  exit 0
fi

SERVER_COUNT=$(yq '.github_servers | length' "$CONFIG_FILE" 2>/dev/null || echo 0)

if [ "$SERVER_COUNT" -eq 0 ]; then
  echo "  No github_servers defined, skipping GitHub setup."
  exit 0
fi

GH_HOSTS_FILE="$HOME/.config/gh/hosts.yml"
mkdir -p "$(dirname "$GH_HOSTS_FILE")"

for i in $(seq 0 $((SERVER_COUNT - 1))); do
  HOST=$(yq ".github_servers[$i].host" "$CONFIG_FILE")
  TOKEN_ENV=$(yq ".github_servers[$i].token_env" "$CONFIG_FILE")
  SSL_VERIFY=$(yq ".github_servers[$i].ssl_verify" "$CONFIG_FILE")
  if [ "$SSL_VERIFY" != "false" ]; then SSL_VERIFY="true"; fi

  # Resolve the env var value
  TOKEN="${!TOKEN_ENV:-}"

  if [ -z "$TOKEN" ]; then
    echo "  WARN: \$$TOKEN_ENV is not set, skipping $HOST"
    continue
  fi

  # Set git SSL config for this host
  if [ "$SSL_VERIFY" = "false" ]; then
    echo "  SSL verification disabled for $HOST"
    git config --global "http.https://$HOST/.sslVerify" false
  fi

  echo "  Authenticating to $HOST..."

  if [ "$SSL_VERIFY" = "false" ]; then
    # Write token directly to gh hosts.yml to avoid TLS validation in gh auth login
    yq -i ".[\"$HOST\"].oauth_token = \"$TOKEN\" | .[\"$HOST\"].git_protocol = \"https\"" "$GH_HOSTS_FILE" 2>/dev/null || {
      # Fallback: write YAML manually if yq fails on hosts.yml format
      cat >> "$GH_HOSTS_FILE" <<EOF
$HOST:
    oauth_token: $TOKEN
    git_protocol: https
EOF
    }
    echo "  Token written directly to gh hosts.yml (SSL verify off)"
  else
    # Temporarily unset GH_TOKEN/GH_ENTERPRISE_TOKEN to prevent gh CLI conflict
    (unset GH_TOKEN GH_ENTERPRISE_TOKEN; echo "$TOKEN" | gh auth login --hostname "$HOST" --with-token 2>&1) || {
      echo "  WARN: Failed to authenticate to $HOST"
      continue
    }
  fi
done

# Configure git credential helper for all authenticated hosts
(unset GH_TOKEN GH_ENTERPRISE_TOKEN; gh auth setup-git 2>/dev/null) || true

echo "  GitHub auth complete."
