# Component: Go
# Sourced by install.sh — do not execute directly.

install_golang() {
    log_info "Installing Go..."

    case "${OS_FAMILY}" in
        rhel)
            pkg_install golang
            ;;
        debian)
            # Download from golang.org for a recent version
            if ! is_installed curl; then
                pkg_install curl
            fi
            local go_arch="${ARCH}"
            [[ "${go_arch}" == "x86_64" ]] && go_arch="amd64"
            [[ "${go_arch}" == "aarch64" ]] && go_arch="arm64"
            local go_tar="go${GOLANG_VERSION}.linux-${go_arch}.tar.gz"
            curl -fsSL "https://go.dev/dl/${go_tar}" -o "/tmp/${go_tar}"
            _sudo rm -rf /usr/local/go
            _sudo tar -C /usr/local -xzf "/tmp/${go_tar}"
            rm -f "/tmp/${go_tar}"
            export PATH="/usr/local/go/bin:${PATH}"
            # Persist PATH
            local shell_profile="${HOME}/.bashrc"
            [[ -f "${HOME}/.zshrc" ]] && shell_profile="${HOME}/.zshrc"
            if ! grep -q '/usr/local/go/bin' "${shell_profile}" 2>/dev/null; then
                echo 'export PATH="/usr/local/go/bin:${PATH}"' >> "${shell_profile}"
            fi
            ;;
        macos)
            pkg_install go
            ;;
        *)
            log_error "Unsupported OS for Go"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version go version)"
    log_success "Go installed: ${ver}"
    record_result "Go" "OK" "${ver}"
}
