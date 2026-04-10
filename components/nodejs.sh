# Component: Node.js + npm
# Sourced by install.sh — do not execute directly.

install_nodejs() {
    log_info "Installing Node.js ${NODEJS_VERSION}..."

    case "${OS_FAMILY}" in
        rhel)
            # pkg_module_enable "nodejs:${NODEJS_VERSION}"
            pkg_install nodejs npm
            ;;
        debian)
            # Use NodeSource setup
            if ! is_installed curl; then
                pkg_install curl ca-certificates gnupg
            fi
            local nodesource_key="/etc/apt/keyrings/nodesource.gpg"
            local nodesource_list="/etc/apt/sources.list.d/nodesource.list"
            _sudo mkdir -p /etc/apt/keyrings
            curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | _sudo gpg --dearmor -o "${nodesource_key}" --yes
            echo "deb [signed-by=${nodesource_key}] https://deb.nodesource.com/node_${NODEJS_VERSION}.x nodistro main" | _sudo tee "${nodesource_list}" >/dev/null
            _sudo apt-get update -qq
            pkg_install nodejs
            ;;
        macos)
            pkg_install "node@${NODEJS_VERSION}"
            # Ensure node@VERSION is linked
            brew link --overwrite "node@${NODEJS_VERSION}" 2>/dev/null || true
            ;;
        *)
            log_error "Unsupported OS for Node.js"
            return 1
            ;;
    esac

    # Configure npm prefix for non-root users (workstation mode)
    if [[ "${USE_SUDO}" == "true" ]] && [[ "${IS_CONTAINER}" == "false" ]]; then
        local npm_prefix="${HOME}/.npm-global"
        mkdir -p "${npm_prefix}"
        npm config set prefix "${npm_prefix}" 2>/dev/null || true
        export PATH="${npm_prefix}/bin:${PATH}"
        # Persist to shell profile if not already there
        local shell_profile="${HOME}/.bashrc"
        [[ -f "${HOME}/.zshrc" ]] && shell_profile="${HOME}/.zshrc"
        if ! grep -q '.npm-global' "${shell_profile}" 2>/dev/null; then
            {
                echo ''
                echo '# npm global prefix'
                echo 'export PATH="${HOME}/.npm-global/bin:${PATH}"'
            } >> "${shell_profile}"
        fi
    fi

    local ver
    ver="$(get_version node --version)"
    log_success "Node.js installed: ${ver}"
    record_result "Node.js" "OK" "${ver}"
}
