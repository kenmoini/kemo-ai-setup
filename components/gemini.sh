# Component: Gemini CLI (@google/gemini-cli)
# Sourced by install.sh — do not execute directly.

install_gemini() {
    ensure_dependency "Node.js" install_nodejs node

    log_info "Installing Gemini CLI..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: npm install -g @google/gemini-cli"
        record_result "Gemini CLI" "DRY-RUN" ""
        return 0
    fi

    npm install -g @google/gemini-cli
    npm cache clean --force

    local ver
    ver="$(get_version gemini --version)"
    log_success "Gemini CLI installed: ${ver}"
    record_result "Gemini CLI" "OK" "${ver}"
}
