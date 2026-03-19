#!/bin/bash
# Run Claude Code in a sandboxed container against the current directory.
# Usage: claude-sandbox [claude args...]
#   e.g. claude-sandbox
#        claude-sandbox --dangerously-skip-permissions

IMAGE="claude-sandbox"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pull API key from macOS keychain
if [ -z "$ANTHROPIC_API_KEY" ]; then
  ANTHROPIC_API_KEY=$(security find-generic-password -s "Claude Code" -w 2>/dev/null)
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "Error: could not find Anthropic API key in keychain. Run 'claude' once to authenticate." >&2
  exit 1
fi

# Refuse to run from home directory
if [ "$(pwd)" = "$HOME" ]; then
  echo "Error: cannot run claude-sandbox from your home directory. cd into a project first." >&2
  exit 1
fi

# Build image if it doesn't exist
if ! docker image inspect "$IMAGE" &>/dev/null; then
  echo "Building $IMAGE image..."
  docker build -t "$IMAGE" "$SCRIPT_DIR"
fi

mount_if_exists() {
  local src="$1" target="$2" flags="${3:-ro}"
  if [ -e "$src" ]; then
    echo "-v ${src}:${target}:${flags}"
  fi
}

docker run -it --rm \
  -w /workspace \
  -v "$(pwd)":/workspace \
  \
  `# Auth & Identity` \
  $(mount_if_exists "$HOME/.npmrc"    /root/.npmrc) \
  $(mount_if_exists "$HOME/.gitconfig" /root/.gitconfig) \
  $(mount_if_exists "$HOME/.ssh"      /root/.ssh) \
  \
  `# Kubernetes` \
  $(mount_if_exists "$HOME/.kube"              /root/.kube) \
  $(mount_if_exists "$HOME/.pmctl"             /root/.pmctl) \
  $(mount_if_exists "$HOME/.config/argocd"     /root/.config/argocd) \
  \
  `# Databases` \
  $(mount_if_exists "$HOME/.docdb" /root/.docdb) \
  $(mount_if_exists "$HOME/.aws"   /root/.aws) \
  \
  `# Editor` \
  $(mount_if_exists "$HOME/.vimrc" /root/.vimrc) \
  $(mount_if_exists "$HOME/.vim"   /root/.vim) \
  \
  `# Files` \
  $(mount_if_exists "$HOME/Downloads" /root/Downloads) \
  \
  -e ANTHROPIC_API_KEY \
  "$IMAGE" claude "$@"
