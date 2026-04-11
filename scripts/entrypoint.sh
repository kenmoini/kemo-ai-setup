#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh - Container entrypoint
#
# Sets up PATH for tools installed to non-standard locations,
# optionally prints installed tool versions, and execs into CMD.
# =============================================================================

# --- PATH setup ---
# npm global prefix (container installs as root to /usr/local, no change needed)
# For non-root user scenarios:
[[ -d "${HOME}/.npm-global/bin" ]]   && export PATH="${HOME}/.npm-global/bin:${PATH}"

# Rust (rustup)
[[ -f "${HOME}/.cargo/env" ]]        && source "${HOME}/.cargo/env"

# Bun
[[ -d "${HOME}/.bun/bin" ]]          && export PATH="${HOME}/.bun/bin:${PATH}"

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

# --- Version banner (optional) ---
if [[ "${SHOW_VERSIONS:-false}" == "true" ]]; then
    echo "=== Installed Tools ==="
    for cmd in node npm npx pnpm bun claude codex gemini go python3 rustc php java mvn gradle git gcc make; do
        if command -v "${cmd}" &>/dev/null; then
            if [[ "${cmd}" == "go" ]]; then
                ver="$(go version 2>/dev/null)" || ver="(unknown)"
            elif [[ "${cmd}" == "gradle" ]]; then
                ver="$(gradle --version 2>/dev/null | grep -oP 'Gradle \K[0-9.]+')" || ver="(unknown)"
            else
                ver="$("${cmd}" --version 2>/dev/null | head -1)" || ver="$("${cmd}" version 2>/dev/null | head -1)" || ver="(unknown)"
            fi
            printf "  %-12s %s\n" "${cmd}" "${ver}"
        fi
    done
    echo "======================="
    echo ""
fi

# --- Exec into CMD ---
exec "$@"
