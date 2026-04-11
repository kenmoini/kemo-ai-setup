# kemo-ai-container

A configurable container image and install script for agentic AI development. Based on Fedora 44 with support for running directly on macOS, Fedora/RHEL, and Debian/Ubuntu workstations.

## Components

All components are toggled via `ENABLE_*` environment variables. Dependencies are resolved automatically (e.g., enabling Claude Code auto-enables Node.js).

Components marked **user-scoped** install into `$HOME` (pyenv, rustup, bun, opencode, graphify). During container builds these are installed as the unprivileged `dev` user via `user-install.sh`, not as root.

| Component | Variable | Default | Notes |
|---|---|---|---|
| **Git** | `ENABLE_GIT` | `true` | |
| **Build Essentials** | `ENABLE_BUILD_ESSENTIALS` | `true` | gcc, g++, make |
| **Node.js + npm** | `ENABLE_NODEJS` | `true` | Required by AI CLIs |
| **pnpm** | `ENABLE_PNPM` | `false` | Requires Node.js |
| **Bun** | `ENABLE_BUN` | `false` | User-scoped (`~/.bun`) |
| **Claude Code** | `ENABLE_CLAUDE_CODE` | `true` | `@anthropic-ai/claude-code` |
| **Codex CLI** | `ENABLE_CODEX` | `false` | `@openai/codex` |
| **Gemini CLI** | `ENABLE_GEMINI` | `false` | `@google/gemini-cli` |
| **dev-browser** | `ENABLE_DEV_BROWSER` | `false` | Browser automation for AI agents |
| **OpenCode** | `ENABLE_OPENCODE` | `false` | User-scoped (`~/.opencode`) |
| **Python (pyenv)** | `ENABLE_PYTHON` | `true` | User-scoped (`~/.pyenv`) |
| **graphify** | `ENABLE_GRAPHIFY` | `false` | Knowledge graph skill; requires Python |
| **Go** | `ENABLE_GOLANG` | `false` | |
| **Rust** | `ENABLE_RUST` | `false` | User-scoped via rustup (`~/.cargo`) |
| **PHP** | `ENABLE_PHP` | `false` | |
| **OpenJDK** | `ENABLE_OPENJDK` | `false` | |
| **Maven** | `ENABLE_MAVEN` | `false` | Requires OpenJDK |
| **Gradle** | `ENABLE_GRADLE` | `false` | Requires OpenJDK |
| **Code Server** | `ENABLE_CODE_SERVER` | `false` | VS Code in the browser |

Version pins are centralized in [`versions.env`](versions.env).

## Quick Start

### Container (Podman/Docker)

Build with defaults (Git, build essentials, Node.js, Claude Code, Python):

```bash
podman build -t kemo-ai-container -f Containerfile .
```

Build with additional components:

```bash
podman build \
  --build-arg ENABLE_GOLANG=true \
  --build-arg ENABLE_RUST=true \
  --build-arg ENABLE_CODEX=true \
  --build-arg ENABLE_OPENCODE=true \
  --build-arg ENABLE_DEV_BROWSER=true \
  --build-arg ENABLE_GRAPHIFY=true \
  -t kemo-ai-container -f Containerfile .
```

Run:

```bash
podman run -it \
  -e ANTHROPIC_API_KEY \
  -v "$(pwd)":/workspace \
  kemo-ai-container
```

### Compose

```bash
cp .env.example .env
# Edit .env to enable desired components
podman compose up -d
podman compose exec dev bash
```

The compose configuration mounts `./workspace` into the container and maps `~/.claude` for persistent Claude Code configuration. API keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`) are passed through from the host environment.

### Workstation Bootstrap

The same install script can run directly on a workstation. Supported platforms: **macOS** (Homebrew), **Fedora/RHEL/CentOS** (dnf), **Debian/Ubuntu** (apt).

```bash
git clone <repo-url> && cd kemo-ai-container
cp .env.example .env
# Edit .env to enable desired components
source .env && ./install.sh
```

Or inline:

```bash
ENABLE_CLAUDE_CODE=true ENABLE_GOLANG=true ./install.sh
```

On a workstation (non-root), `install.sh` installs everything including user-scoped components. There is no need to run `user-install.sh` separately.

## Install Scripts

### install.sh

```
./install.sh [OPTIONS]

Options:
  --force         Reinstall components even if already present
  --dry-run       Show what would be installed without making changes
  --root-install  Install user-scoped components even when running as root
  --help          Show usage message
