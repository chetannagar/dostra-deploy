#!/usr/bin/env bash

# Production deployment script for the Dostra CRM stack.
#
# What it does:
# - validates that .env.prod exists and has no unfilled placeholder values
# - pulls the latest submodule commits
# - builds production images (Dockerfile.prod) with no cache, pulling fresh base images
# - starts all services in detached mode
# - waits until every service reports healthy (fails on unhealthy or timeout)
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

# Fail fast if any required variable is missing or empty. (Compose would
# otherwise substitute an empty string, e.g. baking a blank API URL into the
# frontend bundle.)
for VAR in POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD APP_KEY APP_URL VITE_API_BASE_URL; do
  if ! grep -qE "^${VAR}=.+" "$ENV_FILE"; then
    echo "ERROR: $VAR is missing or empty in $ENV_FILE."
    exit 1
  fi
done

echo "── Dostra production deploy ──────────────────────────────────────────────"

# ── Submodules ─────────────────────────────────────────────────────────────────

echo "[1/3] Updating submodules..."
git submodule update --init --recursive

# ── Build and start ────────────────────────────────────────────────────────────

echo "[2/3] Building production images and starting services..."

# --no-cache and --pull ensure the build uses the latest source, dependencies
# and base images (including the pinned patched PHP image).
# "up" has no --no-cache flag, so build first, then start without rebuilding.
# Remove --no-cache if build speed matters more than freshness on re-deploys.
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" \
  build --pull --no-cache

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" \
  up -d

# ── Health check ───────────────────────────────────────────────────────────────

echo "[3/3] Waiting for stack to become healthy..."

# Every service defines a healthcheck. Wait until all containers report
# "healthy"; fail immediately if any reports "unhealthy".
# The api container runs migrations before it becomes healthy, so allow time.
TIMEOUT=180
ELAPSED=0
COMPOSE=(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE")

while true; do
  PENDING=()
  for SERVICE in $("${COMPOSE[@]}" config --services); do
    CID="$("${COMPOSE[@]}" ps -q "$SERVICE")"
    STATUS="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CID" 2>/dev/null || echo missing)"
    case "$STATUS" in
      healthy) ;;
      unhealthy|exited|dead|missing)
        echo "ERROR: service '$SERVICE' is $STATUS. Check logs:"
        echo "       docker compose -f $COMPOSE_FILE --env-file $ENV_FILE logs $SERVICE"
        exit 1
        ;;
      *) PENDING+=("$SERVICE") ;;
    esac
  done

  if [ "${#PENDING[@]}" -eq 0 ]; then
    break
  fi

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "ERROR: timed out after ${TIMEOUT}s waiting for: ${PENDING[*]}"
    echo "       docker compose -f $COMPOSE_FILE --env-file $ENV_FILE logs"
    exit 1
  fi

  sleep 3
  ELAPSED=$((ELAPSED + 3))
done

echo
echo "Dostra production stack is running."
echo "Access the app at the APP_URL defined in $ENV_FILE."
