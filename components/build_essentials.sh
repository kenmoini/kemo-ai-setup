# Component: Build Essentials (gcc, g++, make)
# Sourced by install.sh — do not execute directly.

install_build_essentials() {
    log_info "Installing build essentials (gcc, g++, make)..."

    case "${OS_FAMILY}" in
        rhel)
            pkg_install gcc gcc-c++ make automake autoconf pkgconfig
            ;;
        debian)
            pkg_install build-essential pkg-config
            ;;
        macos)
            if xcode-select -p &>/dev/null; then
                log_info "Xcode Command Line Tools already present"
            else
                log_info "Installing Xcode Command Line Tools..."
                xcode-select --install 2>/dev/null || true
                log_warn "You may need to accept the Xcode CLT dialog and re-run this script"
            fi
            ;;
        *)
            log_error "Unsupported OS for build essentials"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version gcc --version)"
    log_success "Build essentials installed: ${ver}"
    record_result "Build Essentials" "OK" "${ver}"
}
