# Firewall Deployment Guide

## Quick Reference

### Deploy to Hosts

```bash
# Single host
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml --limit nginx

# Multiple hosts
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml --limit "docker,nginx,ansible"

# Entire group
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml --limit dockerhost

# All hosts (DANGEROUS - use with caution!)
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml
```

### Dry Run (Check What Would Change)

```bash
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml --limit nginx --check
```

### Skip Manual Approval

```bash
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml \
  --limit nginx \
  --extra-vars "firewall_require_approval=false"
```

### Rollback

```bash
# Automatic (uses latest backup)
ansible-playbook -i inventories/manual/on_premise.yml rollback_firewall.yml --limit nginx

# Specific backup file
ansible-playbook -i inventories/manual/on_premise.yml rollback_firewall.yml \
  --limit nginx \
  --extra-vars "backup_file=/tmp/firewall_backup_1765337903.txt"
```

## Files Overview

### Main Playbooks

| File | Purpose |
|------|---------|
| `deploy_firewall.yml` | Deploy/update firewall rules to any host |
| `rollback_firewall.yml` | Restore previous firewall configuration |

### Configuration Files

| Location | Purpose |
|----------|---------|
| `inventories/manual/host_vars/<hostname>.yml` | Per-host firewall services configuration |
| `roles/firewall_hardened/defaults/main.yml` | Default firewall settings |
| `/tmp/firewall_backup_*.txt` | Automatic backups (on each host) |

### Old Files (Can Be Removed)

These phase-based playbooks are no longer needed:
- `deploy_firewall_phase1.yml`
- `deploy_firewall_phase2.yml`
- `deploy_firewall_phase3.yml`
- `/tmp/deploy_firewall_docker.yml`
- `/tmp/deploy_firewall_docker_internal.yml`

## Host Variables Configuration

Configure firewall rules for each host in `inventories/manual/host_vars/<hostname>.yml`:

```yaml
---
# Example: inventories/manual/host_vars/docker.yml

firewall_services:
  # Public access (no source restrictions)
  - port: 80
    protocol: tcp
    name: "HTTP Web Server"
    access: public

  # Trusted VLAN only
  - port: 9999
    protocol: tcp
    name: "Admin Panel"
    access: trusted_vlan

  # Custom sources (multiple IPs/networks)
  - port: 8080
    protocol: tcp
    name: "API Server"
    access: custom
    sources:
      - "10.37.70.24/32"         # nginx internal (IPv4)
      - "fd00:1337:1337:70::24/128"  # nginx internal (IPv6)
      - "10.37.20.0/24"          # trusted_vlan (IPv4)
      - "fd00:1337:1337:20::/64" # trusted_vlan (IPv6)
```

### Access Types

| Type | Description | Example Use |
|------|-------------|-------------|
| `public` | Accessible from anywhere | Public web servers |
| `trusted_vlan` | Only from trusted VLAN (10.37.20.0/24) | Admin interfaces |
| `management_vlan` | Only from management VLAN (10.37.90.0/24) | Infrastructure tools |
| `dmz_vlan` | Only from DMZ VLAN (10.37.70.0/24) | Internal services |
| `wireguard_vlan` | Only from WireGuard VPN | Remote access services |
| `proxy` | From reverse proxy + management VLAN | Web apps behind proxy |
| `custom` | Specific IPs/networks (must define `sources`) | Specific integrations |

## Built-in Safety Features

### Automatic Rollback
- Triggers automatically if SSH connectivity is lost
- Restores previous firewall configuration
- Preserves SSH access

### Backups
- Created automatically before any changes: `/tmp/firewall_backup_<timestamp>.txt`
- Stored on each target host
- Contains full firewall state

### SSH Protection
1. Adds SSH rich rules first
2. Verifies SSH connectivity
3. Only then removes default SSH service
4. Verifies again after removal

### Docker Support
- Auto-detects all Docker bridge interfaces
- Adds bridges to trusted zone
- Supports custom Docker networks

## Common Tasks

### Add New Service to Host

1. Edit host vars file:
   ```bash
   nano inventories/manual/host_vars/docker.yml
   ```

2. Add service configuration:
   ```yaml
   firewall_services:
     - port: 3000
       protocol: tcp
       name: "New Application"
       access: custom
       sources:
         - "10.37.70.24/32"
         - "10.37.20.0/24"
   ```

