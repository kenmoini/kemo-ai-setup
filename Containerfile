# =============================================================================
# Containerfile - Agentic AI Development Container
#
# Based on Red Hat Universal Base Image 9.
# Components are controlled via build args (ENABLE_*).
#
# Build examples:
#   podman build -t kemo-ai-container .
#   podman build --build-arg ENABLE_GOLANG=true -t kemo-ai-container:golang .
#   podman build --build-arg ENABLE_GOLANG=true --build-arg ENABLE_RUST=true \
#     --build-arg ENABLE_OPENJDK=true -t kemo-ai-container:full .
# =============================================================================

# FROM registry.access.redhat.com/ubi9/ubi:latest
FROM registry.fedoraproject.org/fedora:44

LABEL maintainer="kemo"
LABEL description="Agentic AI development container with configurable tooling"

# ---------------------------------------------------------------------------
# Build args for component toggles (defaults match .env.example)
# ---------------------------------------------------------------------------
ARG ENABLE_GIT=true
ARG ENABLE_BUILD_ESSENTIALS=true
ARG ENABLE_NODEJS=true
ARG ENABLE_PNPM=false
ARG ENABLE_BUN=false
ARG ENABLE_CLAUDE_CODE=true
ARG ENABLE_CLAUDE_CODE_ROUTER=false
ARG ENABLE_CODEX=false
ARG ENABLE_GEMINI=false
ARG ENABLE_OPENCODE=false
ARG ENABLE_DEV_BROWSER=false
ARG ENABLE_PYTHON=true
ARG ENABLE_GRAPHIFY=false
ARG ENABLE_GOLANG=false
ARG ENABLE_RUST=false
ARG ENABLE_PHP=false
ARG ENABLE_OPENJDK=false
ARG ENABLE_MAVEN=false
ARG ENABLE_GRADLE=false
ARG ENABLE_CODE_SERVER=false

# ---------------------------------------------------------------------------
# Convert ARGs to ENVs so install.sh can read them
# ---------------------------------------------------------------------------
ENV ENABLE_GIT=${ENABLE_GIT} \
    ENABLE_BUILD_ESSENTIALS=${ENABLE_BUILD_ESSENTIALS} \
    ENABLE_NODEJS=${ENABLE_NODEJS} \
    ENABLE_PNPM=${ENABLE_PNPM} \
    ENABLE_BUN=${ENABLE_BUN} \
    ENABLE_CLAUDE_CODE=${ENABLE_CLAUDE_CODE} \
    ENABLE_CLAUDE_CODE_ROUTER=${ENABLE_CLAUDE_CODE_ROUTER} \
    ENABLE_CODEX=${ENABLE_CODEX} \
    ENABLE_GEMINI=${ENABLE_GEMINI} \
    ENABLE_OPENCODE=${ENABLE_OPENCODE} \
    ENABLE_DEV_BROWSER=${ENABLE_DEV_BROWSER} \
    ENABLE_PYTHON=${ENABLE_PYTHON} \
    ENABLE_GRAPHIFY=${ENABLE_GRAPHIFY} \
    ENABLE_GOLANG=${ENABLE_GOLANG} \
    ENABLE_RUST=${ENABLE_RUST} \
    ENABLE_PHP=${ENABLE_PHP} \
    ENABLE_OPENJDK=${ENABLE_OPENJDK} \
    ENABLE_MAVEN=${ENABLE_MAVEN} \
    ENABLE_GRADLE=${ENABLE_GRADLE} \
    ENABLE_CODE_SERVER=${ENABLE_CODE_SERVER}

# ---------------------------------------------------------------------------
# Create non-root user
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash dev \
    && mkdir -p /workspace \
    && chown dev:dev /workspace

# ---------------------------------------------------------------------------
# Copy build scripts
# ---------------------------------------------------------------------------
COPY --chmod=777 versions.env /tmp/versions.env
COPY --chmod=755 install.sh /tmp/install.sh
COPY components/ /tmp/components/

# ---------------------------------------------------------------------------
# System packages and non-user-scoped components (runs as root).
# User-scoped components (pyenv, rustup, bun) are deferred — install.sh
# detects UID 0 and skips them, but still installs their build dependencies.
# ---------------------------------------------------------------------------
# RUN dnf update -y --disablerepo="*" --enablerepo=ubi-9-appstream-rpms --enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-codeready-builder-rpms \
RUN dnf update -y \
    && dnf install nano wget curl bash-completion openssh-clients jq procps-ng which iputils net-tools -y \
    && /tmp/install.sh --force \
    && rm -rf /tmp/install.sh /tmp/components \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# ---------------------------------------------------------------------------
# User-scoped components (pyenv, rustup, bun) — runs as the dev user so
# everything installs directly into /home/dev.
# ---------------------------------------------------------------------------
USER dev

ENV HOME=/home/dev
ENV SHOW_VERSIONS=true

COPY --chmod=777 user-install.sh /tmp/user-install.sh
RUN /tmp/user-install.sh --force \
    && mkdir -p /home/dev/.bashrc.d
COPY --chmod=644 scripts/dev-paths.sh /home/dev/.bashrc.d/dev-paths.sh

USER root
RUN rm -f /tmp/user-install.sh /tmp/versions.env
USER dev

WORKDIR /workspace

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY --chmod=755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash"]

# ---------------------------------------------------------------------------
# Expose ports
# ---------------------------------------------------------------------------
# Code Server (VS Code in browser)
EXPOSE 8080
# Claude Code Router
EXPOSE 3456
