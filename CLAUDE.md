# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **deployment/orchestration layer** for the Dostra CRM system. It contains no application logic — that lives in two Git submodules:

- `dostra-api/` — Laravel 13 backend (PHP 8.5+, Pest, Filament, Sanctum)
- `dostra-web/` — React 19 frontend (Vite, TypeScript, Tailwind)

The deploy repo owns: Docker Compose, Nginx config, environment files, and `scripts/`.

---

## Running the Stack

### Docker (recommended)

```bash
# Start (builds images, runs detached)
./scripts/docker-deploy.sh

# Stop (preserves named volumes for faster restarts)
./scripts/docker-rollback.sh

# Full reset including volumes
docker compose down -v
```

Services: Frontend → `http://127.0.0.1:5173` | API → `http://127.0.0.1:8000`

Named volumes (`dostra_api_vendor`, `dostra_web_node_modules`) prevent host/container platform mismatches — don't bind-mount over them.

### Local (without Docker)

```bash
# Requires PHP + Composer + Node.js already installed and deps installed
./scripts/run-all.sh
```

This concurrently runs `composer run dev` (Laravel) and `npm run dev` (Vite).

---

## Backend — `dostra-api/`

Laravel 13 · PHP 8.5 · SQLite (dev) · Sanctum · Filament v5 · Pest v4

### Setup (first time)

```bash
cd dostra-api
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
```

### Development commands

```bash
php artisan serve                          # Start dev server
php artisan test --compact                 # Run full test suite
php artisan test --compact --filter=name   # Run a single test/group
vendor/bin/pint --dirty --format agent     # Format changed PHP files
php artisan route:list                     # Inspect registered routes
php artisan tinker --execute "..."         # Execute PHP for debugging
```

### Architecture

**Two responsibilities:**

1. **Webhook ingestion** — `POST /api/webhook/leads` receives HMAC-signed leads from Zapier. Middleware `validate.lead.webhook` verifies the signature (`hash_hmac('sha256', timestamp.body, client_secret)`), timestamp freshness, client lookup, and idempotency by `X-Webhook-Id`.

2. **CRM REST API** — all other routes under `auth:sanctum` + `throttle:api.crm`. Role separation: `admin` sees everything; `client` sees only their assigned clients and leads. Enforced via Sanctum, Laravel Policies, and scoped Eloquent queries.

**Data model:** `clients` → `leads` (1:many). `clients` ↔ `users` (many:many via `client_user` pivot). `users.role` is either `admin` or `client`.

**Key conventions (from AGENTS.md):**
- Use Form Request classes for all validation (no inline controller validation)
- Use Eloquent Resources for API responses — check existing resources before adding new ones
- Use `php artisan make:` commands to scaffold new files
- Always run Pint after editing PHP: `vendor/bin/pint --dirty --format agent`
- Every change must have a Pest test; run `php artisan test --compact` with a filter before finalising
- Use `config('key')` not `env('KEY')` outside config files
- Avoid `DB::` — prefer `Model::query()`
- Always pass `--no-interaction` to Artisan commands in scripts

**Rate limits:** login: 5/min per email+IP · webhook: 60/min per client key · CRM: 120/min per user

**Seed credentials:** `admin@example.com` / `password` and `client@example.com` / `password`

---

## Frontend — `dostra-web/`

React 19 · Vite · TypeScript · Tailwind CSS

### Setup

```bash
cd dostra-web
npm install
cp .env.example .env        # set VITE_API_BASE_URL
npm run dev
```

The frontend communicates with the API at `VITE_API_BASE_URL` (default `http://127.0.0.1:8000/api`). In Docker, the browser reaches the backend via the host-mapped port, not the internal container name.

---

## Submodule Workflow

```bash
# Update all submodules to their latest remote commits
git submodule update --remote --merge

# After committing changes inside a submodule, update the pointer in this repo
git add dostra-api dostra-web
git commit -m "chore: update submodules"
```

Always commit inside the submodule first, then update the reference here.

---

## Environment Configuration

- `.env` at repo root controls Docker Compose variables (ports, app env overrides)
- `dostra-api/.env` is loaded by Docker as `env_file` and also used for local dev
- `dostra-web/.env` + `dostra-web/.env.local` are loaded by Vite (and Docker Compose)
- Copy from `.env.example` files before first run
