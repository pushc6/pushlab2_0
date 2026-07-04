#!/bin/bash
# Update system packages
set -euo pipefail

echo "=== Updating system packages ==="
dnf update -y

echo "=== System update completed ==="
