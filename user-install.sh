#!/usr/bin/env bash
# =============================================================================
# user-install.sh - User-scoped Component Installer
#
# Installs components that live under $HOME:
#   - Python via pyenv (~/.pyenv)
#   - Rust via rustup (~/.cargo, ~/.rustup)
#   - Bun (~/.bun)
#
# Must NOT be run as root (UID 0). System-level dependencies (compilers,
# headers, curl, etc.) should already be installed via install.sh before
# running this script.
#
# Usage:
#   ./user-install.sh [--force] [--dry-run] [--help]
#
# Components are controlled via ENABLE_* environment variables.
# =============================================================================
set -euo pipefail

# Associative arrays require Bash 4+.
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
# Section 1: Root Guard
# =============================================================================

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo "ERROR: user-install.sh must not be run as root (UID 0)." >&2
    echo "Run as the target user instead. System dependencies should" >&2
    echo "already be installed via install.sh." >&2
    exit 1
fi

# =============================================================================
# Section 2: Constants and Defaults
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
PYTHON_VERSION="${PYTHON_VERSION:-3.14}"
BUN_VERSION="${BUN_VERSION:-latest}"
RUST_INSTALL_METHOD="${RUST_INSTALL_METHOD:-rustup}"

# Component toggle defaults
ENABLE_CLAUDE_CODE="${ENABLE_CLAUDE_CODE:-true}"
ENABLE_PYTHON="${ENABLE_PYTHON:-true}"
ENABLE_OPENCODE="${ENABLE_OPENCODE:-false}"
ENABLE_GRAPHIFY="${ENABLE_GRAPHIFY:-false}"
ENABLE_RUST="${ENABLE_RUST:-false}"
ENABLE_BUN="${ENABLE_BUN:-false}"

# Flags
FORCE=false
DRY_RUN=false

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
# Section 3: Argument Parsing
# =============================================================================

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Installs user-scoped development tools (pyenv, rustup, bun) into \$HOME.
Must not be run as root. System dependencies should already be installed
via install.sh.

Options:
  --force     Reinstall components even if already present
  --dry-run   Show what would be installed without making changes
  --help      Show this help message

Examples:
  # Install with defaults
  ./user-install.sh

  # Enable Rust and Bun
  ENABLE_RUST=true ENABLE_BUN=true ./user-install.sh

  # Force reinstall
  ./user-install.sh --force
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help)    usage ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage
            ;;
    esac
done

# =============================================================================
# Section 4: OS Detection and Utilities
# =============================================================================

log_info()    { echo -e "${BLUE}===== [INFO] ========================${RESET}    $*"; }
log_success() { echo -e "${GREEN}===== [OK] ========================${RESET}      $*"; }
log_warn()    { echo -e "${YELLOW}===== [WARN] ========================${RESET}    $*"; }
log_error()   { echo -e "${RED}===== [ERROR] ========================${RESET}   $*"; }
log_skip()    { echo -e "${YELLOW}===== [SKIP] ========================${RESET}    $*"; }
log_dry()     { echo -e "${BOLD}===== [DRY-RUN] ========================${RESET} $*"; }

is_installed() { command -v "$1" &>/dev/null; }

detect_os() {
    OS_FAMILY="unknown"
    ARCH="$(uname -m)"

    case "$(uname -s)" in
        Darwin) OS_FAMILY="macos" ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                # shellcheck source=/dev/null
                source /etc/os-release
                case "${ID:-}" in
                    rhel|centos|rocky|alma|fedora)       OS_FAMILY="rhel" ;;
                    debian|ubuntu|pop|mint|linuxmint)    OS_FAMILY="debian" ;;
                    *)
                        case "${ID_LIKE:-}" in
                            *rhel*|*fedora*|*centos*) OS_FAMILY="rhel" ;;
                            *debian*|*ubuntu*)        OS_FAMILY="debian" ;;
                        esac
                        ;;
                esac
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

    log_info "Detected: OS=${OS_FAMILY} ARCH=${ARCH} CONTAINER=${IS_CONTAINER} USER=$(whoami) HOME=${HOME}"
}

record_result() {
    local component="$1"
    local status="$2"
    local version="${3:-}"
    SUMMARY_COMPONENTS+=("${component}")
    SUMMARY_STATUSES+=("${status}")
    SUMMARY_VERSIONS+=("${version}")
}

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
# Section 5: Claude Code
# =============================================================================

