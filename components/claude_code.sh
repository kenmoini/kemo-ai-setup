# Component: Claude Code (@anthropic-ai/claude-code)
# Sourced by install.sh — do not execute directly.

install_claude_code() {
    ensure_dependency "Node.js" install_nodejs node

    log_info "Installing Claude Code..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: curl -fsSL https://claude.ai/install.sh | bash"
        record_result "Claude Code" "DRY-RUN" ""
        return 0
    fi

    curl -fsSL https://claude.ai/install.sh | bash
    npm cache clean --force

    local ver
    ver="$(get_version claude --version)"
    log_success "Claude Code installed: ${ver}"
    record_result "Claude Code" "OK" "${ver}"
}
