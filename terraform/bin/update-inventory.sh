#!/usr/bin/env bash
set -euo pipefail
ENV=${1:-}
if [[ -z "${ENV}" ]]; then
  echo "Usage: $0 <lab|prod>" >&2
  exit 1
fi
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
TF_DIR="${ROOT_DIR}/envs/${ENV}"
INV_DIR="${ROOT_DIR}/../ansible/inventories/${ENV}"

# Initialize in read-only mode; inventory is generated from outputs
terraform -chdir="${TF_DIR}" init -input=false -lock=false -no-color >/dev/null
mkdir -p "${INV_DIR}"
NEW_FILE=$(mktemp)
terraform -chdir="${TF_DIR}" output -raw ansible_inventory_yaml >"${NEW_FILE}"

# Update only if changed to avoid noise
TARGET_FILE="${INV_DIR}/hosts.yml"
if [[ ! -f "${TARGET_FILE}" ]] || ! cmp -s "${TARGET_FILE}" "${NEW_FILE}"; then
  mv "${NEW_FILE}" "${TARGET_FILE}"
  echo "Updated ${TARGET_FILE}"
else
  rm -f "${NEW_FILE}"
  echo "No changes for ${TARGET_FILE}"
fi
