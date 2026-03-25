<div align="center">

<br/>

```
██████╗  ██████╗ ███████╗████████╗██████╗  █████╗
██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔══██╗██╔══██╗
██║  ██║██║   ██║███████╗   ██║   ██████╔╝███████║
██║  ██║██║   ██║╚════██║   ██║   ██╔══██╗██╔══██║
██████╔╝╚██████╔╝███████║   ██║   ██║  ██║██║  ██║
╚═════╝  ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝
```

### **Deploy**

*Orchestration & deployment layer for the Dostra CRM system*

<br/>

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![Laravel](https://img.shields.io/badge/Laravel-FF2D20?style=flat-square&logo=laravel&logoColor=white)](https://laravel.com/)
[![React](https://img.shields.io/badge/React-61DAFB?style=flat-square&logo=react&logoColor=black)](https://react.dev/)
[![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Vite](https://img.shields.io/badge/Vite-646CFF?style=flat-square&logo=vite&logoColor=white)](https://vitejs.dev/)
[![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat-square&logo=nginx&logoColor=white)](https://nginx.org/)

<br/>

</div>

---

## Overview

This repository is the **single source of truth** for running the Dostra CRM system. It brings together the `dostra-web` frontend and `dostra-api` backend into a unified, containerised environment — for local development, staging, and production alike.

> It does **not** contain application logic. That lives in the submodules.

---

## 🗂 Project Structure

```
dostra-deploy/
├── 🌐  dostra-web/          # Frontend  — React · Vite · TypeScript · Tailwind
├── ⚙️  dostra-api/          # Backend   — Laravel (PHP)
├── 🔀  nginx/               # Reverse proxy configuration
├── 🛠  scripts/             # Deployment & utility scripts
├── .dockerignore
├── .env.example
├── .gitignore
├── .gitmodules
├── docker-compose.yml
├── Dockerfile
└── README.md
```

### Git Submodules

This repository uses Git submodules to independently version each service:

| Submodule | Role | Stack |
|-----------|------|-------|
| [`dostra-web`](../dostra-web) | CRM dashboard & UI | React, Vite, TypeScript, Tailwind |
| [`dostra-api`](../dostra-api) | Lead ingestion & REST API | Laravel, PHP |

---

## ⚡ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | React · Vite · TypeScript · Tailwind CSS |
| **Backend** | Laravel (PHP) |
| **Database** | SQLite *(dev)* · MySQL or PostgreSQL *(prod)* |
| **DevOps** | Docker · Docker Compose |
| **Integration** | WordPress + Zapier Webhooks |

---

## 🚀 Getting Started

### 1. Clone with submodules

```bash
git clone --recurse-submodules <repo-url>
cd dostra-deploy
```

Already cloned without submodules?
> ```bash
> git submodule update --init --recursive
> ```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` with your local configuration before proceeding.

### 3. Start the stack

```bash
docker-compose up --build
```

| Service | URL |
|---------|-----|
| 🌐 Frontend | http://localhost:5173 |
| ⚙️ Backend | http://localhost:8000 |

---

## 🔄 Working with Submodules

**Pull all latest changes:**
```bash
git submodule update --remote --merge
```

**Update a specific service:**
```bash
# Frontend
cd dostra-web && git pull origin main

# Backend
cd ../dostra-api && git pull origin main
```

**Clone fresh with submodules:**
```bash
git clone --recurse-submodules <repo-url>
```

---

## 📦 Services

<details>
<summary><strong>🌐 dostra-web</strong> — CRM Frontend</summary>

<br/>

- Role-based access control (admin / client)
- Lead management dashboard
- Built with React + Vite + TypeScript

</details>

<details>
<summary><strong>⚙️ dostra-api</strong> — API Backend</summary>

<br/>

- Receives inbound leads from WordPress via Zapier
- Persists and exposes lead data
- Full REST API consumed by the frontend

</details>

---

## 🔁 Data Flow

```
WordPress Form  ──▶  Zapier  ──▶  Laravel API  ──▶  Database  ──▶  React CRM
```

---

## 🏗 Deployment Responsibilities

This repo owns:

- **Service orchestration** via Docker Compose
- **Environment management** via `.env` files
- **Reverse proxy** configuration via Nginx
- **Deployment scripts** in `/scripts`

Application logic belongs to the submodules — not here.

---

## 🧠 Why This Structure?

```
✦  Frontend and backend are independently versioned and deployable
✦  Each service can be developed and tested in isolation
✦  The deploy layer stays clean — no business logic, just infrastructure
✦  Scales naturally: swap services, add new ones, without touching others
```

---

## ⚠️ Important: Committing Changes

Always commit inside `dostra-web` or `dostra-api` **first**, then update the submodule reference in this repo:

```bash
# After committing changes inside a submodule...
git add dostra-web dostra-api
git commit -m "chore: update submodules"
git push
```

---

## 🗺 Roadmap

- [ ] CI/CD pipeline via GitHub Actions
- [ ] Production-hardened Docker configuration
- [ ] Load balancing and horizontal scaling
- [ ] Centralised auth and authorisation layer
- [ ] Multi-tenant client support

---

## 👤 Author

**Chetan Nagar**

---

## 📄 License

Internal use only. Add a licence file if this becomes public.

---

<div align="center">
<sub>Built with Docker · Laravel · React</sub>
</div>
