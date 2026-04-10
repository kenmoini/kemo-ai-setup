# Component: pnpm
# Sourced by install.sh — do not execute directly.

install_pnpm() {
    ensure_dependency "Node.js" install_nodejs node

    log_info "Installing pnpm..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: npm install -g pnpm"
        record_result "pnpm" "DRY-RUN" ""
        return 0
    fi

    npm install -g pnpm

    local ver
    ver="$(get_version pnpm --version)"
    log_success "pnpm installed: ${ver}"
    record_result "pnpm" "OK" "${ver}"
}
