#!/usr/bin/env bash

# Development deployment helper for the Dostra Docker stack.
#
# This script is intentionally optimized for local development:
# - always runs from the repository root
# - builds the current Docker images before starting containers
# - starts the stack in detached mode so the terminal is not occupied
# - prints the main local URLs after startup
#
# For production, use a separate deployment script or pipeline with production images.

set -euo pipefail

# Resolve the repository root from the script location so the command works from any directory.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "Building and starting the Dostra Docker stack..."

# Build fresh images and start the services in the background.
docker compose up --build -d

echo
echo "Dostra stack is running."
echo "Frontend: http://127.0.0.1:5173"
echo "API:      http://127.0.0.1:8000"
