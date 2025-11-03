# AlmaLinux 10 VM Template Deployment

## Current Status

✅ **ISO Downloaded and Uploaded**: AlmaLinux 10 minimal ISO is ready in your datastore
⚠️ **Manual Installation Required**: AlmaLinux 10 uses a different automation format than expected

## Quick Manual Installation Steps

Since you now have a VM running with the AlmaLinux 10 installer GUI:

### 1. **Complete the Installation Manually**
1. Select **English** as language (or your preference)
2. In the Installation Summary screen:
   - **Installation Destination**: Select the 40GB disk, choose "Automatic partitioning"
   - **Network & Host Name**: Enable the network interface and set hostname to `almalinux-template`
    - **Root Password**: Choose a strong password (or use a pre-hashed value you generate)
   - **User Creation**: Create a user or just use root

### 2. **Minimal Package Selection**
- Choose **Minimal Install** to keep it lean
- Optionally add **Standard** for basic tools

### 3. **Complete Installation**
- Click **Begin Installation**
- Wait for installation to complete (~10-15 minutes)
- Click **Reboot**

### 4. **Post-Installation Template Preparation**

After the VM reboots and you can SSH in:

```bash
# Update system
sudo dnf update -y

# Install essential packages
sudo dnf install -y curl wget vim htop tree unzip tar gzip net-tools \
    bind-utils telnet traceroute rsyslog sudo firewalld git which \
    man-pages open-vm-tools python3 python3-pip chrony

# Enable services
sudo systemctl enable sshd firewalld chronyd vmtoolsd

# Configure firewall
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# Add your SSH key (replace with your own public key)
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAA...your-public-key... comment" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Clean up for template
sudo dnf clean all
sudo rm -f /etc/machine-id && sudo touch /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id && sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo find /var/log -type f -exec truncate -s 0 {} \;
history -c && rm -f ~/.bash_history

# Shutdown for template conversion
sudo shutdown -h now
```

### 5. **Convert to Template via vSphere UI**
1. Right-click the powered-off VM
2. Select **Template** → **Convert to Template**
3. Confirm the conversion

## Alternative: Automated Approach

If you want to try the automated approach again, I can create a proper kickstart configuration for AlmaLinux 10.

## Files Created

- ✅ **AlmaLinux-10.0-x86_64-minimal.iso** - Downloaded and uploaded to datastore
- ✅ **VM Template** - Ready for manual installation  
- 📝 **kickstart.cfg** - For future automated installations
- 📝 **Manual steps** - This guide

The manual approach is actually more reliable for creating a perfect template since you have full control over the installation process!
