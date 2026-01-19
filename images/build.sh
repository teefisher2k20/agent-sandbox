#!/bin/bash
set -euo pipefail

# Build agent-sandbox images locally
# Usage: ./build.sh [base|claude|all]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build_base() {
  echo "Building agent-sandbox-base..."
  docker build -t agent-sandbox-base:local "$SCRIPT_DIR/base"
}

build_claude() {
  echo "Building agent-sandbox-claude..."
  docker build \
    --build-arg BASE_IMAGE=agent-sandbox-base:local \
    -t agent-sandbox-claude:local \
    "$SCRIPT_DIR/agents/claude"
}

case "${1:-all}" in
  base)
    build_base
    ;;
  claude)
    build_claude
    ;;
  all)
    build_base
    build_claude
    ;;
  *)
    echo "Usage: $0 [base|claude|all]"
    exit 1
    ;;
esac

echo "Done."