3. Deploy:
   ```bash
   ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml --limit docker
   ```

### Verify Firewall Status on Host

```bash
# SSH to host
ssh push@<hostname>

# View all zones and rules
sudo firewall-cmd --list-all-zones

# View specific zone
sudo firewall-cmd --zone=public --list-all

# View rich rules
sudo firewall-cmd --list-rich-rules

# View trusted zone (Docker bridges)
sudo firewall-cmd --zone=trusted --list-interfaces

# Check logs
sudo journalctl -u firewalld -n 50
```

### Test Connectivity After Deployment

```bash
# From your workstation
nc -zv <hostname> <port>

# From within Docker container
docker exec <container> nc -zv <target> <port>

# HTTP test
curl -v http://<hostname>:<port>
```

## Troubleshooting

### SSH Access Lost

If you lose SSH access:

1. **Console access**: Log in via console/IPMI
2. **Stop firewalld**:
   ```bash
   sudo systemctl stop firewalld
   ```
3. **Restore backup**:
   ```bash
   ls -lt /tmp/firewall_backup_*.txt | head -1
   # Review the backup
   cat /tmp/firewall_backup_<timestamp>.txt
   ```
4. **Start firewalld**:
   ```bash
   sudo systemctl start firewalld
   ```
5. **Fix and redeploy**

### Container Can't Reach Another Container

**Symptoms**: "Host is unreachable" errors between containers on same host

**Solution**: Ensure Docker bridges are in trusted zone:

```bash
# Check if bridges are trusted
sudo firewall-cmd --zone=trusted --list-interfaces

# Should see: br-* and docker0

# If missing, redeploy firewall
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml --limit <hostname>
```

### Service Not Accessible

1. **Check firewall rules**:
   ```bash
   sudo firewall-cmd --list-all
   ```

2. **Check if service is listening**:
   ```bash
   sudo ss -tlnp | grep <port>
   ```

3. **Check host vars configuration**:
   ```bash
   cat inventories/manual/host_vars/<hostname>.yml
   ```

4. **Test from allowed source**:
   ```bash
   # From trusted VLAN
   nc -zv <hostname> <port>
   ```

### View Deployment History

```bash
# List all backups
ssh push@<hostname> "ls -lht /tmp/firewall_backup_*.txt"

# View specific backup
ssh push@<hostname> "cat /tmp/firewall_backup_<timestamp>.txt"

# Compare current vs backup
ssh push@<hostname> "diff <(firewall-cmd --list-all-zones) <(cat /tmp/firewall_backup_<timestamp>.txt)"
```

## Advanced Usage

### Custom Variables

Override defaults via `--extra-vars`:

```bash
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml \
  --limit nginx \
  --extra-vars "firewall_rollback_timer=600 firewall_enable_ipv6=false"
```

### Tags

Run specific parts of the role:

```bash
# Only Docker configuration
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml \
  --limit docker \
  --tags docker

# Only service rules (skip SSH hardening)
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml \
  --limit nginx \
  --tags firewall
```

### Limit by Pattern

```bash
# All Docker hosts
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml \
  --limit "docker*"

# All nginx hosts
ansible-playbook -i inventories/manual/on_premise.yml deploy_firewall.yml \
  --limit "*nginx*"
```

## Best Practices

1. **Always test on one host first**:
   ```bash
   ansible-playbook deploy_firewall.yml --limit test-host
   ```

2. **Use dry-run before production**:
   ```bash
   ansible-playbook deploy_firewall.yml --limit prod-host --check
   ```

3. **Keep host vars in version control**:
   ```bash
   git add inventories/manual/host_vars/
   git commit -m "Update firewall rules for nginx"
   ```

4. **Document custom rules**:
   ```yaml
   # Add comments to host vars
   - port: 8080
     name: "Custom App"  # Required for Project X integration
     access: custom
     sources:
       - "10.37.70.5/32"  # nginx-dmz
   ```

5. **Regular backups**: Firewall backups are automatic, but also:
   ```bash
   # Periodic manual backup
   ssh push@<host> "sudo firewall-cmd --list-all-zones > ~/firewall_manual_$(date +%Y%m%d).txt"
   ```

6. **Monitor logs after deployment**:
   ```bash
   ansible all -i inventories/manual/on_premise.yml \
     -m shell \
     -a "journalctl -u firewalld --since '5 minutes ago' --no-pager"
   ```