```

The script detects the OS and package manager automatically. It skips components that are already installed unless `--force` is passed. On workstation installs, it configures shell profiles for tools that need PATH additions (pyenv, npm globals, cargo, bun, opencode).

When running as root (UID 0), user-scoped components (pyenv, rustup, bun, opencode, graphify) are **deferred** unless `--root-install` is passed. Their system-level build dependencies are still installed so that `user-install.sh` can run without root later.

### user-install.sh

```
./user-install.sh [OPTIONS]

Options:
  --force     Reinstall components even if already present
  --dry-run   Show what would be installed without making changes
  --help      Show usage message
```

Installs user-scoped components directly into `$HOME`. Refuses to run as root. In the container build, this runs as the `dev` user after `install.sh` has laid down all system packages.

## Container Build Flow

The Containerfile uses a two-stage install strategy:

1. **Root stage** -- `install.sh --force` installs system packages and non-user-scoped components (Node.js, npm globals, Go, etc.). User-scoped components are deferred, but their build dependencies (e.g., Python compilation headers) are pre-installed.
2. **User stage** -- `USER dev` switches to the unprivileged user, then `user-install.sh --force` installs pyenv/Python, rustup/Rust, Bun, OpenCode, and graphify directly into `/home/dev`.

This avoids the old pattern of installing into `/root` and copying to `/home/dev`.

## Project Structure

```
.
├── Containerfile              # Fedora 44 container definition
├── install.sh                 # Main install script (sources components/)
├── user-install.sh            # User-scoped component installer
├── versions.env               # Pinned version numbers
├── compose.yaml               # Podman/Docker Compose
├── components/                # One file per component installer
│   ├── build_essentials.sh
│   ├── bun.sh
│   ├── claude_code.sh
│   ├── code_server.sh
│   ├── codex.sh
│   ├── dev_browser.sh
│   ├── gemini.sh
│   ├── git.sh
│   ├── golang.sh
│   ├── gradle.sh
│   ├── graphify.sh
│   ├── maven.sh
│   ├── nodejs.sh
│   ├── opencode.sh
│   ├── openjdk.sh
│   ├── php.sh
│   ├── pnpm.sh
│   ├── python.sh
│   └── rust.sh
├── scripts/
│   └── entrypoint.sh          # Container entrypoint (PATH setup + version banner)
├── hack/
│   └── container-kitchen-sink.sh  # Build with all components enabled
└── .github/
    ├── dependabot.yml
    └── workflows/
        └── build.yaml         # CI: container build + Ubuntu/macOS tests
```

## Adding a New Component

1. Create `components/<name>.sh` with an `install_<name>()` function. The function has access to all utilities from `install.sh` (`pkg_install`, `log_info`, `ensure_dependency`, `record_result`, etc.).

2. If the component installs into `$HOME` (user-scoped), also define:
   - An `install_<name>_deps()` function for system-level build dependencies (called even when the main install is deferred).
   - An `install_<name>_user()` function in `user-install.sh`.
   - Add the component to `COMPONENT_USER_SCOPED` in `install.sh`.

3. Add the component to the orchestration maps in `install.sh` (Section 7):
   - `INSTALL_ORDER` array (position matters for dependency ordering)
   - `COMPONENT_ENABLE` map (`[name]="ENABLE_VAR"`)
   - `COMPONENT_CHECK_CMD` map (`[name]="binary_to_check"`)
   - `COMPONENT_LABEL` map (`[name]="Display Name"`)

4. Add the `ENABLE_*` variable default in `install.sh` (Section 1) and, if user-scoped, in `user-install.sh`.

5. Add the `ENABLE_*` variable to the `ARG`/`ENV` blocks in `Containerfile` and the `args` block in `compose.yaml`.

6. If the component has dependencies, call `ensure_dependency` at the top of the install function:
   ```bash
   ensure_dependency "Node.js" install_nodejs node
   ```

7. Update `scripts/entrypoint.sh` if the component needs a custom PATH entry or version display logic.

## CI

The GitHub Actions workflow (`.github/workflows/build.yaml`) runs three test jobs on push to `main`, then builds and pushes multi-arch images:

| Job | Runner | Description |
|---|---|---|
| **Container Build** | `ubuntu-latest` | Builds the container image with all components enabled and verifies tools |
| **Install Script (Ubuntu)** | `ubuntu-latest` | Runs `install.sh --force` directly on the runner |
| **Install Script (macOS)** | `macos-latest` | Runs `install.sh --force` directly on the runner |
| **Build + Push** | `ubuntu-latest` | Multi-arch (amd64, arm64) build pushed to `ghcr.io` |
