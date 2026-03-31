#!/usr/bin/env bash

# Development rollback helper for the Dostra Docker stack.
#
# This script is intentionally optimized for local development:
# - always runs from the repository root
# - stops and removes the running Compose services
# - preserves named volumes by default so dependencies and local state remain cached
#
# If you need a full reset, run `docker compose down -v` manually from the repository root.

set -euo pipefail

# Resolve the repository root from the script location so the command works from any directory.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "Stopping the Dostra Docker stack..."

# Stop and remove the containers, but keep named volumes for faster future startups.
docker compose down

echo
echo "Dostra stack has been stopped."
