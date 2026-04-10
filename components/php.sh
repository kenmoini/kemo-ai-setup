# Component: PHP
# Sourced by install.sh — do not execute directly.

install_php() {
    log_info "Installing PHP ${PHP_VERSION}..."

    case "${OS_FAMILY}" in
        rhel)
            pkg_module_enable "php:${PHP_VERSION}"
            pkg_install php-cli php-common
            ;;
        debian)
            # Add Sury PPA for recent PHP versions
            if ! is_installed curl; then
                pkg_install curl ca-certificates gnupg
            fi
            _sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://packages.sury.org/php/apt.gpg | _sudo gpg --dearmor -o /etc/apt/keyrings/php-sury.gpg --yes
            echo "deb [signed-by=/etc/apt/keyrings/php-sury.gpg] https://packages.sury.org/php/ $(lsb_release -cs) main" | _sudo tee /etc/apt/sources.list.d/php-sury.list >/dev/null
            _sudo apt-get update -qq
            pkg_install "php${PHP_VERSION}-cli" "php${PHP_VERSION}-common"
            ;;
        macos)
            pkg_install "php@${PHP_VERSION}"
            brew link --overwrite "php@${PHP_VERSION}" 2>/dev/null || true
            ;;
        *)
            log_error "Unsupported OS for PHP"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version php --version)"
    log_success "PHP installed: ${ver}"
    record_result "PHP" "OK" "${ver}"
}
