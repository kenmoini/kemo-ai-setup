#!/bin/bash

# Script: dev-paths.sh
# Purpose: Set up PATH for tools installed

echo "Setting up PATH for development tools..."

# --- PATH setup ---
# Claude Code (native installer)
[[ -d "${HOME}/.local/bin" ]]        && export PATH="${HOME}/.local/bin:${PATH}"

# npm global prefix (container installs as root to /usr/local, no change needed)
# For non-root user scenarios:
[[ -d "${HOME}/.npm-global/bin" ]]   && export PATH="${HOME}/.npm-global/bin:${PATH}"

# Rust (rustup)
[[ -f "${HOME}/.cargo/env" ]]        && source "${HOME}/.cargo/env"

# Bun
[[ -d "${HOME}/.bun/bin" ]]          && export PATH="${HOME}/.bun/bin:${PATH}"

# OpenCode
[[ -d "${HOME}/.opencode/bin" ]]     && export PATH="${HOME}/.opencode/bin:${PATH}"

# pyenv
if [[ -d "${HOME}/.pyenv" ]]; then
    export PYENV_ROOT="${HOME}/.pyenv"
    [[ -d "${PYENV_ROOT}/bin" ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"
    eval "$(pyenv init - bash)" 2>/dev/null || true
fi

# Go (direct install)
[[ -d "/usr/local/go/bin" ]]         && export PATH="/usr/local/go/bin:${PATH}"

# Gradle (direct install)
[[ -d "/opt/gradle" ]]               && export PATH="/opt/gradle/gradle-*/bin:${PATH}"
