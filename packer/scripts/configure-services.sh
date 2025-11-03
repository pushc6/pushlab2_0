#!/bin/bash
# Configure essential services

echo "=== Configuring services ==="

# Enable required services only
systemctl enable sshd
systemctl enable vmtoolsd

# SSH key injection is handled via Packer provisioner when ssh_public_key is provided

echo "=== Service configuration completed ==="
