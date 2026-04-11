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
    npm cache clean --force

    # Download Playwright and Chromium dependencies
    log_info "Running dev-browser install (fetching browser dependencies)..."
    dev-browser install || log_warn "dev-browser install returned non-zero; browser deps may be incomplete"

    local ver
    ver="$(npm list -g dev-browser --depth=0 --json 2>/dev/null | jq -r '.dependencies["dev-browser"].version' 2>/dev/null)" || ver="(unknown)"
    log_success "dev-browser installed: ${ver}"
    record_result "dev-browser" "OK" "${ver}"
}
