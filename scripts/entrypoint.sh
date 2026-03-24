#!/usr/bin/env bash
set -euo pipefail

# ── Banner ───────────────────────────────────────────────────────────────────
MODE="${MODE:-develop}"
echo "┌──────────────────────────────────────────────┐"
echo "│  claude-devcontainer                         │"
echo "│  Mode: $(printf '%-38s' "$MODE")│"
echo "│  Time: $(printf '%-38s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)")│"
echo "└──────────────────────────────────────────────┘"
echo ""

# ── Validate mode ────────────────────────────────────────────────────────────
case "$MODE" in
  develop|pr-review)
    ;;
  *)
    echo "ERROR: Unknown mode '$MODE'. Supported: develop, pr-review"
    exit 1
    ;;
esac

# ── Setup scripts ────────────────────────────────────────────────────────────
echo ":: Setting up GitHub..."
/scripts/setup-github.sh || echo "WARN: GitHub setup had issues (continuing)"

echo ":: Setting up Jira..."
/scripts/setup-jira.sh || echo "WARN: Jira setup had issues (continuing)"

echo ":: Cloning repos..."
/scripts/clone-repos.sh || echo "WARN: Repo cloning had issues (continuing)"

echo ":: Configuring Claude Code..."
/scripts/setup-claude-config.sh || echo "WARN: Claude config setup had issues (continuing)"

# ── Session directory ────────────────────────────────────────────────────────
SESSION_DIR="/workspace/.claude-session"
mkdir -p "$SESSION_DIR"

cat > "$SESSION_DIR/status.json" <<EOF
{
  "mode": "$MODE",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "container_id": "$(hostname)"
}
EOF

touch "$SESSION_DIR/output.log"

echo ""
echo ":: Setup complete. Launching mode: $MODE"
echo ""

# ── Dispatch to mode script ──────────────────────────────────────────────────
exec /scripts/modes/${MODE}.sh
