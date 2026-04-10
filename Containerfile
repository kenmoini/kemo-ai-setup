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

FROM registry.access.redhat.com/ubi9/ubi:latest

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
ARG ENABLE_CODEX=false
ARG ENABLE_GEMINI=false
ARG ENABLE_PYTHON=true
ARG ENABLE_GOLANG=false
ARG ENABLE_RUST=false
ARG ENABLE_PHP=false
ARG ENABLE_OPENJDK=false
ARG ENABLE_MAVEN=false
ARG ENABLE_GRADLE=false

# ---------------------------------------------------------------------------
# Convert ARGs to ENVs so install.sh can read them
# ---------------------------------------------------------------------------
ENV ENABLE_GIT=${ENABLE_GIT} \
    ENABLE_BUILD_ESSENTIALS=${ENABLE_BUILD_ESSENTIALS} \
    ENABLE_NODEJS=${ENABLE_NODEJS} \
    ENABLE_PNPM=${ENABLE_PNPM} \
    ENABLE_BUN=${ENABLE_BUN} \
    ENABLE_CLAUDE_CODE=${ENABLE_CLAUDE_CODE} \
    ENABLE_CODEX=${ENABLE_CODEX} \
    ENABLE_GEMINI=${ENABLE_GEMINI} \
    ENABLE_PYTHON=${ENABLE_PYTHON} \
    ENABLE_GOLANG=${ENABLE_GOLANG} \
    ENABLE_RUST=${ENABLE_RUST} \
    ENABLE_PHP=${ENABLE_PHP} \
    ENABLE_OPENJDK=${ENABLE_OPENJDK} \
    ENABLE_MAVEN=${ENABLE_MAVEN} \
    ENABLE_GRADLE=${ENABLE_GRADLE}

# ---------------------------------------------------------------------------
# Install all components via install.sh (single layer)
# ---------------------------------------------------------------------------
COPY versions.env /tmp/versions.env
COPY install.sh /tmp/install.sh
COPY components/ /tmp/components/
RUN dnf update -y --disablerepo="*" --enablerepo=ubi-9-appstream-rpms --enablerepo=ubi-9-baseos-rpms --enablerepo=ubi-9-codeready-builder-rpms \
    && chmod +x /tmp/install.sh \
    && /tmp/install.sh --force \
    && rm -rf /tmp/install.sh /tmp/versions.env /tmp/components \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# ---------------------------------------------------------------------------
# Create non-root user
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash dev \
    && mkdir -p /workspace \
    && chown dev:dev /workspace

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY --chmod=755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

ENV HOME=/home/dev
USER dev
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
