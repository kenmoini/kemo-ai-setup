# Component: Build Essentials (gcc, g++, make)
# Sourced by install.sh — do not execute directly.

install_build_essentials() {
    log_info "Installing build essentials (gcc, g++, make)..."

    case "${OS_FAMILY}" in
        rhel)
            pkg_install gcc gcc-c++ make automake autoconf pkgconfig which
            pkg_install nspr nss atk dbus-libs cups-libs libxkbcommon at-spi2-atk libXcomposite libXdamage libXfixes libXrandr mesa-libgbm pango alsa-lib
            ;;
        debian)
            pkg_install build-essential pkg-config which
            pkg_install libnspr4 libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libdbus-1-3 libcups2t64 libxkbcommon0 libatspi2.0-0t64 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libasound2t64
            ;;
        macos)
            pkg_install bash
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
