#!/usr/bin/env bash

# Production deployment script for the Dostra CRM stack.
#
# What it does:
# - validates that .env.prod exists and has no unfilled placeholder values
# - pulls the latest submodule commits
# - builds production images (Dockerfile.prod) with no cache
# - starts all services in detached mode
# - waits for the stack to become healthy
#
# Usage (on the production server):
#   ./scripts/docker-deploy-prod.sh
#
# The script expects .env.prod to exist at the repo root.
# Copy .env.prod.example and fill in real values before running.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE=".env.prod"
COMPOSE_FILE="docker-compose.prod.yml"

# ── Preflight checks ───────────────────────────────────────────────────────────

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found."
  echo "       Copy .env.prod.example, fill in real values, then re-run."
  exit 1
fi

# Fail fast if any placeholder values were left unfilled.
if grep -qE "change_me|replace_with|yourdomain\.com" "$ENV_FILE"; then
  echo "ERROR: $ENV_FILE contains unfilled placeholder values."
  echo "       Search for 'change_me', 'replace_with', or 'yourdomain.com' and replace them."
  exit 1
fi

echo "── Dostra production deploy ──────────────────────────────────────────────"

# ── Submodules ─────────────────────────────────────────────────────────────────

echo "[1/3] Updating submodules..."
git submodule update --init --recursive

# ── Build and start ────────────────────────────────────────────────────────────

echo "[2/3] Building production images and starting services..."

# --no-cache ensures the build always uses the latest source and dependencies.
# Remove --no-cache if build speed matters more than freshness on re-deploys.
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" \
  up --build --no-cache -d

# ── Health check ───────────────────────────────────────────────────────────────

echo "[3/3] Waiting for stack to become healthy..."

# Give services up to 60 seconds to pass their healthchecks.
TIMEOUT=60
ELAPSED=0
until docker compose -f "$COMPOSE_FILE" ps | grep -q "healthy" || [ "$ELAPSED" -ge "$TIMEOUT" ]; do
  sleep 3
  ELAPSED=$((ELAPSED + 3))
done

if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
  echo "WARNING: Timed out waiting for healthy status. Check logs:"
  echo "         docker compose -f $COMPOSE_FILE logs"
else
  echo
  echo "Dostra production stack is running."
  echo "Access the app at the APP_URL defined in $ENV_FILE."
fi
