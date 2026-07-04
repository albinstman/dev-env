FROM mcr.microsoft.com/devcontainers/base:ubuntu

# basics
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    ca-certificates \
    wget \
    git \
    jq \
    unzip \
    vim \
    less \
    tree \
    ripgrep \
    fd-find \
    htop \
    zsh \
    fzf \
    net-tools \
    dnsutils \
    iputils-ping \
    tar \
    openssh-client \
    python3 \
    python3-pip \
    make \
    g++ \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Persist bash history across container rebuilds
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir -p /commandhistory \
    && touch /commandhistory/.bash_history \
    && echo "$SNIPPET" >> /root/.bashrc

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*
