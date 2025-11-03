#!/bin/bash
# Clean up system for template preparation

echo "=== Starting template cleanup ==="

# Clean package cache
dnf clean all

# Remove machine-specific configuration
# Ensure a fresh machine-id on first boot: zero out /etc/machine-id and remove DBus copy
rm -f /var/lib/dbus/machine-id
mkdir -p /var/lib/dbus || true
: > /etc/machine-id

# Clear network connections
rm -f /etc/NetworkManager/system-connections/*

# Clear SSH host keys (regenerated on first boot)
rm -f /etc/ssh/ssh_host_*

# Create service to regenerate SSH keys on first boot
cat > /etc/systemd/system/regenerate-ssh-keys.service << 'EOF'
[Unit]
Description=Regenerate SSH host keys
Before=sshd.service
ConditionFileNotEmpty=!/etc/ssh/ssh_host_rsa_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable regenerate-ssh-keys.service

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \;

# Clear command history
history -c
rm -f /root/.bash_history
rm -f /home/*/.bash_history

# Clear temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Zero free space for template optimization (quiet, non-fatal)
echo "=== Zeroing free space for template optimization ==="
(dd if=/dev/zero of=/zero bs=1M status=none || true) 2>/dev/null
sync || true
rm -f /zero || true

# Discard free blocks if supported (thin-provisioned storage)
fstrim -av || true

echo "=== Template cleanup completed ==="
