#!/bin/bash
# Configure essential services

echo "=== Configuring services ==="

# Enable required services only
systemctl enable sshd
systemctl enable vmtoolsd
systemctl enable cloud-init-local cloud-init cloud-config cloud-final

# SSH key injection is handled via Packer provisioner when ssh_public_key is provided

# Ensure cloud-init VMware datasource is configured
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/90_dpkg.cfg <<'EOF'
datasource_list: [VMware, OVF, NoCloud]
EOF

echo "=== Service configuration completed ==="
