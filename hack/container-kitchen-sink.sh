#!/bin/bash

# This script quickly creates a "kitchen sink" container with all components enabled for testing purposes.
# It is not intended for production use and may include components that are not fully configured.

set -e

podman build \
  --build-arg ENABLE_GIT=true \
  --build-arg ENABLE_PYTHON=true \
  --build-arg ENABLE_BUILD_ESSENTIALS=true \
  --build-arg ENABLE_CODE_SERVER=true \
  --build-arg ENABLE_NODEJS=true \
  --build-arg ENABLE_RUST=true \
  --build-arg ENABLE_PNPM=true \
  --build-arg ENABLE_BUN=true \
  -f Containerfile \
  -t kemo-ai-container:test .