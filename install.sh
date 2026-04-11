#!/usr/bin/env bash
# =============================================================================
# install.sh - Agentic AI Development Environment Installer
#
# Dual-use script: runs inside a container (during build) or on a host
# workstation (macOS, Fedora/RHEL, Debian/Ubuntu).
#
# Usage:
#   ./install.sh [--force] [--dry-run] [--help]
#
# Components are controlled via ENABLE_* environment variables.
# See .env.example for the full list.
# =============================================================================
set -euo pipefail

# Associative arrays require Bash 4+. macOS ships Bash 3.2; re-exec under
# Homebrew's modern bash when available to avoid "unbound variable" errors.
if (( BASH_VERSINFO[0] < 4 )); then
    for _bash in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "${_bash}" ]] && "${_bash}" -c '(( BASH_VERSINFO[0] >= 4 ))' 2>/dev/null; then
            exec "${_bash}" "$0" "$@"
        fi
    done
    echo "ERROR: Bash 4+ is required (found ${BASH_VERSION})." >&2
    echo "On macOS, install it with:  brew install bash" >&2
    exit 1
fi

# =============================================================================
# Section 1: Constants and Defaults
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Source version pins if available
if [[ -f "${SCRIPT_DIR}/versions.env" ]]; then
    # shellcheck source=versions.env
    source "${SCRIPT_DIR}/versions.env"
elif [[ -f "/tmp/versions.env" ]]; then
    source "/tmp/versions.env"
fi

# Version defaults (fallbacks if versions.env not found)
NODEJS_VERSION="${NODEJS_VERSION:-22}"
GOLANG_VERSION="${GOLANG_VERSION:-1.24.2}"
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"
PHP_VERSION="${PHP_VERSION:-8.3}"
MAVEN_VERSION="${MAVEN_VERSION:-3.9}"
GRADLE_VERSION="${GRADLE_VERSION:-8.12}"
BUN_VERSION="${BUN_VERSION:-latest}"
RUST_INSTALL_METHOD="${RUST_INSTALL_METHOD:-rustup}"
PYTHON_VERSION="${PYTHON_VERSION:-3.14}"

# Component toggle defaults (only set if not already defined)
ENABLE_GIT="${ENABLE_GIT:-true}"
ENABLE_BUILD_ESSENTIALS="${ENABLE_BUILD_ESSENTIALS:-true}"
ENABLE_NODEJS="${ENABLE_NODEJS:-true}"
ENABLE_PNPM="${ENABLE_PNPM:-false}"
ENABLE_BUN="${ENABLE_BUN:-false}"
ENABLE_CLAUDE_CODE="${ENABLE_CLAUDE_CODE:-true}"
ENABLE_CODEX="${ENABLE_CODEX:-false}"
ENABLE_GEMINI="${ENABLE_GEMINI:-false}"
ENABLE_PYTHON="${ENABLE_PYTHON:-true}"
ENABLE_GOLANG="${ENABLE_GOLANG:-false}"
ENABLE_RUST="${ENABLE_RUST:-false}"
ENABLE_PHP="${ENABLE_PHP:-false}"
ENABLE_OPENJDK="${ENABLE_OPENJDK:-false}"
ENABLE_MAVEN="${ENABLE_MAVEN:-false}"
ENABLE_GRADLE="${ENABLE_GRADLE:-false}"
ENABLE_CODE_SERVER="${ENABLE_CODE_SERVER:-false}"

# Flags
FORCE=false
DRY_RUN=false
ROOT_INSTALL=false

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

# Summary tracking
declare -a SUMMARY_COMPONENTS=()
declare -a SUMMARY_STATUSES=()
declare -a SUMMARY_VERSIONS=()

# =============================================================================
# Section 2: Argument Parsing
# =============================================================================

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Installs development tools for agentic AI development.
Components are controlled via ENABLE_* environment variables.

