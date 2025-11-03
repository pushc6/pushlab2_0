#!/usr/bin/env bash
set -euo pipefail

# Render a generated kickstart with your SSH public key and run packer build using key-only SSH
# Usage: packer/bin/build.sh [-k /path/to/private_key] [-p /path/to/public_key] [-v /path/to/vars.pkrvars.hcl] [-- extra packer args]

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
PACKER_DIR="$ROOT_DIR/packer"
HTTP_DIR="$PACKER_DIR/http"
KS_TEMPLATE="$HTTP_DIR/almalinux-10.vsphere-x86_64.ks"
KS_RENDERED="$HTTP_DIR/generated.ks"

PRIV_KEY="${PRIV_KEY:-}"   # env override
PUB_KEY="${PUB_KEY:-}"     # env override (string contents)
PUB_KEY_FILE=""             # optional path to .pub
VAR_FILE="$PACKER_DIR/secrets.pkrvars.hcl"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--key)
      PRIV_KEY="$2"; shift 2 ;;
    -p|--pub)
      PUB_KEY_FILE="$2"; shift 2 ;;
    -v|--var-file)
      VAR_FILE="$2"; shift 2 ;;
    --)
      shift; break ;;
    *)
      echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Determine private key
if [[ -z "$PRIV_KEY" ]]; then
  if [[ -f "$HOME/.ssh/id_ed25519" ]]; then PRIV_KEY="$HOME/.ssh/id_ed25519"; 
  elif [[ -f "$HOME/.ssh/id_rsa" ]]; then PRIV_KEY="$HOME/.ssh/id_rsa"; 
  else
    echo "No private key found. Provide with -k /path/to/private_key" >&2; exit 1
  fi
fi

# Determine public key content
if [[ -z "$PUB_KEY" ]]; then
  if [[ -n "$PUB_KEY_FILE" && -f "$PUB_KEY_FILE" ]]; then
    PUB_KEY=$(cat "$PUB_KEY_FILE")
  elif [[ -f "${PRIV_KEY}.pub" ]]; then
    PUB_KEY=$(cat "${PRIV_KEY}.pub")
  elif [[ -f "$PACKER_DIR/ssh_public_key.pub" ]]; then
    PUB_KEY=$(cat "$PACKER_DIR/ssh_public_key.pub")
  else
    echo "Public key not found. Provide with -p /path/to/key.pub or set PUB_KEY env var." >&2; exit 1
  fi
fi

# Render KS by replacing placeholder
if ! grep -q "REPLACED_BY_RENDERER" "$KS_TEMPLATE"; then
  echo "Kickstart template missing placeholder REPLACED_BY_RENDERER: $KS_TEMPLATE" >&2; exit 1
fi

# Escape sed replacement chars
ESC_PUB_KEY=$(printf '%s' "$PUB_KEY" | sed -e 's/[\&/]/\\&/g')
sed "s/REPLACED_BY_RENDERER/${ESC_PUB_KEY}/" "$KS_TEMPLATE" > "$KS_RENDERED"

# Ensure perms
chmod 0644 "$KS_RENDERED"

# Run packer build with key-only SSH
cd "$PACKER_DIR"
set -x
PACKER_LOG=${PACKER_LOG:-1} packer build \
  -var-file="${VAR_FILE}" \
  -var "ssh_private_key_file=${PRIV_KEY}" \
  -var "ssh_public_key=${PUB_KEY}" \
  "$PACKER_DIR/alma-template.pkr.hcl" "$@"
set +x
