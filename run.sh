#!/bin/bash
# Run Claude Code in a sandboxed container against the current directory.
# Usage: claude-sandbox [claude args...]
#   e.g. claude-sandbox
#        claude-sandbox --dangerously-skip-permissions

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Pull API key from environment or macOS keychain
if [ -z "$ANTHROPIC_API_KEY" ]; then
  ANTHROPIC_API_KEY=$(security find-generic-password -s "Claude Code" -w 2>/dev/null)
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "Error: could not find Anthropic API key. Set ANTHROPIC_API_KEY or store it in keychain." >&2
  exit 1
fi

# Refuse to run from home directory
if [ "$(pwd)" = "$HOME" ]; then
  echo "Error: cannot run claude-sandbox from your home directory. cd into a project first." >&2
  exit 1
fi

# Build image if it doesn't exist
if ! docker image inspect claude-sandbox &>/dev/null; then
  echo "Building claude-sandbox image..."
  docker build -t claude-sandbox "$SCRIPT_DIR"
fi

docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm -e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" claude "$@"
