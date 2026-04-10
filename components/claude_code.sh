# Component: Claude Code (@anthropic-ai/claude-code)
# Sourced by install.sh — do not execute directly.

install_claude_code() {
    ensure_dependency "Node.js" install_nodejs node

    log_info "Installing Claude Code..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: npm install -g @anthropic-ai/claude-code"
        record_result "Claude Code" "DRY-RUN" ""
        return 0
    fi

    npm install -g @anthropic-ai/claude-code

    local ver
    ver="$(get_version claude --version)"
    log_success "Claude Code installed: ${ver}"
    record_result "Claude Code" "OK" "${ver}"
}