Options:
  --force         Reinstall components even if already present
  --dry-run       Show what would be installed without making changes
  --root-install  Install user-scoped components (pyenv, rustup, bun) even
                  when running as root. Without this flag, these are deferred
                  to user-install.sh so they install into the correct \$HOME.
  --help          Show this help message

Examples:
  # Install with defaults
  ./install.sh

  # Enable Go and Rust
  ENABLE_GOLANG=true ENABLE_RUST=true ./install.sh

  # Force reinstall everything
  ./install.sh --force

  # Source .env and install
  source .env && ./install.sh
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)  FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --root-install) ROOT_INSTALL=true; shift ;;
        --help)   usage ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# =============================================================================
# Section 3: OS and Environment Detection
# =============================================================================

log_info()    { echo -e "${BLUE}===== [INFO] ========================${RESET}    $*"; }
log_success() { echo -e "${GREEN}===== [OK] ========================${RESET}      $*"; }
log_warn()    { echo -e "${YELLOW}===== [WARN] ========================${RESET}    $*"; }
log_error()   { echo -e "${RED}===== [ERROR] ========================${RESET}   $*"; }
log_skip()    { echo -e "${YELLOW}===== [SKIP] ========================${RESET}    $*"; }
log_dry()     { echo -e "${BOLD}===== [DRY-RUN] ========================${RESET} $*"; }

detect_os() {
    OS_FAMILY="unknown"
    PKG_MANAGER="unknown"
    ARCH="$(uname -m)"

    case "$(uname -s)" in
        Darwin)
            OS_FAMILY="macos"
            PKG_MANAGER="brew"
            ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                # shellcheck source=/dev/null
                source /etc/os-release
                case "${ID:-}" in
                    rhel|centos|rocky|alma|fedora)
                        OS_FAMILY="rhel"
                        ;;
                    debian|ubuntu|pop|mint|linuxmint)
                        OS_FAMILY="debian"
                        ;;
                    *)
                        # Check ID_LIKE for derivatives
                        case "${ID_LIKE:-}" in
                            *rhel*|*fedora*|*centos*)
                                OS_FAMILY="rhel"
                                ;;
                            *debian*|*ubuntu*)
                                OS_FAMILY="debian"
                                ;;
                        esac
                        ;;
                esac
            fi

            # Determine package manager for RHEL family
            if [[ "${OS_FAMILY}" == "rhel" ]]; then
                if command -v microdnf &>/dev/null; then
                    PKG_MANAGER="microdnf"
                elif command -v dnf &>/dev/null; then
                    PKG_MANAGER="dnf"
                elif command -v yum &>/dev/null; then
                    PKG_MANAGER="yum"
                fi
            elif [[ "${OS_FAMILY}" == "debian" ]]; then
                PKG_MANAGER="apt-get"
            fi
            ;;
    esac

    # Container detection
    IS_CONTAINER=false
    if [[ -f /.containerenv ]] || [[ -f /.dockerenv ]]; then
        IS_CONTAINER=true
    elif [[ "${container:-}" == "oci" ]] || [[ "${container:-}" == "podman" ]] || [[ "${container:-}" == "docker" ]]; then
        IS_CONTAINER=true
    fi

    # Sudo handling
    USE_SUDO=false
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        USE_SUDO=true
    fi

    log_info "Detected: OS=${OS_FAMILY} PKG=${PKG_MANAGER} ARCH=${ARCH} CONTAINER=${IS_CONTAINER} SUDO=${USE_SUDO}"
}

# =============================================================================
# Section 4: Package Manager Abstraction
# =============================================================================

_sudo() {
    if [[ "${USE_SUDO}" == "true" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

pkg_update() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would refresh package metadata"
        return 0
    fi

    log_info "Refreshing package metadata..."
    case "${PKG_MANAGER}" in
        dnf|yum)
            # _sudo "${PKG_MANAGER}" makecache -q --disablerepo="*" --enablerepo=ubi-9-appstream-rpms --enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-codeready-builder-rpms -y 2>/dev/null || true
            _sudo "${PKG_MANAGER}" makecache -q -y 2>/dev/null || true
            ;;
        microdnf)
            # microdnf refreshes on install; no explicit makecache needed
            ;;
        apt-get)
            _sudo apt-get update -qq
            ;;
        brew)
            brew update --quiet
            ;;
    esac
}

