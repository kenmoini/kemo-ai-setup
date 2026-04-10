# Component: Python (via pyenv)
# Sourced by install.sh — do not execute directly.
#
# Installs pyenv, the required build dependencies for compiling CPython,
# then builds and sets the requested Python version as the global default.
# Reference: https://github.com/pyenv/pyenv#installation

install_python() {
    # pyenv needs git to clone itself on Linux
    ensure_dependency "Git" install_git git

    log_info "Installing Python ${PYTHON_VERSION} via pyenv..."

    # --- Step 1: Install build dependencies for compiling Python ---
    log_info "Installing Python build dependencies..."
    case "${OS_FAMILY}" in
        rhel)
            pkg_install make gcc patch zlib-devel bzip2 bzip2-devel \
                readline-devel sqlite sqlite-devel openssl-devel tk-devel \
                libffi-devel xz-devel libuuid-devel gdbm-libs libnsl2
            ;;
        debian)
            pkg_install make build-essential libssl-dev zlib1g-dev libbz2-dev \
                libreadline-dev libsqlite3-dev curl git libncursesw5-dev \
                xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
            ;;
        macos)
            pkg_install openssl readline sqlite3 xz tcl-tk@8 zlib pkgconfig
            ;;
        *)
            log_error "Unsupported OS for Python build dependencies"
            return 1
            ;;
    esac

    # --- Step 2: Install pyenv ---
    export PYENV_ROOT="${PYENV_ROOT:-${HOME}/.pyenv}"

    if [[ "${OS_FAMILY}" == "macos" ]]; then
        # Use Homebrew on macOS
        pkg_install pyenv
    else
        # Use the automatic installer on Linux
        if ! is_installed curl; then
            pkg_install curl
        fi
        curl -fsSL https://pyenv.run | bash
    fi

    # Make pyenv available in the current session
    export PATH="${PYENV_ROOT}/bin:${PATH}"
    eval "$(pyenv init - bash)" 2>/dev/null || true

    # --- Step 3: Persist pyenv shell setup ---
    if [[ "${IS_CONTAINER}" == "false" ]]; then
        # Workstation mode: add to shell profile
        local shell_profile="${HOME}/.bashrc"
        [[ -f "${HOME}/.zshrc" ]] && shell_profile="${HOME}/.zshrc"
        if ! grep -q 'PYENV_ROOT' "${shell_profile}" 2>/dev/null; then
            {
                echo ''
                echo '# pyenv'
                echo 'export PYENV_ROOT="${HOME}/.pyenv"'
                echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
                echo 'eval "$(pyenv init - $(basename $SHELL))"'
            } >> "${shell_profile}"
        fi
    else
        # Container mode: write to /etc/profile.d so all users pick it up
        cat > /tmp/pyenv.sh <<'PYENV_PROFILE'
export PYENV_ROOT="${HOME}/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - $(basename $SHELL))" 2>/dev/null || true
PYENV_PROFILE
        _sudo mv /tmp/pyenv.sh /etc/profile.d/pyenv.sh
        _sudo chmod 644 /etc/profile.d/pyenv.sh
    fi

    # --- Step 4: Install the requested Python version ---
    log_info "Building Python ${PYTHON_VERSION} (this may take a few minutes)..."
    pyenv install -s "${PYTHON_VERSION}"

    # --- Step 5: Set as global default ---
    pyenv global "${PYTHON_VERSION}"

    local ver
    ver="$(pyenv exec python --version 2>&1)"
    log_success "Python installed via pyenv: ${ver}"
    record_result "Python (pyenv)" "OK" "${ver}"

    mv /root/.pyenv /home/dev/.pyenv 2>/dev/null || true
    chown -R dev:dev /home/dev/.pyenv 2>/dev/null || true
}
