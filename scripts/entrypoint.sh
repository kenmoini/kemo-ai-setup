#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh - Container entrypoint
#
# Sets up PATH for tools installed to non-standard locations,
# optionally prints installed tool versions, and execs into CMD.
# =============================================================================

source ${HOME}/.bashrc.d/dev-paths.sh

# --- Version banner (optional) ---
if [[ "${SHOW_VERSIONS:-false}" == "true" ]]; then
    echo "=== Installed Tools ==="
    for cmd in node npm npx pnpm bun claude ccr codex gemini dev-browser opencode graphify go python3 rustc php java mvn gradle git gcc make; do
        if command -v "${cmd}" &>/dev/null; then
            if [[ "${cmd}" == "go" ]]; then
                ver="$(go version 2>/dev/null)" || ver="(unknown)"
            elif [[ "${cmd}" == "gradle" ]]; then
                ver="$(gradle --version 2>/dev/null | grep -oP 'Gradle \K[0-9.]+' | head -1)" || ver="(unknown)"
            elif [[ "${cmd}" == "graphify" ]]; then
                ver="$(pip show graphifyy | grep ^Version: | awk '{print $2}')" || ver="(unknown)"
            elif [[ "${cmd}" == "dev-browser" ]]; then
                ver="$(npm list -g dev-browser --depth=0 --json 2>/dev/null | jq -r '.dependencies["dev-browser"].version' 2>/dev/null)" || ver="(unknown)"
            elif [[ "${cmd}" == "ccr" ]]; then
                ver="$(ccr -v 2>/dev/null | awk '{print $2}')" || ver="(unknown)"
            else
                ver="$("${cmd}" --version 2>/dev/null | head -1)" || ver="(unknown)"
            fi
            printf "  %-12s %s\n" "${cmd}" "${ver}"
        fi
    done
    echo "======================="
    echo ""
fi

# --- Exec into CMD ---
exec "$@"
