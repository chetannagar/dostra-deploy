# v1.0.0 — 2026-10-24

First tracked release of the Dostra stack (API + web + production deployment).

## Security

- **PHP upgraded to 8.5.12.** Fixes two critical remote-code-execution bugs
  fixed upstream in PHP 8.5.12 / 8.4.27. The API now refuses to install, build
  or boot on an unpatched PHP:
  - `composer.json` requires `~8.4.27 || ^8.5.12`
  - both Dockerfiles pin the exact PHP version instead of a floating tag
  - `bootstrap/app.php` checks the PHP version on every request and command
- Dependencies updated (`composer.lock`) to clear the reported security advisories.

## Deploy

- **Fixed the production deploy script.** It used `docker compose up --no-cache`,
  which is not a valid flag. It now runs `build --pull --no-cache`, then `up -d`.
- **Real health checks.** `api`, `web` and `nginx` now have healthchecks and
  start in dependency order. The deploy script waits for every service to be
  healthy and fails on `unhealthy`, `exited` or timeout. The API is healthy only
  after migrations finish.
- The deploy script now fails fast if a required `.env.prod` value is missing or empty.
- `CACHE_STORE=file` in production, so `migrate --isolated` works on the very
  first deploy (the database cache-lock table does not exist yet).

## Nginx

- **Filament admin panel is reachable in production.** `/admin`, `/livewire-*`,
  `/filament` and `/up` now go to PHP-FPM, and Filament's static assets are
  served directly. Previously everything except `/api` and `/sanctum` went to the SPA.
- Real client IP and scheme are passed to Laravel (trusted proxy), so HTTPS URLs
  and per-IP rate limits work correctly behind Nginx.
- Nginx re-resolves the `api` and `web` containers through Docker DNS, so a
  redeploy no longer causes 502 errors until Nginx is restarted.

## API (dostra-api)

- Production image hardened: runs as non-root `www-data`, installs production
  dependencies only, builds the autoloader after the source is copied, and starts
  through `docker/entrypoint.prod.sh` (optimize, optional migrate, `exec php-fpm`).
- Trusted proxy configuration, with a test.
- Dev image runs `composer install` on start so the vendor volume can't go stale.
- Filament assets refreshed; Laravel Boost guidelines and skills updated.

## Web (dostra-web)

- No functional changes in this release. Included at the pinned commit in
  `components.json`.

## Upgrade notes

- On a fresh database the admin panel has no user. Create one before first login
  (e.g. via `php artisan tinker` inside the `dostra-api-prod` container). Prod never seeds.
- Dev stacks: no manual `docker compose down -v` is needed; the API container
  now syncs `vendor` itself.