pkg_install() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install packages: $*"
        return 0
    fi

    case "${PKG_MANAGER}" in
        dnf|yum)
            local flags=(-y)
            # [[ "${IS_CONTAINER}" == "true" ]] && flags+=(--nodocs --disablerepo="*" --enablerepo=ubi-9-appstream-rpms --enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-codeready-builder-rpms --setopt=install_weak_deps=False)
            [[ "${IS_CONTAINER}" == "true" ]] && flags+=(--nodocs --setopt=install_weak_deps=False)
            _sudo "${PKG_MANAGER}" install "${flags[@]}" "$@"
            ;;
        microdnf)
            local flags=(-y)
            # [[ "${IS_CONTAINER}" == "true" ]] && flags+=(--nodocs --disablerepo="*" --enablerepo=ubi-9-appstream-rpms --enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-codeready-builder-rpms --setopt=install_weak_deps=0)
            [[ "${IS_CONTAINER}" == "true" ]] && flags+=(--nodocs --setopt=install_weak_deps=0)
            _sudo microdnf install "${flags[@]}" "$@"
            ;;
        apt-get)
            DEBIAN_FRONTEND=noninteractive _sudo apt-get install -y --no-install-recommends "$@"
            ;;
        brew)
            brew install "$@" 2>/dev/null || brew upgrade "$@" 2>/dev/null || true
            ;;
    esac
}

pkg_module_enable() {
    local module="$1"
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would enable module: ${module}"
        return 0
    fi

    case "${PKG_MANAGER}" in
        dnf|yum)
            # _sudo "${PKG_MANAGER}" module reset --disablerepo="*" --enablerepo=ubi-9-appstream-rpms --enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-codeready-builder-rpms -y "${module%%:*}" 2>/dev/null || true
            # _sudo "${PKG_MANAGER}" module enable --disablerepo="*" --enablerepo=ubi-9-appstream-rpms --enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-codeready-builder-rpms -y "${module}"
            _sudo "${PKG_MANAGER}" module reset -y "${module%%:*}" 2>/dev/null || true
            _sudo "${PKG_MANAGER}" module enable -y "${module}"
            ;;
        microdnf)
            _sudo microdnf module reset -y "${module%%:*}" 2>/dev/null || true
            _sudo microdnf module enable -y "${module}"
            ;;
        *)
            # Modules are RHEL-specific; no-op elsewhere
            ;;
    esac
}

