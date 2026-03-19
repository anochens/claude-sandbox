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


# Get GitHub token via gh CLI (handles macOS keychain transparently)
GH_TOKEN=$(gh auth token 2>/dev/null)

mkdir -p "$HOME/.claude/sessions" "$HOME/.claude/projects"

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

# Mount symlink targets so they resolve inside the container.
# For each symlink in $PWD, mount the real target at the same absolute path.
SYMLINK_VOLUMES=()
while IFS= read -r -d '' link; do
  target=$(readlink -f "$link")
  if [ -e "$target" ] && [ "$target" != "$PWD" ]; then
    SYMLINK_VOLUMES+=(-v "$target:/workspace/$(basename "$link")")
  fi
done < <(find "$PWD" -maxdepth 1 -type l -print0)

docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm \
  -e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" \
  ${GH_TOKEN:+-e "GH_TOKEN=$GH_TOKEN"} \
  "${SYMLINK_VOLUMES[@]}" \
  claude "$@"
