#!/usr/bin/env bash
set -euo pipefail

# ── Copy host config into Claude Code paths ──────────────────────────────────

HOST_CONFIG="/host-config"
CLAUDE_HOME="$HOME/.claude"

if [ ! -d "$HOST_CONFIG" ]; then
  echo "  No host-config mounted, skipping."
  exit 0
fi

# Global CLAUDE.md
if [ -f "$HOST_CONFIG/CLAUDE.md" ]; then
  cp "$HOST_CONFIG/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"
  echo "  Copied global CLAUDE.md"
fi

# Global settings.json (merge with existing if present)
if [ -f "$HOST_CONFIG/settings.json" ]; then
  if [ -f "$CLAUDE_HOME/settings.json" ]; then
    # Merge: host config values override defaults
    jq -s '.[0] * .[1]' "$CLAUDE_HOME/settings.json" "$HOST_CONFIG/settings.json" \
      > "$CLAUDE_HOME/settings.json.tmp" \
      && mv "$CLAUDE_HOME/settings.json.tmp" "$CLAUDE_HOME/settings.json"
    echo "  Merged host settings.json with defaults"
  else
    cp "$HOST_CONFIG/settings.json" "$CLAUDE_HOME/settings.json"
    echo "  Copied global settings.json"
  fi
fi

# Global agents
if [ -d "$HOST_CONFIG/agents" ]; then
  mkdir -p "$CLAUDE_HOME/agents"
  cp "$HOST_CONFIG/agents/"*.md "$CLAUDE_HOME/agents/" 2>/dev/null || true
  echo "  Copied global agents"
fi

# Global skills
if [ -d "$HOST_CONFIG/skills" ]; then
  cp -r "$HOST_CONFIG/skills/"* "$CLAUDE_HOME/skills/" 2>/dev/null || true
  echo "  Copied global skills"
fi

# Per-repo config
if [ -d "$HOST_CONFIG/repos" ]; then
  for REPO_DIR in "$HOST_CONFIG/repos"/*/; do
    REPO_NAME=$(basename "$REPO_DIR")
    WORKSPACE_REPO="/workspace/$REPO_NAME"

    if [ ! -d "$WORKSPACE_REPO" ]; then
      continue
    fi

    mkdir -p "$WORKSPACE_REPO/.claude"

    # Per-repo CLAUDE.md
    if [ -f "$REPO_DIR/CLAUDE.md" ]; then
      cp "$REPO_DIR/CLAUDE.md" "$WORKSPACE_REPO/.claude/CLAUDE.md"
      echo "  Copied CLAUDE.md for $REPO_NAME"
    fi

    # Per-repo agents
    if [ -d "$REPO_DIR/agents" ]; then
      mkdir -p "$WORKSPACE_REPO/.claude/agents"
      cp "$REPO_DIR/agents/"*.md "$WORKSPACE_REPO/.claude/agents/" 2>/dev/null || true
    fi

    # Per-repo skills
    if [ -d "$REPO_DIR/skills" ]; then
      cp -r "$REPO_DIR/skills/"* "$WORKSPACE_REPO/.claude/skills/" 2>/dev/null || true
    fi

    # Per-repo plans
    if [ -d "$REPO_DIR/plans" ]; then
      mkdir -p "$WORKSPACE_REPO/.claude/plans"
      cp "$REPO_DIR/plans/"*.md "$WORKSPACE_REPO/.claude/plans/" 2>/dev/null || true
    fi
  done
fi

# Install mode-specific skills/agents from built-in claude-config
MODE="${MODE:-develop}"
BUILTIN_CONFIG="/etc/claude-dev/claude-config"

if [ -d "$BUILTIN_CONFIG/agents" ]; then
  mkdir -p "$CLAUDE_HOME/agents"
  cp "$BUILTIN_CONFIG/agents/"*.md "$CLAUDE_HOME/agents/" 2>/dev/null || true
fi

if [ -d "$BUILTIN_CONFIG/skills" ]; then
  cp -r "$BUILTIN_CONFIG/skills/"* "$CLAUDE_HOME/skills/" 2>/dev/null || true
fi

echo "  Claude Code config ready."
