# myDKG ID (Authelia) - Standalone Authentication Stack

Centralized SSO gateway for all `*.findoku.de` services, powered by [Authelia](https://www.authelia.com/).

## Structure

```
myDKG_ID/
├── config/
│   └── authelia.yaml          # Per-environment settings (single source of truth)
├── templates/
│   └── configuration.yml.tpl  # Authelia config template (envsubst placeholders)
├── scripts/
│   └── deploy.sh              # Renders template + manages docker compose
├── authelia/
│   ├── .secrets               # Secrets (never committed)
│   ├── users_database.yml     # User store (Argon2id hashes)
│   ├── configuration.yml      # Rendered output (gitignored)
│   ├── db.sqlite3             # Runtime (gitignored)
│   └── notification.txt       # Runtime (gitignored)
├── redis/                     # Redis persistence (gitignored)
├── docker-compose.yml         # Authelia + Redis containers
├── create-user.sh             # Password hash helper
└── README.md
```

## Prerequisites

- `docker compose`
- `yq` (YAML processor)
- `envsubst` (from `gettext`)

## Quick Start

```bash
# Render config and start the stack
FINDOKU_ENV=dev ./scripts/deploy.sh up

# Other commands
FINDOKU_ENV=dev ./scripts/deploy.sh down       # stop
FINDOKU_ENV=dev ./scripts/deploy.sh restart    # re-render + restart
FINDOKU_ENV=dev ./scripts/deploy.sh render     # render only
FINDOKU_ENV=dev ./scripts/deploy.sh status     # container status
```

`FINDOKU_ENV` must match the value used by FinEdge_Gateway.

## Environments

| Env | Domain | Auth URL |
|-----|--------|----------|
| `dev` | `dev.findoku.de` | `https://auth.dev.findoku.de` |
| `int` | `int.findoku.de` | `https://auth.int.findoku.de` |
| `prod` | `findoku.de` | `https://auth.findoku.de` |

## Protected Services

- `magnus` — Knowledge base
- `kihub` — AI Hub
- `neuromark` — Document processing
- `genesis` — Project genesis platform

To add a service: update `config/authelia.yaml` (services list) and `templates/configuration.yml.tpl` (access_control rule).

## Create a User

```bash
./create-user.sh 'ThePassword'
```

Paste the hash into `authelia/users_database.yml`.

## Notes

- TLS termination is handled by FinEdge_Gateway (Traefik), not this stack.
- `authelia/configuration.yml` is generated — edit the template or config YAML instead.
- Secrets live in `authelia/.secrets` and are injected at render time.
- Each stack has its own Redis instance for Authelia sessions.
