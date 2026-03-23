# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## What This Repo Is

myDKG ID is an **infrastructure-only** repository — no application code, only container orchestration and configuration. It deploys a standalone [Authelia](https://www.authelia.com/) authentication portal branded as "myDKG ID", serving as the centralized SSO gateway for all `*.findoku.de` services (Magnus, KIHub, etc.).

## Architecture

```
Client ──▶ NGINX (TLS termination)
              ├─ :8443  dev  (auth.int.findoku.de)
              └─ :443   prod (auth.findoku.de)
                    │
                    ▼
              Authelia (:9091)
              ├── file-based user DB  (authelia/users_database.yml, Argon2id)
              ├── SQLite storage      (authelia/db.sqlite3)
              ├── Redis sessions      (127.0.0.1:6379)
              └── filesystem notifier (authelia/notification.txt)
```

All three containers run with `network_mode: host`, so they bind directly to the host network — no inter-container DNS.

### Environment Variants

| File | Cookie domain | Authelia URL | Protected domains |
|------|--------------|--------------|-------------------|
| `authelia/configuration.yml` (dev) | `int.findoku.de` | `https://auth.int.findoku.de` | `magnus.int.findoku.de`, `kihub.int.findoku.de` |
| `authelia/configuration.yml.prod` | `findoku.de` | `https://auth.findoku.de` | `magnus.findoku.de`, `kihub.findoku.de` |

To switch environments, replace `configuration.yml` with the appropriate variant and restart.

### How Other Services Integrate

Protected services (Magnus, KIHub) must send a subrequest to Authelia's verify endpoint:
- Dev: `https://auth.int.findoku.de/api/verify`
- Prod: `https://auth.findoku.de/api/verify`

## Commands

### Start / Stop the Stack

```bash
podman-compose up -d          # start all (authelia + redis)
podman-compose down            # stop all
podman-compose logs -f         # tail all logs
podman-compose logs -f authelia  # tail authelia only
```

### Create a New User

Generate an Argon2id password hash, then add the entry to `authelia/users_database.yml`:

```bash
./create-user.sh 'ThePassword'
```

Paste the resulting hash into `authelia/users_database.yml` following the existing user format.

### Inspect Running State

```bash
podman ps --filter name=mydkg   # list running containers
podman exec mydkg-authelia cat /config/notification.txt   # check notification output
podman exec mydkg-redis redis-cli -h 127.0.0.1 DBSIZE     # count session keys
```

## Key Files to Know

- `authelia/configuration.yml` — **active** Authelia config (dev). All auth policy, session, and storage settings live here.
- `authelia/configuration.yml.prod` — production variant; differs only in domain/URL values.
- `authelia/.secrets` — Authelia secrets file. **Never commit real secret values.**
- `authelia/users_database.yml` — flat-file user store. Passwords are Argon2id hashes.
- `nginx/nginx.conf` — TLS-terminating reverse proxy; upstreams to Authelia on `:9091`.
- `nginx/certs/` — TLS certificate and key (not committed).

## Conventions

- Configuration changes go into the YAML files, never hard-coded into scripts or compose overrides.
- The `.backup` suffixed files (`podman-compose.yml.backup`, `configuration.yml.backup`) preserve the previous working state before a change — keep this pattern when making significant config changes.
- Redis is scoped per stack (each solution gets its own Redis instance for Authelia sessions).
