# Component: OpenJDK
# Sourced by install.sh — do not execute directly.

install_openjdk() {
    log_info "Installing OpenJDK ${OPENJDK_VERSION}..."

    case "${OS_FAMILY}" in
        rhel)
            pkg_install "java-${OPENJDK_VERSION}-openjdk-devel"
            ;;
        debian)
            pkg_install "openjdk-${OPENJDK_VERSION}-jdk"
            ;;
        macos)
            pkg_install "openjdk@${OPENJDK_VERSION}"
            # Link so system java wrappers find it
            _sudo ln -sfn "$(brew --prefix openjdk@${OPENJDK_VERSION})/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-${OPENJDK_VERSION}.jdk 2>/dev/null || true
            ;;
        *)
            log_error "Unsupported OS for OpenJDK"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version java -version 2>&1 | head -n 1)"
    log_success "OpenJDK installed: ${ver}"
    record_result "OpenJDK" "OK" "${ver}"
}
