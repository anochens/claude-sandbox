#!/bin/bash
# Stash the key in a file and unset the env var so Claude doesn't show the
# "detected custom API key" prompt. The apiKeyHelper script reads from the file.
if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo -n "$ANTHROPIC_API_KEY" > /tmp/claude-api-key
  chmod 644 /tmp/claude-api-key
fi

# Ensure ~/.claude is owned by the claude user (the named volume may be root-owned on first run)
chown -R claude:claude /home/claude/.claude

# Write sandbox settings on top of the mounted ~/.claude, so that
# onboarding/auth config is always correct regardless of host settings.
CLAUDE_VERSION=$(node -e "console.log(require('/usr/local/lib/node_modules/@anthropic-ai/claude-code/package.json').version)" 2>/dev/null)
mkdir -p /home/claude/.claude
jq -n \
  --arg v "$CLAUDE_VERSION" \
  --arg p "${HOST_PWD:-$PWD}" \
  '{hasCompletedOnboarding: true, lastOnboardingVersion: $v, theme: "dark", projects: {($p): {hasTrustDialogAccepted: true}}}' \
  > /home/claude/.claude/.config.json

# Write sandbox settings into the container-local claude config volume
cp /home/claude/.claude-defaults/settings.json /home/claude/.claude/settings.json

exec gosu claude env -u ANTHROPIC_API_KEY claude "$@"
