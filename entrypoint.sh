#!/bin/bash
# Stash the key in a file and unset the env var so Claude doesn't show the
# "detected custom API key" prompt. The apiKeyHelper script reads from the file.
if [ -n "$ANTHROPIC_API_KEY" ]; then
  echo -n "$ANTHROPIC_API_KEY" > /run/claude-api-key
  chmod 600 /run/claude-api-key
fi

exec env -u ANTHROPIC_API_KEY claude "$@"
