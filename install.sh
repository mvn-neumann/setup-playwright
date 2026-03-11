#!/usr/bin/env bash
# install.sh — Install the setup-playwright skill for Claude Code.
#
# Installs to:
#   ~/.claude/skills/setup-playwright/SKILL.md   (shared, all projects)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TARGET="$CLAUDE_DIR/skills/setup-playwright/SKILL.md"

# Create target directory
mkdir -p "$CLAUDE_DIR/skills/setup-playwright"

# Detect fresh install vs update
if [ -f "$TARGET" ]; then
  ACTION="Updated"
else
  ACTION="Installed"
fi

# Copy skill file
cp "$SCRIPT_DIR/skills/setup-playwright/SKILL.md" "$TARGET"

echo "setup-playwright: $ACTION successfully."
echo ""
echo "  $TARGET"
echo ""
echo "Usage: /setup-playwright (inside any project)"
