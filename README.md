# Claude Sandbox

A Docker-based sandbox for running [Claude Code](https://claude.ai/code) in an isolated, secure container with granular permission controls and pre-installed development tools.

## Overview

Claude Sandbox containerizes Claude Code so it can safely interact with your local workspace while:
- Preventing destructive operations (force pushes, `rm -rf`, `kubectl delete`, etc.)
- Securely managing your Anthropic API key
- Mirroring your local developer identity (git config, SSH keys, Kubernetes config, AWS credentials) into the container
- Providing a rich set of pre-installed development tools

## Requirements

- Docker and Docker Compose
- An Anthropic API key (via `ANTHROPIC_API_KEY` environment variable or macOS keychain)

## Build

```bash
docker build -t claude-sandbox .
```

To rebuild from scratch (e.g. after changing the Dockerfile):

```bash
docker rmi claude-sandbox && docker build -t claude-sandbox .
```

## Usage

```bash
# Interactive Claude Code session in the current directory
./run.sh

# Skip permission prompts (requires non-root container user)
./run.sh --dangerously-skip-permissions
```

`run.sh` will automatically build the Docker image if it doesn't exist yet. It validates that you are not running from your home directory to prevent accidentally mounting your entire home folder.

## How It Works

1. `run.sh` retrieves your API key (from `$ANTHROPIC_API_KEY` or the macOS keychain) and launches the container via Docker Compose.
2. `entrypoint.sh` stashes the API key into `/tmp/claude-api-key` and removes it from the environment, preventing Claude Code from showing "custom API key detected" prompts.
3. `claude-api-key.sh` is registered as the `apiKeyHelper` in Claude's settings so it can retrieve the key on demand.
4. The current working directory on the host is mounted into the container at the same absolute path, so Claude's session/project keys match between host and container (enabling `--resume`).

## Claude Config Isolation

The container's `~/.claude` lives in a named Docker volume (`claude-config`) and is **never bind-mounted from the host**. This means the sandbox cannot corrupt your host Claude settings (e.g. injecting `apiKeyHelper`).

Both `~/.claude/sessions` and `~/.claude/projects` are bind-mounted from the host, and the workspace is mounted at the same absolute path as on the host. Together these ensure `--resume <session-id>` works interchangeably between the sandbox and your host Claude installation. `run.sh` creates these directories automatically if they don't exist.

## Permissions

Claude's permissions are configured in `claude-settings.json` using an allowlist/denylist model.

**Allowed:**
- File operations: `Glob`, `Grep`, `Read`, `Write`, `Edit`
- Network: `WebFetch`, `WebSearch`
- Package management: npm, yarn, pip (non-destructive)
- Kubernetes read operations (`kubectl get`, `kubectl describe`, `kubectl logs`, etc.)

**Denied:**
- `git push --force`, `git reset --hard`, `git clean`
- `kubectl delete`
- `rm -rf`

## Mounted Configuration

The container mounts the following host directories (read-only unless noted):

| Host Path | Purpose |
|-----------|---------|
| `~/.npmrc` | npm authentication |
| `~/.gitconfig` | Git identity |
| `~/.ssh` | SSH keys |
| `~/.kube` | Kubernetes config |
| `~/.aws` | AWS credentials |

## Pre-installed Tools

| Category | Tools |
|----------|-------|
| Runtime | Node.js 20, fnm |
| Version control | Git, GitHub CLI (`gh`) |
| Kubernetes | `kubectl`, `kubectx`, `kubens` |
| Databases | `mongosh`, MySQL client, Redis CLI |
| GitOps | ArgoCD CLI |
| Utilities | `jq`, `curl`, `wget`, `vim`, `tmux` |

## Dev Container

The repo includes a `devcontainer.json` for opening the project directly in a VS Code Dev Container, which provides the same environment without needing to run `run.sh` manually.
