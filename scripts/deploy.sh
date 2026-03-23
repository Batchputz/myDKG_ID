#!/usr/bin/env bash
# myDKG_ID deploy script
# Usage: FINDOKU_ENV=<dev|int|prod> ./scripts/deploy.sh <up|down|restart|status|render>
#
# Reads config/authelia.yaml, renders templates, and manages the podman-compose lifecycle.
# Requires: yq, envsubst, podman-compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_DIR/config/authelia.yaml"
SECRETS_FILE="$PROJECT_DIR/authelia/.secrets"
TEMPLATE="$PROJECT_DIR/templates/configuration.yml.tpl"
OUTPUT="$PROJECT_DIR/authelia/configuration.yml"

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
for cmd in yq envsubst podman-compose; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found in PATH." >&2
    exit 1
  fi
done

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
FINDOKU_DOMAIN="$(yq ".environments.$ENV.domain" "$CONFIG_FILE")"
FINDOKU_AUTH_POLICY="$(yq ".environments.$ENV.auth_policy" "$CONFIG_FILE")"
DEFAULT_REDIRECT_SVC="$(yq ".environments.$ENV.default_redirect_service" "$CONFIG_FILE")"

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

echo "==> Environment: $ENV"
echo "    Domain:      $FINDOKU_DOMAIN"
echo "    Auth URL:    $FINDOKU_AUTH_URL"
echo "    Redirect:    $FINDOKU_DEFAULT_REDIRECT"
echo "    Policy:      $FINDOKU_AUTH_POLICY"

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
    podman-compose -f "$PROJECT_DIR/podman-compose.yml" up -d
    ;;
  down)
    echo "==> Stopping containers..."
    podman-compose -f "$PROJECT_DIR/podman-compose.yml" down
    ;;
  restart)
    render_template
    echo "==> Restarting containers..."
    podman-compose -f "$PROJECT_DIR/podman-compose.yml" down
    podman-compose -f "$PROJECT_DIR/podman-compose.yml" up -d
    ;;
  render)
    render_template
    echo "==> Template rendered (no containers started)."
    ;;
  status)
    podman ps --filter "name=mydkg" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ;;
  *)
    echo "Usage: FINDOKU_ENV=<dev|int|prod> $0 <up|down|restart|render|status>" >&2
    exit 1
    ;;
esac
