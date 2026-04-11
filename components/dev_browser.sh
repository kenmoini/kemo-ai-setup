# Component: dev-browser (browser automation for AI agents)
# Sourced by install.sh — do not execute directly.
#
# Installs dev-browser as a global npm package, then runs
# `dev-browser install` to fetch Playwright and Chromium.
# Reference: https://github.com/SawyerHood/dev-browser

install_dev_browser() {
    ensure_dependency "Node.js" install_nodejs node

    log_info "Installing dev-browser..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: npm install -g dev-browser"
        record_result "dev-browser" "DRY-RUN" ""
        return 0
    fi

    npm install -g dev-browser

    # Download Playwright and Chromium dependencies
    log_info "Running dev-browser install (fetching browser dependencies)..."
    dev-browser install || log_warn "dev-browser install returned non-zero; browser deps may be incomplete"

    local ver
    ver="$(get_version dev-browser --version)"
    log_success "dev-browser installed: ${ver}"
    record_result "dev-browser" "OK" "${ver}"
}
