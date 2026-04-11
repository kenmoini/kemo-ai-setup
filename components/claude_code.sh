# Component: Claude Code (Anthropic's AI coding agent)
# Sourced by install.sh — do not execute directly.
#
# Installs Claude Code via the official install script.
# Installs to ~/.local/bin/claude and ~/.local/share/claude.
# Standalone — does not require Node.js.
# Reference: https://docs.anthropic.com/en/docs/claude-code/getting-started

# Install system-level dependencies needed by the Claude Code installer.
# Called by install.sh even when the install itself is deferred to user-install.sh.
install_claude_code_deps() {
    if ! is_installed curl; then
        case "${OS_FAMILY}" in
            rhel)   pkg_install curl ;;
            debian) pkg_install curl ca-certificates ;;
        esac
    fi
}

install_claude_code() {
    log_info "Installing Claude Code..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: curl -fsSL https://claude.ai/install.sh | bash"
        record_result "Claude Code" "DRY-RUN" ""
        return 0
    fi

    if ! is_installed curl; then
        case "${OS_FAMILY}" in
            rhel)   pkg_install curl ;;
            debian) pkg_install curl ca-certificates ;;
        esac
    fi

    curl -fsSL https://claude.ai/install.sh | bash

    # Add to PATH for current session
    [[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

    if [[ "${OS_FAMILY}" != "macos" ]]; then
        if [[ "$UID" -eq 0 ]]; then
            cp -R /root/.local/bin/claude /home/dev/.local/bin/claude 2>/dev/null || true
            cp -R /root/.local/share/claude /home/dev/.local/share/claude 2>/dev/null || true
            chown -R dev:dev /home/dev/.local 2>/dev/null || true
        fi
    fi

    local ver
    ver="$(get_version claude --version)"
    log_success "Claude Code installed: ${ver}"
    record_result "Claude Code" "OK" "${ver}"
}
