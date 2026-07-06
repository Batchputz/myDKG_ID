# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## What This Repo Is

myDKG ID is an **infrastructure-only** repository — no application code, only container orchestration and configuration. It deploys a standalone [Authelia](https://www.authelia.com/) authentication portal branded as "myDKG ID", serving as the centralized SSO gateway for all `*.findoku.de` services.

## Architecture

```
Client ──▶ FinEdge_Gateway (Traefik, TLS termination)
                │
                ▼
          Authelia (:9091)
          ├── file-based user DB  (authelia/users_database.yml, Argon2id)
          ├── SQLite storage      (authelia/db.sqlite3)
          ├── Redis sessions      (127.0.0.1:6379)
          └── filesystem notifier (authelia/notification.txt)
```

Both containers run with `network_mode: host`, binding directly to the host network. TLS termination is handled by FinEdge_Gateway (Traefik), not by this stack.

### Environment Model

A global `FINDOKU_ENV` variable (`dev`, `int`, or `prod`) controls all configuration. Both this repo and FinEdge_Gateway must use the same value.

| Env | Domain suffix | Auth URL |
|-----|--------------|----------|
| `dev` | `dev.findoku.de` | `https://auth.dev.findoku.de` |
| `int` | `int.findoku.de` | `https://auth.int.findoku.de` |
| `prod` | `findoku.de` | `https://auth.findoku.de` |

Environment-specific settings live in `config/authelia.yaml`. The deploy script renders `templates/configuration.yml.tpl` into `authelia/configuration.yml` via `envsubst`.

### Protected Services

Services protected behind Authelia forward-auth (defined in `config/authelia.yaml`):

- **magnus** — Knowledge base
- **kihub** — AI Hub
- **neuromark** — Document processing pipeline
- **genesis** — Project genesis platform

To add a new service: add it to `config/authelia.yaml` under `services`, then add a matching `access_control` rule block in `templates/configuration.yml.tpl`.

### How Other Services Integrate

Protected services must be routed through FinEdge_Gateway with the `forwardauth_authelia` middleware. The gateway sends a subrequest to Authelia's verify endpoint at `https://auth.{domain}/api/verify`.

## Commands

### Deploy the Stack

```bash
FINDOKU_ENV=dev ./scripts/deploy.sh up        # render config + start containers
FINDOKU_ENV=dev ./scripts/deploy.sh down       # stop containers
FINDOKU_ENV=dev ./scripts/deploy.sh restart    # render + restart
FINDOKU_ENV=dev ./scripts/deploy.sh render     # render config only (no containers)
FINDOKU_ENV=dev ./scripts/deploy.sh status     # show container status
```

### Create a New User

Generate an Argon2id password hash, then add the entry to `authelia/users_database.yml`:

```bash
./create-user.sh 'ThePassword'
```

Paste the resulting hash into `authelia/users_database.yml` following the existing user format.

### Inspect Running State

```bash
docker ps --filter name=mydkg   # list running containers
docker exec mydkg-authelia cat /config/notification.txt   # check notification output
docker exec mydkg-redis redis-cli -h 127.0.0.1 DBSIZE     # count session keys
```

## Key Files to Know

- `config/authelia.yaml` — Single source of truth for per-environment settings (domains, policy, services).
- `templates/configuration.yml.tpl` — Authelia config template with `${VARIABLE}` placeholders.
- `scripts/deploy.sh` — Reads `FINDOKU_ENV`, extracts settings via `yq`, renders template, manages compose lifecycle.
- `authelia/.secrets` — Secrets file (JWT, session, storage keys). **Never commit.**
- `authelia/users_database.yml` — Flat-file user store. Passwords are Argon2id hashes.
- `authelia/configuration.yml` — **Rendered output** (generated, gitignored). Do not edit directly.
- `docker-compose.yml` — Container definitions for Authelia + Redis.

## Conventions

- Configuration changes go into `config/authelia.yaml` or `templates/configuration.yml.tpl`, never hardcoded.
- The rendered `authelia/configuration.yml` is gitignored — always re-render via `deploy.sh`.
- `FINDOKU_ENV` must match between this repo and FinEdge_Gateway.
- Secrets are loaded from `authelia/.secrets` at deploy time, not stored in config YAML.
- Redis is scoped per stack (each solution gets its own Redis instance for Authelia sessions).
