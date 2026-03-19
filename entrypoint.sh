#!/bin/bash
# Stash the key in a file and unset the env var so Claude doesn't show the
# "detected custom API key" prompt. The apiKeyHelper script reads from the file.
if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo -n "$ANTHROPIC_API_KEY" > /run/claude-api-key
  chmod 600 /run/claude-api-key
fi

# Write sandbox settings on top of the mounted ~/.claude, so that
# onboarding/auth config is always correct regardless of host settings.
CLAUDE_VERSION=$(node -e "console.log(require('/usr/local/lib/node_modules/@anthropic-ai/claude-code/package.json').version)" 2>/dev/null)
mkdir -p /root/.claude
jq -n \
  --arg v "$CLAUDE_VERSION" \
  --arg p "${HOST_PWD:-$PWD}" \
  '{hasCompletedOnboarding: true, lastOnboardingVersion: $v, theme: "dark", projects: {($p): {hasTrustDialogAccepted: true}}}' \
  > /root/.claude/.config.json

# Write sandbox settings into the container-local claude config volume
cp /root/.claude-defaults/settings.json /root/.claude/settings.json

exec env -u ANTHROPIC_API_KEY claude "$@"
