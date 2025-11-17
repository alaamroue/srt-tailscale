#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

### Logging
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  local level="$1"; shift
  local message="$*"
  local ts
  ts="$(date +"%Y-%m-%d %H:%M:%S")"

  case "$level" in
    INFO) printf "%s [${GREEN}%s${NC}] %s\n" "$ts" "$level" "$message" ;;
    WARN) printf "%s [${YELLOW}%s${NC}] %s\n" "$ts" "$level" "$message" ;;
    ERROR) printf "%s [${RED}%s${NC}] %s\n" "$ts" "$level" "$message" >&2 ;;
    *) printf "%s [%s] %s\n" "$ts" "$level" "$message" ;;
  esac
}

### Determine environment
ENVIRONMENT="${1:-prod}"  # default to production

if [[ "$ENVIRONMENT" == "dev" ]]; then
  COMPOSE_FILES="-f $REPO_DIR/infra/docker-compose.client.yml -f $REPO_DIR/infra/docker-compose.client.dev.yml"
else
  COMPOSE_FILES="-f $REPO_DIR/infra/docker-compose.client.yml"
fi

ENV_FILE="$REPO_DIR/.env"
### Load and check env variables
if [[ -f "$ENV_FILE" ]]; then
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
else
    log WARN "$ENV_FILE not found — continuing without loading"
fi

if [[ -z "${TS_AUTHKEY_CLIENT:-}" ]]; then
    log ERROR "TS_AUTHKEY_CLIENT is missing. Add it to $ENV_FILE or export it first."
    exit 1
fi

### Docker checks
command -v docker >/dev/null 2>&1 || {
  log ERROR "Docker not installed"
  exit 1
}

docker compose $COMPOSE_FILES pull || log WARN "Pull failed or skipped for dev"

docker compose $COMPOSE_FILES build --pull || {
    log ERROR "Docker build failed"
    exit 1
}

docker compose $COMPOSE_FILES up -d || {
    log ERROR "Compose up failed"
    exit 1
}

docker compose $COMPOSE_FILES ps || log WARN "Unable to check container status"

log INFO "Deployment complete for $ENVIRONMENT mode!"
