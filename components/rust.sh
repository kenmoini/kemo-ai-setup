# Component: Rust
# Sourced by install.sh — do not execute directly.

install_rust() {
    log_info "Installing Rust (method: ${RUST_INSTALL_METHOD})..."

    if [[ "${RUST_INSTALL_METHOD}" == "rustup" ]] || [[ "${OS_FAMILY}" == "macos" ]]; then
        # Use rustup for upstream installer
        if ! is_installed curl; then
            case "${OS_FAMILY}" in
                rhel)   pkg_install curl ;;
                debian) pkg_install curl ca-certificates ;;
            esac
        fi
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        export PATH="${HOME}/.cargo/bin:${PATH}"
        # Persist PATH
        local shell_profile="${HOME}/.bashrc"
        [[ -f "${HOME}/.zshrc" ]] && shell_profile="${HOME}/.zshrc"
        if ! grep -q '.cargo/bin' "${shell_profile}" 2>/dev/null; then
            echo 'source "${HOME}/.cargo/env" 2>/dev/null || true' >> "${shell_profile}"
        fi
    else
        # Use system packages
        case "${OS_FAMILY}" in
            rhel)
                pkg_install rust cargo
                ;;
            debian)
                pkg_install rustc cargo
                ;;
            *)
                log_error "Unsupported OS for system Rust packages"
                return 1
                ;;
        esac
    fi

    local ver
    ver="$(get_version rustc --version)"
    log_success "Rust installed: ${ver}"
    record_result "Rust" "OK" "${ver}"
}