install_claude_code_user() {
    if [[ "${ENABLE_CLAUDE_CODE}" != "true" ]]; then
        record_result "Claude Code" "SKIP" "(disabled)"
        return 0
    fi

    if [[ "${FORCE}" != "true" ]] && is_installed claude; then
        local ver
        ver="$(get_version claude --version)"
        log_skip "Claude Code already installed: ${ver}"
        record_result "Claude Code" "SKIP" "(installed)"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install Claude Code"
        record_result "Claude Code" "DRY-RUN" ""
        return 0
    fi

    log_info "Installing Claude Code..."

    curl -fsSL https://claude.ai/install.sh | bash

    # Add to PATH for current session
    [[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

    local ver
    ver="$(get_version claude --version)"
    log_success "Claude Code installed: ${ver}"
    record_result "Claude Code" "OK" "${ver}"
}

# =============================================================================
# Section 6: Python (pyenv)
# =============================================================================

install_python_user() {
    if [[ "${ENABLE_PYTHON}" != "true" ]]; then
        record_result "Python (pyenv)" "SKIP" "(disabled)"
        return 0
    fi

    if [[ "${FORCE}" != "true" ]] && is_installed pyenv; then
        local ver
        ver="$(get_version pyenv --version)"
        log_skip "pyenv already installed: ${ver}"
        record_result "Python (pyenv)" "SKIP" "(installed)"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install pyenv + Python ${PYTHON_VERSION}"
        record_result "Python (pyenv)" "DRY-RUN" ""
        return 0
    fi

    log_info "Installing Python ${PYTHON_VERSION} via pyenv..."

    # --- Install pyenv ---
    export PYENV_ROOT="${PYENV_ROOT:-${HOME}/.pyenv}"

    if [[ "${OS_FAMILY}" == "macos" ]]; then
        brew install pyenv 2>/dev/null || brew upgrade pyenv 2>/dev/null || true
    else
        curl -fsSL https://pyenv.run | bash
    fi

    # Make pyenv available in the current session
    export PATH="${PYENV_ROOT}/bin:${PATH}"
    eval "$(pyenv init - bash)" 2>/dev/null || true

    # --- Persist pyenv shell setup ---
    local shell_profile="${HOME}/.bashrc"
    [[ -f "${HOME}/.zshrc" ]] && shell_profile="${HOME}/.zshrc"
    if ! grep -q 'PYENV_ROOT' "${shell_profile}" 2>/dev/null; then
        {
            echo ''
            echo '# pyenv'
            echo 'export PYENV_ROOT="${HOME}/.pyenv"'
            echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
            echo 'eval "$(pyenv init - $(basename $SHELL))" 2>/dev/null || true'
        } >> "${shell_profile}"
    fi

    # --- Build and set Python version ---
    log_info "Building Python ${PYTHON_VERSION} (this may take a few minutes)..."
    pyenv install -s "${PYTHON_VERSION}"
    pyenv global "${PYTHON_VERSION}"

    local ver
    ver="$(pyenv exec python --version 2>&1)"
    log_success "Python installed via pyenv: ${ver}"
    record_result "Python (pyenv)" "OK" "${ver}"
}

# =============================================================================
# Section 6: OpenCode
# =============================================================================

install_opencode_user() {
    if [[ "${ENABLE_OPENCODE}" != "true" ]]; then
        record_result "OpenCode" "SKIP" "(disabled)"
        return 0
    fi

    if [[ "${FORCE}" != "true" ]] && is_installed opencode; then
        local ver
        ver="$(get_version opencode --version)"
        log_skip "OpenCode already installed: ${ver}"
        record_result "OpenCode" "SKIP" "(installed)"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install OpenCode"
        record_result "OpenCode" "DRY-RUN" ""
        return 0
    fi

    log_info "Installing OpenCode..."

    curl -fsSL https://opencode.ai/install | bash

    # Add to PATH for current session
    [[ -d "${HOME}/.opencode/bin" ]] && export PATH="${HOME}/.opencode/bin:${PATH}"

    local ver
    ver="$(get_version opencode --version)"
    log_success "OpenCode installed: ${ver}"
    record_result "OpenCode" "OK" "${ver}"
}

# =============================================================================
# Section 7: graphify (knowledge graph skill)
# =============================================================================

install_graphify_user() {
    if [[ "${ENABLE_GRAPHIFY}" != "true" ]]; then
        record_result "graphify" "SKIP" "(disabled)"
        return 0
    fi

    if [[ "${FORCE}" != "true" ]] && is_installed graphify; then
        local ver
        ver="$(get_version graphify --version)"
        log_skip "graphify already installed: ${ver}"
        record_result "graphify" "SKIP" "(installed)"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install graphify"
        record_result "graphify" "DRY-RUN" ""
        return 0
    fi

    # graphify requires Python via pyenv
    if ! is_installed pyenv; then
        log_error "graphify requires pyenv/Python — enable ENABLE_PYTHON=true"
        record_result "graphify" "FAIL" "(missing pyenv)"
        return 1
    fi

    log_info "Installing graphify..."

    # Ensure pyenv Python is on PATH
    export PYENV_ROOT="${PYENV_ROOT:-${HOME}/.pyenv}"
    export PATH="${PYENV_ROOT}/bin:${PATH}"
    eval "$(pyenv init - bash)" 2>/dev/null || true

    pip install graphifyy
    pip cache purge

    # Install the skill into the AI coding assistant config
    # graphify install || log_warn "graphify install returned non-zero; skill config may need manual setup"
    graphify install 2>/dev/null || true

    local ver
    ver="$(pip show graphifyy | grep ^Version: | awk '{print $2}')"
    log_success "graphify installed: ${ver}"
    record_result "graphify" "OK" "${ver}"
}

# =============================================================================
# Section 8: Rust (rustup)
# =============================================================================

install_rust_user() {
    if [[ "${ENABLE_RUST}" != "true" ]]; then
        record_result "Rust" "SKIP" "(disabled)"
        return 0
    fi

    if [[ "${FORCE}" != "true" ]] && is_installed rustc; then
        local ver
        ver="$(get_version rustc --version)"
        log_skip "Rust already installed: ${ver}"
        record_result "Rust" "SKIP" "(installed)"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install Rust via rustup"
        record_result "Rust" "DRY-RUN" ""
        return 0
    fi

    # System package method requires root; can only use rustup here
    if [[ "${RUST_INSTALL_METHOD}" != "rustup" ]] && [[ "${OS_FAMILY}" != "macos" ]]; then
        log_warn "Rust system package install requires root; skipping in user-install"
        record_result "Rust" "SKIP" "(needs root for repo method)"
        return 0
    fi

    log_info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

    export PATH="${HOME}/.cargo/bin:${PATH}"

    # Persist cargo env
    local shell_profile="${HOME}/.bashrc"
    [[ -f "${HOME}/.zshrc" ]] && shell_profile="${HOME}/.zshrc"
    if ! grep -q '.cargo/bin' "${shell_profile}" 2>/dev/null; then
        echo 'source "${HOME}/.cargo/env" 2>/dev/null || true' >> "${shell_profile}"
    fi

    local ver
    ver="$(get_version rustc --version)"
    log_success "Rust installed: ${ver}"
    record_result "Rust" "OK" "${ver}"
}

# =============================================================================
# Section 9: Bun
# =============================================================================

install_bun_user() {
    if [[ "${ENABLE_BUN}" != "true" ]]; then
        record_result "Bun" "SKIP" "(disabled)"
        return 0
    fi

    if [[ "${FORCE}" != "true" ]] && is_installed bun; then
        local ver
        ver="$(get_version bun --version)"
        log_skip "Bun already installed: ${ver}"
        record_result "Bun" "SKIP" "(installed)"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would install Bun"
        record_result "Bun" "DRY-RUN" ""
        return 0
    fi

    log_info "Installing Bun..."

    if [[ "${OS_FAMILY}" == "macos" ]]; then
        brew install oven-sh/bun/bun 2>/dev/null || brew upgrade oven-sh/bun/bun 2>/dev/null || true
    else
        if [[ "${BUN_VERSION}" == "latest" ]]; then
            curl -fsSL https://bun.sh/install | bash
        else
            curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}"
        fi
        export BUN_INSTALL="${HOME}/.bun"
        export PATH="${BUN_INSTALL}/bin:${PATH}"
    fi

    local ver
    ver="$(get_version bun --version)"
    log_success "Bun installed: ${ver}"
    record_result "Bun" "OK" "${ver}"
}

# =============================================================================
# Section 10: Summary and Entrypoint
# =============================================================================

print_summary() {
    echo ""
    echo -e "${BOLD}==================================================================${RESET}"
    echo -e "${BOLD}  User Install Summary${RESET}"
    echo -e "${BOLD}==================================================================${RESET}"
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

    echo -e "${BOLD}==================================================================${RESET}"
    echo ""

    if [[ "${has_failure}" == "true" ]]; then
        log_error "Some components failed to install. Check the output above."
        return 1
    fi
}

main() {
    echo ""
    echo -e "${BOLD}User-scoped Component Installer${RESET}"
    echo ""

    detect_os
    if [[ "${OS_FAMILY}" == "unknown" ]]; then
        log_error "Unsupported operating system. Supported: macOS, RHEL/Fedora/CentOS, Debian/Ubuntu"
        exit 1
    fi

    install_claude_code_user
    install_python_user
    install_opencode_user
    install_graphify_user
    install_rust_user
    install_bun_user

    print_summary
}

main "$@"
