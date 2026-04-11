# Component: Gradle
# Sourced by install.sh — do not execute directly.

install_gradle() {
    ensure_dependency "OpenJDK" install_openjdk java

    log_info "Installing Gradle ${GRADLE_VERSION}..."

    case "${OS_FAMILY}" in
        macos)
            pkg_install gradle
            ;;
        rhel|debian)
            # Download from upstream
            if ! is_installed curl; then
                pkg_install curl
            fi
            if ! is_installed unzip; then
                pkg_install unzip
            fi
            local gradle_zip="gradle-${GRADLE_VERSION}-bin.zip"
            curl -fsSL "https://services.gradle.org/distributions/${gradle_zip}" -o "/tmp/${gradle_zip}"
            _sudo mkdir -p /opt/gradle
            _sudo unzip -qo "/tmp/${gradle_zip}" -d /opt/gradle
            rm -f "/tmp/${gradle_zip}"
            # Create symlink
            _sudo ln -sf "/opt/gradle/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle
            ;;
        *)
            log_error "Unsupported OS for Gradle"
            return 1
            ;;
    esac

    local ver
    gradleVersion=$(gradle --version 2>/dev/null | head -n3 | tail -n1)
    # ver="$(get_version gradle --version 2>/dev/null | head -n3 | tail -n1)"
    log_success "Gradle installed: ${gradleVersion}"
    record_result "Gradle" "OK" "${gradleVersion}"
}
