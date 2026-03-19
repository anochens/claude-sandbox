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

# Merge sandbox defaults into settings.json, preserving any user-added settings
# (e.g. plugin registrations). Defaults are the base; existing settings win on conflict.
SETTINGS=/home/claude/.claude/settings.json
DEFAULTS=/home/claude/.claude-defaults/settings.json
if [ -f "$SETTINGS" ]; then
  jq -s '.[0] * .[1]' "$DEFAULTS" "$SETTINGS" > /tmp/settings-merged.json \
    && mv /tmp/settings-merged.json "$SETTINGS"
else
  cp "$DEFAULTS" "$SETTINGS"
fi

exec gosu claude env -u ANTHROPIC_API_KEY claude "$@"
