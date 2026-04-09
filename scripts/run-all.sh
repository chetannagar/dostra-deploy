#!/usr/bin/env bash

# Development helper for running the Dostra app locally (without Docker).
#
# This script is optimized for local development:
# - always runs from the repository root
# - starts both backend (Laravel) and frontend (Vite) concurrently
# - keeps logs visible in the terminal for easier debugging
# - prints the main local URLs after startup
#
# Requirements:
# - PHP installed (with Composer)
# - Node.js + npm installed
# - Project dependencies already installed (composer install / npm install)
#
# Notes:
# - Backend runs via "composer run dev" (Laravel)
# - Frontend runs via "npm run dev" (Vite)
# - Uses background processes and cleans them up on exit (Ctrl+C)

set -euo pipefail

# Resolve the repository root from the script location so the command works from any directory.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "Starting Dostra app locally (Laravel + Vite)..."

# Ensure cleanup on exit (Ctrl+C)
cleanup() {
  echo
  echo "Stopping local development servers..."
  kill "$API_PID" "$WEB_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

# 🔥 Start Laravel API
echo "Starting Laravel API..."
(
  cd "$ROOT_DIR/dostra-api"
  composer run dev
) &
API_PID=$!

# 🔥 Start Vite Web
echo "Starting Vite Web..."
(
  cd "$ROOT_DIR/dostra-web"
  npm run dev
) &
WEB_PID=$!

echo
echo "Dostra app is running locally."
echo "Frontend: http://127.0.0.1:5173"
echo "API:      http://127.0.0.1:8000"
echo
echo "Press Ctrl+C to stop all services."

# Wait for both processes
wait "$API_PID" "$WEB_PID"