#!/usr/bin/env bash
set -euo pipefail

# ── Develop mode ─────────────────────────────────────────────────────────────
# Keeps the container alive so the user can attach interactively.

SKIP_PERMISSIONS="${SKIP_PERMISSIONS:-false}"

echo "╔══════════════════════════════════════════════════╗"
echo "║  DEVELOP MODE                                    ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "║  Attach to this container:                       ║"
echo "║                                                  ║"
if [ "$SKIP_PERMISSIONS" = "true" ]; then
echo "║    docker exec -it claude-dev \\                  ║"
echo "║      claude --dangerously-skip-permissions       ║"
else
echo "║    docker exec -it claude-dev claude              ║"
fi
echo "║                                                  ║"
echo "║  Or use the CLI wrapper:                         ║"
echo "║                                                  ║"
echo "║    ./claude-dev attach                           ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"

# Keep the container alive
exec sleep infinity
