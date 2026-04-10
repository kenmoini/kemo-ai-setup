# kemo-ai-container

A configurable container image and install script for agentic AI development. Based on Red Hat Universal Base Image 9 with support for running directly on macOS, Fedora/RHEL, and Debian/Ubuntu workstations.

## Components

All components are toggled via `ENABLE_*` environment variables. Dependencies are resolved automatically (e.g., enabling Claude Code auto-enables Node.js).

| Component | Variable | Default | Notes |
|---|---|---|---|
| **Git** | `ENABLE_GIT` | `true` | |
| **Build Essentials** | `ENABLE_BUILD_ESSENTIALS` | `true` | gcc, g++, make |
| **Node.js + npm** | `ENABLE_NODEJS` | `true` | Required by AI CLIs |
| **pnpm** | `ENABLE_PNPM` | `false` | Requires Node.js |
| **Bun** | `ENABLE_BUN` | `false` | |
| **Claude Code** | `ENABLE_CLAUDE_CODE` | `true` | `@anthropic-ai/claude-code` |
| **Codex CLI** | `ENABLE_CODEX` | `false` | `@openai/codex` |
| **Gemini CLI** | `ENABLE_GEMINI` | `false` | `@google/gemini-cli` |
| **Python (pyenv)** | `ENABLE_PYTHON` | `true` | Installs via pyenv |
| **Go** | `ENABLE_GOLANG` | `false` | |
| **Rust** | `ENABLE_RUST` | `false` | Via rustup or system package |
| **PHP** | `ENABLE_PHP` | `false` | |
| **OpenJDK** | `ENABLE_OPENJDK` | `false` | |
| **Maven** | `ENABLE_MAVEN` | `false` | Requires OpenJDK |
| **Gradle** | `ENABLE_GRADLE` | `false` | Requires OpenJDK |

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
  --build-arg ENABLE_GEMINI=true \
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

## Install Script Options

```
./install.sh [OPTIONS]

Options:
  --force     Reinstall components even if already present
  --dry-run   Show what would be installed without making changes
  --help      Show usage message
```

The script detects the OS and package manager automatically. It skips components that are already installed unless `--force` is passed. On workstation installs, it configures shell profiles for tools that need PATH additions (pyenv, npm globals, cargo, bun).

## Project Structure

```
.
├── Containerfile              # UBI 9 container definition
├── install.sh                 # Main install script (sources components/)
├── versions.env               # Pinned version numbers
├── .env.example               # Documented component toggle defaults
├── compose.yaml               # Podman/Docker Compose
├── components/                # One file per component installer
│   ├── build_essentials.sh
│   ├── bun.sh
│   ├── claude_code.sh
│   ├── codex.sh
│   ├── gemini.sh
│   ├── git.sh
│   ├── golang.sh
│   ├── gradle.sh
│   ├── maven.sh
│   ├── nodejs.sh
│   ├── openjdk.sh
│   ├── php.sh
│   ├── pnpm.sh
│   ├── python.sh
│   └── rust.sh
├── scripts/
│   └── entrypoint.sh          # Container entrypoint (PATH setup)
└── .github/
    └── workflows/
        └── build.yaml         # CI: container build + Ubuntu/macOS tests
```

## Adding a New Component

1. Create `components/<name>.sh` with an `install_<name>()` function. The function has access to all utilities from `install.sh` (`pkg_install`, `log_info`, `ensure_dependency`, `record_result`, etc.).

2. Add the component to the orchestration maps in `install.sh` (Section 7):
   - `INSTALL_ORDER` array (position matters for dependency ordering)
   - `COMPONENT_ENABLE` map (`[name]="ENABLE_VAR"`)
   - `COMPONENT_CHECK_CMD` map (`[name]="binary_to_check"`)
   - `COMPONENT_LABEL` map (`[name]="Display Name"`)

3. Add the `ENABLE_*` variable to `.env.example`, the `ARG`/`ENV` block in `Containerfile`, and the `args` block in `compose.yaml`.

4. If the component has dependencies, call `ensure_dependency` at the top of the install function:
   ```bash
   ensure_dependency "Node.js" install_nodejs node
   ```

## CI

The GitHub Actions workflow (`.github/workflows/build.yaml`) runs three parallel jobs on push to `main`:

| Job | Runner | Description |
|---|---|---|
| **Container Build** | `ubuntu-latest` | Builds the container image with all components enabled and verifies tools |
| **Install Script (Ubuntu)** | `ubuntu-latest` | Runs `install.sh --force` directly on the runner |
| **Install Script (macOS)** | `macos-latest` | Runs `install.sh --force` directly on the runner |
