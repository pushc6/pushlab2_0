#!/usr/bin/env bash
set -euo pipefail
ENV=${1:-}
if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <lab|prod> [extra terraform args]" >&2
  exit 1
fi
shift || true
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
ENV_DIR="$ROOT_DIR/envs/$ENV"
cd "$ENV_DIR"

terraform destroy "$@"
