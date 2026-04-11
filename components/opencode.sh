# Component: OpenCode (open-source AI coding agent)
# Sourced by install.sh — do not execute directly.
#
# Installs OpenCode via the official install script.
# Installs to $HOME/.opencode/bin by default.
# Reference: https://github.com/anomalyco/opencode

# Install system-level dependencies needed by the OpenCode installer.
# Called by install.sh even when the install itself is deferred to user-install.sh.
install_opencode_deps() {
    if ! is_installed curl; then
        case "${OS_FAMILY}" in
            rhel)   pkg_install curl ;;
            debian) pkg_install curl ;;
        esac
    fi
}

install_opencode() {
    log_info "Installing OpenCode..."

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install OpenCode"
        record_result "OpenCode" "DRY-RUN" ""
        return 0
    fi

    if ! is_installed curl; then
        case "${OS_FAMILY}" in
            rhel)   pkg_install curl ;;
            debian) pkg_install curl ca-certificates ;;
        esac
    fi

    curl -fsSL https://opencode.ai/install | bash

    # Add to PATH for current session
    [[ -d "${HOME}/.opencode/bin" ]] && export PATH="${HOME}/.opencode/bin:${PATH}"

    if [[ "${OS_FAMILY}" != "macos" ]]; then
        if [[ "$UID" -eq 0 ]]; then
            cp -R /root/.opencode /home/dev/.opencode 2>/dev/null || true
            chown -R dev:dev /home/dev/.opencode 2>/dev/null || true
        fi
    fi

    local ver
    ver="$(get_version opencode --version)"
    log_success "OpenCode installed: ${ver}"
    record_result "OpenCode" "OK" "${ver}"
}
