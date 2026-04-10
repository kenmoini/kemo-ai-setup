# Component: Git
# Sourced by install.sh — do not execute directly.

install_git() {
    log_info "Installing Git..."

    case "${OS_FAMILY}" in
        rhel)
            pkg_install git
            ;;
        debian)
            pkg_install git
            ;;
        macos)
            pkg_install git
            ;;
        *)
            log_error "Unsupported OS for Git"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version git --version)"
    log_success "Git installed: ${ver}"
    record_result "Git" "OK" "${ver}"
}
