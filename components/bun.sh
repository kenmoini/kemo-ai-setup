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
            if ! is_installed unzip; then
                pkg_install unzip
            fi
            if [[ "${BUN_VERSION}" == "latest" ]]; then
                curl -fsSL https://bun.sh/install | bash
            else
                curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}"
            fi
            # Source the bun env for the current session
            export BUN_INSTALL="${HOME}/.bun"
            export PATH="${BUN_INSTALL}/bin:${PATH}"

            # Save the bun env to the global profile.d for future sessions
            if [[ -d /etc/profile.d ]]; then
                echo "export BUN_INSTALL=\"${BUN_INSTALL}\"" | sudo tee /etc/profile.d/bun.sh
                echo "export PATH=\"${BUN_INSTALL}/bin:\$PATH\"" | sudo tee -a /etc/profile.d/bun.sh
                chmod +x /etc/profile.d/bun.sh
            fi
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

    if [[ "${OS_FAMILY}" != "macos" ]]; then
        if [[ "$UID" -eq 0 ]]; then
            cp -R /root/.bun /home/dev/.bun 2>/dev/null || true
            chown -R dev:dev /home/dev/.bun 2>/dev/null || true
        fi
    fi
}
