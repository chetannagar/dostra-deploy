# Deploying Dostra CRM to Production

This guide covers everything needed to deploy the Dostra CRM stack to a production server using Docker Compose.

---

## Architecture

```text
Internet
   │
   ▼
Nginx (port 80/443)          ← only service exposed to the outside
   ├── /api/*  ──────────►  api container  (PHP-FPM :9000)  ──►  PostgreSQL
   └── /*      ──────────►  web container  (Nginx :80, static files)
```

Four containers, one Docker network:

| Container | Image | Role |
| --- | --- | --- |
| `dostra-nginx-prod` | `nginx:1.27-alpine` | Reverse proxy |
| `dostra-api-prod` | Built from `dostra-api/Dockerfile.prod` | Laravel PHP-FPM |
| `dostra-web-prod` | Built from `dostra-web/Dockerfile.prod` | React static files |
| `dostra-db-prod` | `postgres:17-alpine` | Database |

---

## Prerequisites

On the production server:

- Docker Engine 24+ and Docker Compose v2
- Git
- At least 1 GB RAM, 10 GB disk

```bash
# Verify
docker --version
docker compose version
```

---

## First-time Setup

### 1. Clone the repository

```bash
git clone <repo-url> dostra-deploy
cd dostra-deploy
```

### 2. Initialise submodules

```bash
git submodule update --init --recursive
```

### 3. Create the production env file

```bash
cp .env.prod.example .env.prod
```

Open `.env.prod` and fill in every value:

```bash
# PostgreSQL — used by both the db and api containers
POSTGRES_DB=dostra
POSTGRES_USER=dostra
POSTGRES_PASSWORD=<strong-random-password>

# Laravel
APP_KEY=<output of: php artisan key:generate --show>
APP_URL=https://yourdomain.com

# Frontend — baked into the JS bundle at build time
VITE_API_BASE_URL=https://yourdomain.com/api
```

> **APP_KEY** — if you don't have PHP locally, generate one with:

```bash
docker run --rm php:8.4-cli php -r "echo 'base64:' . base64_encode(random_bytes(32)) . PHP_EOL;"
```

### 4. Run the deploy script

```bash
./scripts/docker-deploy-prod.sh
```

The script:

- Validates `.env.prod` has no unfilled placeholders
- Updates submodules to latest commits
- Builds production images with `--no-cache`
- Starts all services in detached mode
- Waits for health checks to pass

---

## Subsequent Deploys

For every code update:

```bash
cd dostra-deploy
git pull                          # pull deploy repo changes
./scripts/docker-deploy-prod.sh  # rebuild and restart
```

Database migrations run automatically at container startup — no manual step needed.

---

## Environment Variables Reference

All variables are set in `.env.prod` and injected at runtime by Docker Compose.

| Variable | Required | Description |
| --- | --- | --- |
| `POSTGRES_DB` | ✓ | Database name |
| `POSTGRES_USER` | ✓ | Database user |
| `POSTGRES_PASSWORD` | ✓ | Database password — use a strong random value |
| `APP_KEY` | ✓ | Laravel encryption key — generate once, never rotate without planning |
| `APP_URL` | ✓ | Full public URL of the app, e.g. `https://yourdomain.com` |
| `VITE_API_BASE_URL` | ✓ | Public API URL baked into the frontend bundle at build time |

---

## SSL / HTTPS

The Nginx config (`nginx/nginx.conf`) has an SSL section that is commented out. To enable HTTPS:

### Option A — Certbot (Let's Encrypt)

```bash
# Install certbot on the host
apt install certbot

# Obtain a certificate (stop nginx first or use --standalone)
certbot certonly --standalone -d yourdomain.com

# Certificates land at:
#   /etc/letsencrypt/live/yourdomain.com/fullchain.pem
#   /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

Then in `nginx/nginx.conf`:

1. Uncomment the `server { listen 443 ssl ... }` block
2. Set `ssl_certificate` and `ssl_certificate_key` to the Certbot paths
3. Uncomment the HTTP → HTTPS redirect block
4. Mount certs into the Nginx container in `docker-compose.prod.yml`:

```yaml
volumes:
  - /etc/letsencrypt/live/yourdomain.com:/etc/nginx/certs:ro
```

1. Uncomment `"443:443"` in the nginx ports section
2. Redeploy

### Option B — Upstream load balancer / CDN

If a load balancer (AWS ALB, Cloudflare, etc.) terminates SSL before traffic reaches the server, no changes are needed. Keep Nginx on port 80 as-is.

---

## Useful Commands

```bash
# View running containers
docker compose -f docker-compose.prod.yml ps

# Stream logs from all services
docker compose -f docker-compose.prod.yml logs -f

# Stream logs from one service
docker compose -f docker-compose.prod.yml logs -f api

# Run a Laravel artisan command
docker exec dostra-api-prod php artisan <command>

# Open a database shell
docker exec -it dostra-db-prod psql -U $POSTGRES_USER -d $POSTGRES_DB

# Stop the stack (preserves data volume)
docker compose -f docker-compose.prod.yml down

# Stop and delete all data (destructive — use with caution)
docker compose -f docker-compose.prod.yml down -v
```

---

## Data & Backups

Database data lives in the Docker named volume `dostra_postgres_data_prod`. It persists across container restarts and re-deploys.

To back up the database:

```bash
docker exec dostra-db-prod pg_dump -U $POSTGRES_USER $POSTGRES_DB > backup_$(date +%Y%m%d_%H%M%S).sql
```

To restore:

```bash
cat backup.sql | docker exec -i dostra-db-prod psql -U $POSTGRES_USER -d $POSTGRES_DB
```

---

## Troubleshooting

### Stack fails to start — db unhealthy

```bash
docker logs dostra-db-prod
```

Usually a wrong `POSTGRES_PASSWORD` or volume permission issue.

### API container keeps restarting

```bash
docker logs dostra-api-prod
```

Common causes: wrong `APP_KEY`, `DB_*` mismatch with Postgres vars, missing migration.

### Frontend shows blank page or API errors

- Verify `VITE_API_BASE_URL` in `.env.prod` matches your actual domain
- Remember: this is baked in at build time — a change requires a full rebuild

### Nginx 502 Bad Gateway

- API container not healthy yet — wait and retry
- Check `docker compose -f docker-compose.prod.yml ps` for container status
