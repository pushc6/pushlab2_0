#!/bin/bash
# Enterprise template validation script

set -e

echo "=== AlmaLinux Template Validation ==="

# Test 1: Verify OS version
echo "Testing OS version..."
if grep -q "AlmaLinux release 10" /etc/redhat-release; then
    echo "✅ AlmaLinux 10 detected"
else
    echo "❌ Wrong OS version"
    exit 1
fi

# Test 2: Verify essential packages
echo "Testing essential packages..."
REQUIRED_PACKAGES="curl open-vm-tools openssh-server"
for pkg in $REQUIRED_PACKAGES; do
    if rpm -q $pkg >/dev/null 2>&1; then
        echo "✅ $pkg installed"
    else
        echo "❌ $pkg missing"
        exit 1
    fi
done

# Test 3: Verify services
echo "Testing services..."
REQUIRED_SERVICES="sshd"
for service in $REQUIRED_SERVICES; do
    if systemctl is-enabled $service >/dev/null 2>&1; then
        echo "✅ $service enabled"
    else
        echo "❌ $service not enabled"
        exit 1
    fi
done

# Test 4: Verify network configuration
echo "Testing network..."
if ip route | grep -q default; then
    echo "✅ Network connectivity"
else
    echo "❌ No network"
    exit 1
fi

# Test 5: Verify template preparation
echo "Testing template readiness..."
if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
    echo "✅ SSH keys cleared for template"
else
    echo "❌ SSH keys not cleared"
    exit 1
fi

if [[ ! -s /etc/machine-id ]]; then
    echo "✅ Machine ID cleared for template"
else
    echo "❌ Machine ID not cleared"
    exit 1
fi

echo "=== All tests passed! Template is ready ==="