pkg_clean() {
    if [[ "${IS_CONTAINER}" == "true" ]]; then
        log_info "Cleaning package cache..."
        case "${PKG_MANAGER}" in
            dnf|yum)
                _sudo "${PKG_MANAGER}" clean all
                _sudo rm -rf /var/cache/dnf /var/cache/yum
                ;;
            microdnf)
                _sudo microdnf clean all
                ;;
            apt-get)
                _sudo apt-get clean
                _sudo rm -rf /var/lib/apt/lists/*
                ;;
        esac
    fi
}

# =============================================================================
# Section 5: Utility Functions
# =============================================================================

is_installed() {
    command -v "$1" &>/dev/null
}

# Check if a component should be installed.
# Args: $1=ENABLE var name (e.g. "ENABLE_NODEJS"), $2=binary to check
should_install() {
    local enable_var="$1"
    local check_cmd="$2"
    local enable_val="${!enable_var:-false}"

    if [[ "${enable_val}" != "true" ]]; then
        return 1
    fi

    if [[ "${FORCE}" == "true" ]]; then
        return 0
    fi

    if is_installed "${check_cmd}"; then
        return 1  # already installed
    fi

    return 0
}

# Auto-enable and install a dependency if not present.
# Args: $1=component label, $2=install function, $3=binary to check
ensure_dependency() {
    local label="$1"
    local install_fn="$2"
    local check_cmd="$3"

    if ! is_installed "${check_cmd}"; then
        log_warn "Auto-enabling ${label} (required dependency)"
        "${install_fn}"
    fi
}

# Record result for summary table
record_result() {
    local component="$1"
    local status="$2"
    local version="${3:-}"
    SUMMARY_COMPONENTS+=("${component}")
    SUMMARY_STATUSES+=("${status}")
    SUMMARY_VERSIONS+=("${version}")
}

# Get version string safely
get_version() {
    local cmd="$1"
    shift
    if is_installed "${cmd}"; then
        "${cmd}" "$@" 2>/dev/null | head -1
    else
        echo "n/a"
    fi
}

# =============================================================================
# Section 6: Load Component Install Functions
# =============================================================================

# Components are loaded from individual files in the components/ directory.
# Each file defines an install_<component>() function.
# Look for components relative to the script, then in /tmp (container build).
COMPONENTS_DIR="${SCRIPT_DIR}/components"
if [[ ! -d "${COMPONENTS_DIR}" ]] && [[ -d "/tmp/components" ]]; then
    COMPONENTS_DIR="/tmp/components"
fi

if [[ ! -d "${COMPONENTS_DIR}" ]]; then
    log_error "Components directory not found. Expected at ${SCRIPT_DIR}/components/"
    exit 1
fi

for component_file in "${COMPONENTS_DIR}"/*.sh; do
    # shellcheck source=/dev/null
    source "${component_file}"
done

# =============================================================================
# Section 7: Dependency Graph and Orchestration
# =============================================================================

# Install order: base tools first, then Node.js ecosystem, then AI CLIs,
# then independent languages, then Java ecosystem last.
INSTALL_ORDER=(
    build_essentials
    git
    nodejs
    pnpm
    bun
    claude_code
    codex
    gemini
    golang
    python
    rust
    php
    openjdk
    maven
    gradle
    code_server
)

# Map: component -> ENABLE variable, check command
declare -A COMPONENT_ENABLE=(
    [build_essentials]="ENABLE_BUILD_ESSENTIALS"
    [git]="ENABLE_GIT"
    [nodejs]="ENABLE_NODEJS"
    [pnpm]="ENABLE_PNPM"
    [bun]="ENABLE_BUN"
    [claude_code]="ENABLE_CLAUDE_CODE"
    [codex]="ENABLE_CODEX"
    [gemini]="ENABLE_GEMINI"
    [golang]="ENABLE_GOLANG"
    [python]="ENABLE_PYTHON"
    [rust]="ENABLE_RUST"
    [php]="ENABLE_PHP"
    [openjdk]="ENABLE_OPENJDK"
    [maven]="ENABLE_MAVEN"
    [gradle]="ENABLE_GRADLE"
    [code_server]="ENABLE_CODE_SERVER"
)

declare -A COMPONENT_CHECK_CMD=(
    [build_essentials]="gcc"
    [git]="git"
    [nodejs]="node"
    [pnpm]="pnpm"
    [bun]="bun"
    [claude_code]="claude"
    [codex]="codex"
    [gemini]="gemini"
    [golang]="go"
    [python]="pyenv"
    [rust]="rustc"
    [php]="php"
    [openjdk]="java"
    [maven]="mvn"
    [gradle]="gradle"
    [code_server]="code-server"
)

declare -A COMPONENT_LABEL=(
    [build_essentials]="Build Essentials"
    [git]="Git"
    [nodejs]="Node.js"
    [pnpm]="pnpm"
    [bun]="Bun"
    [claude_code]="Claude Code"
    [codex]="Codex CLI"
    [gemini]="Gemini CLI"
    [golang]="Go"
    [python]="Python (pyenv)"
    [rust]="Rust"
    [php]="PHP"
    [openjdk]="OpenJDK"
    [maven]="Maven"
    [gradle]="Gradle"
    [code_server]="Code Server"
)

# Components that install under $HOME (pyenv, rustup, bun).
# Skipped when running as root unless --root-install is passed.
# Use user-install.sh to install these as the target user.
declare -A COMPONENT_USER_SCOPED=(
    [python]=true
    [rust]=true
    [bun]=true
)

run_installs() {
    for component in "${INSTALL_ORDER[@]}"; do
        local enable_var="${COMPONENT_ENABLE[${component}]}"
        local check_cmd="${COMPONENT_CHECK_CMD[${component}]}"
        local label="${COMPONENT_LABEL[${component}]}"
        local enable_val="${!enable_var:-false}"

        if [[ "${enable_val}" != "true" ]]; then
            record_result "${label}" "SKIP" "(disabled)"
            continue
        fi

        # Defer user-scoped components when running as root without --root-install
        if [[ "${COMPONENT_USER_SCOPED[${component}]:-false}" == "true" ]] \
           && [[ "${EUID:-$(id -u)}" -eq 0 ]] \
           && [[ "${ROOT_INSTALL}" != "true" ]]; then
            log_skip "${label} deferred to user-install.sh (running as root without --root-install)"
            # Still install system-level build dependencies if a deps function exists
            if type "install_${component}_deps" &>/dev/null; then
                log_info "Pre-installing system dependencies for ${label}..."
                "install_${component}_deps"
            fi
            record_result "${label}" "DEFERRED" "(user-scoped)"
            continue
        fi

        if [[ "${FORCE}" != "true" ]] && is_installed "${check_cmd}"; then
            local ver
            ver="$(get_version "${check_cmd}" --version)"
            log_skip "${label} already installed: ${ver}"
            record_result "${label}" "SKIP" "(installed)"
            continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            log_dry "Would install ${label}"
            record_result "${label}" "DRY-RUN" ""
            continue
        fi

        if ! "install_${component}"; then
            record_result "${label}" "FAIL" ""
        fi
    done
}

# =============================================================================
# Section 8: Summary and Entrypoint
# =============================================================================

print_summary() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  Installation Summary${RESET}"
    echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
    printf "  %-22s %-10s %s\n" "Component" "Status" "Details"
    echo "  ──────────────────────────────────────────────────"

    local has_failure=false
    for i in "${!SUMMARY_COMPONENTS[@]}"; do
        local status="${SUMMARY_STATUSES[$i]}"
        local color="${GREEN}"
        case "${status}" in
            SKIP)    color="${YELLOW}" ;;
            FAIL)    color="${RED}"; has_failure=true ;;
            DRY-RUN) color="${BLUE}" ;;
        esac
        printf "  %-22s ${color}%-10s${RESET} %s\n" \
            "${SUMMARY_COMPONENTS[$i]}" \
            "${status}" \
            "${SUMMARY_VERSIONS[$i]}"
    done

    echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
    echo ""

    if [[ "${has_failure}" == "true" ]]; then
        log_error "Some components failed to install. Check the output above."
        return 1
    fi
}

# --- Main ---

main() {
    echo ""
    echo -e "${BOLD}Agentic AI Development Environment Installer${RESET}"
    echo ""

    # Validate OS
    detect_os
    if [[ "${OS_FAMILY}" == "unknown" ]]; then
        log_error "Unsupported operating system. Supported: macOS, RHEL/Fedora/CentOS, Debian/Ubuntu"
        exit 1
    fi

    # Validate package manager
    if [[ "${PKG_MANAGER}" == "unknown" ]]; then
        if [[ "${OS_FAMILY}" == "macos" ]]; then
            log_error "Homebrew not found. Install from https://brew.sh and re-run."
        else
            log_error "No supported package manager found."
        fi
        exit 1
    fi

    # Refresh package metadata
    pkg_update

    # Run component installs
    run_installs

    # Clean up package caches in container mode
    pkg_clean

    # Print summary
    print_summary
}

main "$@"
