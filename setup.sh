#!/bin/bash

# Setup script for AlmaLinux 10 Terraform template
set -e

echo "=== AlmaLinux 10 Template Setup Script ==="
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    echo "   Visit: https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi
echo "✅ Terraform found: $(terraform version | head -n1)"

# Check if curl is available (needed for vSphere API calls)
if ! command -v curl &> /dev/null; then
    echo "❌ curl is not installed. Please install curl first."
    exit 1
fi
echo "✅ curl found (needed for vSphere REST API calls)"

# Create terraform.tfvars if it doesn't exist
if [[ ! -f "terraform.tfvars" ]]; then
    echo ""
    echo "📝 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ terraform.tfvars created. Please edit it with your vSphere settings."
    echo ""
    echo "Required configuration:"
    echo "  1. Update vSphere connection details"
    echo "  2. Set infrastructure names (datacenter, cluster, datastore, network)"
    echo "  3. Generate SSH key pair if needed"
    echo "  4. Generate password hash using: openssl passwd -6"
    echo ""
else
    echo "✅ terraform.tfvars already exists"
fi

# Check if SSH key exists
if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
    echo "✅ SSH public key found at ~/.ssh/id_rsa.pub"
    echo "   Add this to your terraform.tfvars:"
    echo "   ssh_public_key = \"$(cat ~/.ssh/id_rsa.pub)\""
elif [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    echo "✅ SSH public key found at ~/.ssh/id_ed25519.pub"
    echo "   Add this to your terraform.tfvars:"
    echo "   ssh_public_key = \"$(cat ~/.ssh/id_ed25519.pub)\""
else
    echo "⚠️  No SSH key found. Generate one with:"
    echo "   ssh-keygen -t ed25519 -f ~/.ssh/alma_template"
fi

echo ""
echo "🚀 Setup complete! Next steps:"
echo "   1. terraform.tfvars is already configured with your settings"
echo "   2. Run: terraform init"
echo "   3. Run: terraform plan"
echo "   4. Run: terraform apply"
echo ""
echo "ℹ️  Template conversion uses vSphere REST API (no external tools needed)"
echo ""
