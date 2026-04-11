# Component: Codex CLI (@openai/codex)
# Sourced by install.sh — do not execute directly.

install_codex() {
    ensure_dependency "Node.js" install_nodejs node

    log_info "Installing Codex CLI..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: npm install -g @openai/codex"
        record_result "Codex CLI" "DRY-RUN" ""
        return 0
    fi

    npm install -g @openai/codex
    npm cache clean --force

    local ver
    ver="$(get_version codex --version)"
    log_success "Codex CLI installed: ${ver}"
    record_result "Codex CLI" "OK" "${ver}"
}
