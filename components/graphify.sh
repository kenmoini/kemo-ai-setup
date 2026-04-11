# Component: graphify (knowledge graph skill for AI coding assistants)
# Sourced by install.sh — do not execute directly.
#
# Installs graphify via pip (PyPI package: graphifyy), then runs
# `graphify install` to configure the skill for the AI coding assistant.
# Requires Python (pyenv). Reference: https://graphify.net

# Python build dependencies are handled by install_python_deps;
# graphify has no additional system-level dependencies.
install_graphify_deps() {
    :
}

install_graphify() {
    ensure_dependency "Python (pyenv)" install_python pyenv

    log_info "Installing graphify..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Would run: pip install graphifyy && graphify install"
        record_result "graphify" "DRY-RUN" ""
        return 0
    fi

    # Ensure pyenv Python is on PATH
    export PYENV_ROOT="${PYENV_ROOT:-${HOME}/.pyenv}"
    export PATH="${PYENV_ROOT}/bin:${PATH}"
    eval "$(pyenv init - bash)" 2>/dev/null || true

    pip install graphifyy
    pip cache purge

    # Install the skill into the AI coding assistant config
    graphify install || log_warn "graphify install returned non-zero; skill config may need manual setup"

    if [[ "${OS_FAMILY}" != "macos" ]]; then
        if [[ "$UID" -eq 0 ]]; then
            # graphify lives inside the pyenv tree; the pyenv copy in
            # install_python already handles that. Just copy any skill config.
            cp -R /root/.claude/skills/graphify /home/dev/.claude/skills/graphify 2>/dev/null || true
            chown -R dev:dev /home/dev/.claude/skills 2>/dev/null || true
        fi
    fi

    local ver
    ver="$(pip show graphifyy | grep ^Version: | awk '{print $2}')"
    log_success "graphify installed: ${ver}"
    record_result "graphify" "OK" "${ver}"
}
