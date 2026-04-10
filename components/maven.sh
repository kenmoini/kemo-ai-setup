# Component: Maven
# Sourced by install.sh — do not execute directly.

install_maven() {
    ensure_dependency "OpenJDK" install_openjdk java

    log_info "Installing Maven..."

    case "${OS_FAMILY}" in
        rhel)
            pkg_module_enable "maven:${MAVEN_VERSION}"
            pkg_install maven
            ;;
        debian)
            pkg_install maven
            ;;
        macos)
            pkg_install maven
            ;;
        *)
            log_error "Unsupported OS for Maven"
            return 1
            ;;
    esac

    local ver
    ver="$(get_version mvn --version)"
    log_success "Maven installed: ${ver}"
    record_result "Maven" "OK" "${ver}"
}
