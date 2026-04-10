# Component: Bun
# Sourced by install.sh — do not execute directly.

install_bun() {
    log_info "Installing Bun..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install Bun"
        record_result "Bun" "DRY-RUN" ""
        return 0
    fi

    case "${OS_FAMILY}" in
        macos)
            pkg_install oven-sh/bun/bun
            ;;
        rhel|debian)
            if ! is_installed curl; then
                pkg_install curl
            fi
            if [[ "${BUN_VERSION}" == "latest" ]]; then
                curl -fsSL https://bun.sh/install | bash
            else
                curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}"
            fi
            # Source the bun env for the current session
            export BUN_INSTALL="${HOME}/.bun"
            export PATH="${BUN_INSTALL}/bin:${PATH}"
            ;;
        *)
            log_error "Unsupported OS for Bun"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version bun --version)"
    log_success "Bun installed: ${ver}"
    record_result "Bun" "OK" "${ver}"
}
