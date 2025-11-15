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
    INFO)
      printf "%s [${GREEN}%s${NC}] %s\n" "$ts" "$level" "$message"
      ;;
    WARN)
      printf "%s [${YELLOW}%s${NC}] %s\n" "$ts" "$level" "$message"
      ;;
    ERROR)
      printf "%s [${RED}%s${NC}] %s\n" "$ts" "$level" "$message" >&2
      ;;
    *)
      # Unknown level -> no color
      printf "%s [%s] %s\n" "$ts" "$level" "$message"
      ;;
  esac
}

### Load and check .env
ENV_FILE="$REPO_DIR/.env"
log INFO "Loading environment variables from $ENV_FILE file"
if [[ -f "$ENV_FILE" ]]; then
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
fi
log INFO "Checking that TS_AUTHKEY variable is set"
if [[ -z "${TS_AUTHKEY:-}" ]]; then
    log ERROR "TS_AUTHKEY environment variable not set. Please set it in the .env file or export it in your shell."
    exit 1
fi

## Check Docker and Docker Compose
log INFO "Checking Docker installation"
command -v docker >/dev/null 2>&1 || {
  log ERROR "Docker not installed or not in PATH"
  exit 1
}




SERVER_COMPOSE_FILE="$REPO_DIR/infra/docker-compose.server.yml"
log INFO "Docker: Checking compose file at $SERVER_COMPOSE_FILE"
if [[ ! -f "$SERVER_COMPOSE_FILE" ]]; then
    log ERROR "Compose file not found: $SERVER_COMPOSE_FILE"
    exit 1
fi
log INFO "Docker: Pulling latest Docker images..."
if ! docker compose -f "$SERVER_COMPOSE_FILE" pull; then
    log ERROR "Pull failed"
    exit 1
fi
log INFO "Docker: Building local images..."
if ! docker compose -f "$SERVER_COMPOSE_FILE" build --pull; then
    log ERROR "Docker Build failed"
    exit 1
fi
log INFO "Docker: Starting stack using compose up..."
if ! docker compose -f "$SERVER_COMPOSE_FILE" up -d; then
    log ERROR "Docker compose up failed"
    exit 1
fi

log INFO "Checking container status:"
if ! docker compose -f "$SERVER_COMPOSE_FILE" ps; then
    log WARN "Could not check container status"
fi
log INFO "Deployment complete!"