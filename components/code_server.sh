# Component: Code Server (VS Code in the browser)
# Sourced by install.sh — do not execute directly.
#
# Installs code-server from https://github.com/coder/code-server
# Default port: 8080

install_code_server() {
    log_info "Installing Code Server..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install Code Server"
        record_result "Code Server" "DRY-RUN" ""
        return 0
    fi

    case "${OS_FAMILY}" in
        macos)
            pkg_install code-server
            ;;
        rhel|debian)
            if ! is_installed curl; then
                pkg_install curl
            fi
            curl -fsSL https://code-server.dev/install.sh | sh
            ;;
        *)
            log_error "Unsupported OS for Code Server"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version code-server --version | tail -n 1)"
    log_success "Code Server installed: ${ver}"
    record_result "Code Server" "OK" "${ver}"
}
