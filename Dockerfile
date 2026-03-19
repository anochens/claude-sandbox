FROM node:22-bookworm-slim

# --- URLs / Download Sources ---
ARG ARGOCD_DOWNLOAD_URL=https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
ARG FNM_INSTALL_URL=https://fnm.vercel.app/install
ARG GH_CLI_APT_REPO=https://cli.github.com/packages
ARG GH_CLI_GPG_URL=https://cli.github.com/packages/githubcli-archive-keyring.gpg
ARG KUBECTL_DOWNLOAD_URL=https://dl.k8s.io/release
ARG KUBECTL_VERSION_URL=https://dl.k8s.io/release/stable.txt
ARG KUBECTX_API_URL=https://api.github.com/repos/ahmetb/kubectx/releases/latest
ARG KUBECTX_DOWNLOAD_URL=https://github.com/ahmetb/kubectx/releases/download
ARG MONGODB_APT_REPO=https://repo.mongodb.org/apt/debian
ARG MONGODB_GPG_URL=https://www.mongodb.org/static/pgp/server-7.0.asc

# Install base tools
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    jq \
    vim \
    tmux \
    openssh-client \
    ca-certificates \
    gnupg \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL ${GH_CLI_GPG_URL} \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] ${GH_CLI_APT_REPO} stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Symlink gh to the path .gitconfig expects (macOS homebrew path)
RUN mkdir -p /opt/homebrew/bin && ln -s $(which gh) /opt/homebrew/bin/gh

# Install kubectl
RUN curl -fsSL "${KUBECTL_DOWNLOAD_URL}/$(curl -L -s ${KUBECTL_VERSION_URL})/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install kubens + kubectx (kns)
RUN KUBECTX_VERSION=$(curl -s ${KUBECTX_API_URL} | grep '"tag_name"' | cut -d'"' -f4) \
    && curl -fsSL "${KUBECTX_DOWNLOAD_URL}/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin kubens \
    && curl -fsSL "${KUBECTX_DOWNLOAD_URL}/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin kubectx \
    && ln -s /usr/local/bin/kubens /usr/local/bin/kns

# Install mongosh
RUN curl -fsSL ${MONGODB_GPG_URL} \
    | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg \
    && echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] ${MONGODB_APT_REPO} bookworm/mongodb-org/7.0 main" \
    | tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null \
    && apt-get update && apt-get install -y mongodb-mongosh \
    && rm -rf /var/lib/apt/lists/*

# Install MySQL client and Redis CLI
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Install ArgoCD CLI
RUN curl -fsSL "${ARGOCD_DOWNLOAD_URL}" \
    -o /usr/local/bin/argocd \
    && chmod +x /usr/local/bin/argocd

# Install fnm (Fast Node Manager)
RUN curl -fsSL ${FNM_INSTALL_URL} | bash -s -- --install-dir /usr/local/bin --skip-shell

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Bake in Claude Code permission settings
RUN mkdir -p /root/.claude
COPY claude-settings.json /root/.claude/settings.json

# Write settings.local.json with onboarding flags stamped with current version
RUN CLAUDE_VERSION=$(node -e "console.log(require('/usr/local/lib/node_modules/@anthropic-ai/claude-code/package.json').version)") \
    && jq -n --arg v "$CLAUDE_VERSION" \
      '{hasCompletedOnboarding: true, lastOnboardingVersion: $v, loginMethod: "apiKey"}' \
    > /root/.claude/settings.local.json

# Create symlink so absolute SSH paths in .gitconfig resolve correctly
RUN mkdir -p /Users/aron.nochensonpostman.com && ln -s /root/.ssh /Users/aron.nochensonpostman.com/.ssh

WORKDIR /workspace
