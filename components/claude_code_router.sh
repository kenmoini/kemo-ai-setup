# Component: Claude Code Router (@musistudio/claude-code-router)
# Sourced by install.sh — do not execute directly.
#
# Routes Claude Code requests to different AI model providers.
# Reference: https://github.com/musistudio/claude-code-router

install_claude_code_router() {
    ensure_dependency "Node.js" install_nodejs node

    log_info "Installing Claude Code Router..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: npm install -g @musistudio/claude-code-router"
        record_result "Claude Code Router" "DRY-RUN" ""
        return 0
    fi

    npm install -g @musistudio/claude-code-router

    local ver
    ver="$(ccr -v 2>/dev/null | awk '{print $2}')" || ver="(unknown)"
    log_success "Claude Code Router installed: ${ver}"
    record_result "Claude Code Router" "OK" "${ver}"
}
