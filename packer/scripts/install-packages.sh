#!/bin/bash
# Install minimal essential packages for template

echo "=== Installing minimal essential packages ==="

dnf install -y \
    open-vm-tools \
    openssh-server \
    curl \
    cloud-init

echo "=== Package installation completed ==="

# Enable required services only
systemctl enable --now vmtoolsd || true
systemctl enable --now sshd || true
