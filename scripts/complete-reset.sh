#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

$SCRIPT_DIR/shutdown-client.sh
$SCRIPT_DIR/shutdown-server.sh
$SCRIPT_DIR/prune-docker.sh