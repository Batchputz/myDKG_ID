#!/usr/bin/env bash
# myDKG_ID deploy script
# Usage: FINDOKU_ENV=<dev|int|prod> ./scripts/deploy.sh <up|down|restart|status|render>
#
# Reads config/authelia.yaml, renders templates, and manages the compose lifecycle.
# Requires: yq, envsubst, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config/authelia.yaml"
SECRETS_FILE="$PROJECT_DIR/authelia/.secrets"
TEMPLATE="$PROJECT_DIR/templates/configuration.yml.tpl"
OUTPUT="$PROJECT_DIR/authelia/configuration.yml"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
for cmd in yq envsubst; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found in PATH." >&2
    exit 1
  fi
done

if ! docker compose version &>/dev/null; then
  echo "ERROR: 'docker compose' is required but not found in PATH." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Validate FINDOKU_ENV
# ---------------------------------------------------------------------------
ENV="${FINDOKU_ENV:?Set FINDOKU_ENV to dev, int, or prod}"

if [[ "$ENV" != "dev" && "$ENV" != "int" && "$ENV" != "prod" ]]; then
  echo "ERROR: FINDOKU_ENV must be one of: dev, int, prod (got '$ENV')" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "ERROR: Secrets file not found: $SECRETS_FILE" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: Template not found: $TEMPLATE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Extract settings from authelia.yaml
# ---------------------------------------------------------------------------
FINDOKU_DOMAIN="$(yq -r ".environments.$ENV.domain" "$CONFIG_FILE")"
FINDOKU_AUTH_POLICY="$(yq -r ".environments.$ENV.auth_policy" "$CONFIG_FILE")"
DEFAULT_REDIRECT_SVC="$(yq -r ".environments.$ENV.default_redirect_service" "$CONFIG_FILE")"

# Server tuning
FINDOKU_SERVER_BUFFERS_READ="$(yq -r ".environments.$ENV.server.buffers.read" "$CONFIG_FILE")"
FINDOKU_SERVER_BUFFERS_WRITE="$(yq -r ".environments.$ENV.server.buffers.write" "$CONFIG_FILE")"
FINDOKU_SERVER_TIMEOUTS_READ="$(yq -r ".environments.$ENV.server.timeouts.read" "$CONFIG_FILE")"
FINDOKU_SERVER_TIMEOUTS_WRITE="$(yq -r ".environments.$ENV.server.timeouts.write" "$CONFIG_FILE")"
FINDOKU_SERVER_TIMEOUTS_IDLE="$(yq -r ".environments.$ENV.server.timeouts.idle" "$CONFIG_FILE")"

# Logging
FINDOKU_LOG_LEVEL="$(yq -r ".environments.$ENV.log.level" "$CONFIG_FILE")"

# Session tuning
FINDOKU_SESSION_EXPIRATION="$(yq -r ".environments.$ENV.session.expiration" "$CONFIG_FILE")"
FINDOKU_SESSION_INACTIVITY="$(yq -r ".environments.$ENV.session.inactivity" "$CONFIG_FILE")"

# Rate limiting
FINDOKU_REGULATION_MAX_RETRIES="$(yq -r ".environments.$ENV.regulation.max_retries" "$CONFIG_FILE")"
FINDOKU_REGULATION_FIND_TIME="$(yq -r ".environments.$ENV.regulation.find_time" "$CONFIG_FILE")"
FINDOKU_REGULATION_BAN_TIME="$(yq -r ".environments.$ENV.regulation.ban_time" "$CONFIG_FILE")"

# Timezone
FINDOKU_TZ="$(yq -r ".environments.$ENV.timezone" "$CONFIG_FILE")"

# Derived values
FINDOKU_TOTP_ISSUER="auth.${FINDOKU_DOMAIN}"
FINDOKU_AUTH_URL="https://auth.${FINDOKU_DOMAIN}"
FINDOKU_DEFAULT_REDIRECT="https://${DEFAULT_REDIRECT_SVC}.${FINDOKU_DOMAIN}"

# ---------------------------------------------------------------------------
# Load secrets from authelia/.secrets
# ---------------------------------------------------------------------------
FINDOKU_JWT_SECRET="$(grep '^JWT_SECRET=' "$SECRETS_FILE" | cut -d'=' -f2-)"
FINDOKU_SESSION_SECRET="$(grep '^SESSION_SECRET=' "$SECRETS_FILE" | cut -d'=' -f2-)"
FINDOKU_STORAGE_SECRET="$(grep '^STORAGE_SECRET=' "$SECRETS_FILE" | cut -d'=' -f2-)"

export FINDOKU_DOMAIN FINDOKU_AUTH_POLICY FINDOKU_TOTP_ISSUER
export FINDOKU_AUTH_URL FINDOKU_DEFAULT_REDIRECT
export FINDOKU_JWT_SECRET FINDOKU_SESSION_SECRET FINDOKU_STORAGE_SECRET
export FINDOKU_SERVER_BUFFERS_READ FINDOKU_SERVER_BUFFERS_WRITE
export FINDOKU_SERVER_TIMEOUTS_READ FINDOKU_SERVER_TIMEOUTS_WRITE FINDOKU_SERVER_TIMEOUTS_IDLE
export FINDOKU_LOG_LEVEL
export FINDOKU_SESSION_EXPIRATION FINDOKU_SESSION_INACTIVITY
export FINDOKU_REGULATION_MAX_RETRIES FINDOKU_REGULATION_FIND_TIME FINDOKU_REGULATION_BAN_TIME
export FINDOKU_TZ

echo "==> Environment: $ENV"
echo "    Domain:      $FINDOKU_DOMAIN"
echo "    Auth URL:    $FINDOKU_AUTH_URL"
echo "    Redirect:    $FINDOKU_DEFAULT_REDIRECT"
echo "    Policy:      $FINDOKU_AUTH_POLICY"
echo "    Compose:     docker compose"
echo "    Log level:   $FINDOKU_LOG_LEVEL"
echo "    Session:     ${FINDOKU_SESSION_EXPIRATION} / ${FINDOKU_SESSION_INACTIVITY}"
echo "    Regulation:  ${FINDOKU_REGULATION_MAX_RETRIES} retries / ${FINDOKU_REGULATION_FIND_TIME} / ban ${FINDOKU_REGULATION_BAN_TIME}"
echo "    Timezone:    $FINDOKU_TZ"

# ---------------------------------------------------------------------------
# Render template
# ---------------------------------------------------------------------------
render_template() {
  echo "==> Rendering template..."
  envsubst < "$TEMPLATE" > "$OUTPUT"
  echo "    authelia/configuration.yml  ← rendered"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------
ACTION="${1:-up}"

case "$ACTION" in
  up)
    render_template
    echo "==> Starting containers..."
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  down)
    echo "==> Stopping containers..."
    docker compose -f "$COMPOSE_FILE" down
    ;;
  restart)
    render_template
    echo "==> Restarting containers..."
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  render)
    render_template
    echo "==> Template rendered (no containers started)."
    ;;
  status)
    docker ps --filter "name=mydkg" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ;;
  *)
    echo "Usage: FINDOKU_ENV=<dev|int|prod> $0 <up|down|restart|render|status>" >&2
    exit 1
    ;;
esac
