# Firewall Hardened Role

Production-ready Ansible role for hardening firewalld configurations with SSH lockout protection, automatic rollback, and VLAN-based access control.

## Table of Contents

- [Features](#features)
- [VLAN Structure](#vlan-structure)
- [Access Levels](#access-levels)
- [SSH Hardening](#ssh-hardening)
- [Quick Start](#quick-start)
- [Variables](#variables)
- [Examples](#examples)
- [Safety Features](#safety-features)
- [Deployment](#deployment)

## Features

✅ **SSH Lockout Protection** - Multi-subnet SSH access with atomic transactions
✅ **Automatic Rollback** - Emergency rollback on any failure
✅ **VLAN-Based Access Control** - 5 VLANs + proxy + custom sources
✅ **Rich Rules** - Source-based firewall restrictions
✅ **Docker Support** - Automatic docker0 interface handling
✅ **Input Validation** - Pre-flight checks and post-implementation validation
✅ **Idempotent** - Safe to run multiple times

## VLAN Structure

This role supports the following network VLANs:

| VLAN | Subnet | Purpose | SSH Access |
|------|--------|---------|------------|
| **Management** | 10.37.10.0/24 | Admin access only | ❌ No |
| **Trusted** | 10.37.20.0/24 | Internal hosts | ✅ **Yes** |
| **DMZ** | 10.37.70.0/24 | Public-facing hosts | ❌ No |
| **WireGuard** | 10.37.90.0/24 | VPN access | ✅ **Yes** |

**Reverse Proxies:**
- `10.37.70.5` - nginx (external)
- `10.37.70.24` - nginx-internal

## Access Levels

Services are configured using the unified `firewall_services` variable with explicit access levels:

### 1. `public` - Accessible from anywhere (0.0.0.0/0)

```yaml
firewall_services:
  - port: 80
    protocol: tcp
    name: "HTTP"
    access: public
```

**Firewall Rule:** Simple port rule (no source restriction)

---

### 2. `management_vlan` - Management VLAN only (10.37.10.0/24)

```yaml
firewall_services:
  - port: 9090
    protocol: tcp
    name: "Cockpit Admin Panel"
    access: management_vlan
```

**Firewall Rule:**
```
rule family="ipv4" source address="10.37.10.0/24" port port="9090" protocol="tcp" accept
```

---

### 3. `trusted_vlan` - Trusted VLAN only (10.37.20.0/24)

**Most common access level** - Use this for internal services that should only be accessible from the trusted network.

```yaml
firewall_services:
  - port: 5432
    protocol: tcp
    name: "PostgreSQL"
    access: trusted_vlan
```

**Firewall Rule:**
```
rule family="ipv4" source address="10.37.20.0/24" port port="5432" protocol="tcp" accept
```

---

### 4. `dmz_vlan` - DMZ VLAN only (10.37.70.0/24)

```yaml
firewall_services:
  - port: 8080
    protocol: tcp
    name: "Internal API"
    access: dmz_vlan
```

**Firewall Rule:**
```
rule family="ipv4" source address="10.37.70.0/24" port port="8080" protocol="tcp" accept
```

---

### 5. `wireguard_vlan` - WireGuard VPN VLAN (10.37.90.0/24)

```yaml
firewall_services:
  - port: 3000
    protocol: tcp
    name: "Grafana"
    access: wireguard_vlan
```

**Firewall Rule:**
```
rule family="ipv4" source address="10.37.90.0/24" port port="3000" protocol="tcp" accept
```

---

### 6. `proxy` - Reverse Proxies + Management

Services accessible from reverse proxy servers and the management VLAN.

```yaml
firewall_services:
  - port: 8080
    protocol: tcp
    name: "Web Application"
    access: proxy
```

**Firewall Rules:** (Creates one rule per source)
```
rule family="ipv4" source address="10.37.70.5" port port="8080" protocol="tcp" accept
rule family="ipv4" source address="10.37.70.24" port port="8080" protocol="tcp" accept
rule family="ipv4" source address="10.37.10.0/24" port port="8080" protocol="tcp" accept
```

---

### 7. `custom` - User-Defined Sources

For custom source lists (e.g., specific IPs or subnets).

```yaml
firewall_services:
  - port: 53
    protocol: udp
    name: "DNS"
    access: custom
    sources:
      - "10.37.0.0/16"
      - "192.168.0.0/16"
```

**Firewall Rules:**
```
rule family="ipv4" source address="10.37.0.0/16" port port="53" protocol="udp" accept
rule family="ipv4" source address="192.168.0.0/16" port port="53" protocol="udp" accept
```

## SSH Hardening

SSH is automatically hardened to allow access **ONLY** from:

✅ **Trusted VLAN** (10.37.20.0/24)
✅ **WireGuard VLAN** (10.37.90.0/24)

**How it works:**

1. Adds rich rules for each allowed subnet
2. Reloads firewall atomically
3. Tests SSH connectivity
4. **Only then** removes the default SSH service
5. Automatic rollback on any failure

**SSH Rich Rules Created:**
```
rule family="ipv4" source address="10.37.20.0/24" port port="22" protocol="tcp" accept
rule family="ipv4" source address="10.37.90.0/24" port port="22" protocol="tcp" accept
```

**Override allowed subnets:**
```yaml
firewall_ssh_allowed_subnets:
  - "10.37.20.0/24"
  - "10.37.90.0/24"
  - "192.168.1.0/24"  # Add custom subnet
```

## Quick Start

### 1. Add to Host Variables

Create `inventories/manual/host_vars/myhost.yml`:

```yaml
---
# Firewall configuration for myhost

firewall_services:
  # Public web server
  - port: 80
    protocol: tcp
    name: "HTTP"
    access: public

  - port: 443
    protocol: tcp
    name: "HTTPS"
    access: public

  # Internal database - trusted VLAN only
  - port: 5432
    protocol: tcp
    name: "PostgreSQL"
    access: trusted_vlan

  # Application accessible via reverse proxy
  - port: 8080
    protocol: tcp
    name: "Application API"
    access: proxy
```

### 2. Run the Playbook

```bash
ansible-playbook -i inventories/manual/on_premise.yml \
  firewall_test.yml \
  --limit myhost \
  --check --diff  # Dry run first!
```

### 3. Apply for Real

```bash
ansible-playbook -i inventories/manual/on_premise.yml \
  firewall_test.yml \
  --limit myhost
```

## Variables

### Network VLANs

```yaml
# Default values (override in group_vars/host_vars)
firewall_management_vlan_subnet: "10.37.10.0/24"
firewall_trusted_vlan_subnet: "10.37.20.0/24"
firewall_dmz_vlan_subnet: "10.37.70.0/24"
firewall_wireguard_vlan_subnet: "10.37.90.0/24"
```

### Reverse Proxy IPs

```yaml
firewall_reverse_proxy_ips:
  - "10.37.70.5"    # nginx external
  - "10.37.70.24"   # nginx internal
```

### SSH Configuration

```yaml
firewall_ssh_port: 22
firewall_ssh_allowed_subnets:
  - "{{ firewall_trusted_vlan_subnet }}"
  - "{{ firewall_wireguard_vlan_subnet }}"
```

### Safety Settings

```yaml
# Rollback timer (seconds) - rules auto-revert if not made permanent
firewall_rollback_timer: 300

# Enable preflight connectivity checks
firewall_enable_preflight: true

# Enable post-implementation validation
firewall_enable_validation: true
```

### Docker Support

```yaml
firewall_docker_interface: "docker0"
firewall_docker_zone: "trusted"
```

## Examples

### Example 1: Web Server (Public + Proxy Services)

```yaml
# inventories/manual/host_vars/nginx.yml
---
firewall_services:
  # Public access
  - port: 80
    protocol: tcp
    name: "HTTP"
    access: public

  - port: 443
    protocol: tcp
    name: "HTTPS"
    access: public
```

### Example 2: Docker Host (Mixed Access)

```yaml
# inventories/manual/host_vars/docker.yml
---
firewall_services:
  # Management services - trusted VLAN only
  - port: 2376
    protocol: tcp
    name: "Docker Daemon"
    access: trusted_vlan

  - port: 5000
    protocol: tcp
    name: "Docker Registry"
    access: trusted_vlan

  # Proxy-accessible services
  - port: 3000
    protocol: tcp
    name: "Grafana"
    access: proxy

  - port: 8080
    protocol: tcp
    name: "Portainer"
    access: proxy

  - port: 9090
    protocol: tcp
    name: "Prometheus"
    access: proxy
```

### Example 3: DNS Server (Custom Sources)

```yaml
# inventories/prod/host_vars/dns02.yml
---
firewall_services:
  # DNS accessible from local networks only
  - port: 53
    protocol: tcp
    name: "DNS TCP"
    access: custom
    sources:
      - "10.37.0.0/16"
      - "192.168.0.0/16"

  - port: 53
    protocol: udp
    name: "DNS UDP"
    access: custom
    sources:
      - "10.37.0.0/16"
      - "192.168.0.0/16"

  # Management interface - trusted VLAN only
  - port: 5380
    protocol: tcp
    name: "Technitium Web Console"
    access: trusted_vlan
```

### Example 4: Game Server (Public + Trusted)

```yaml
# inventories/manual/host_vars/gameserver.yml
---
firewall_services:
  # Public game servers
  - port: 7777
    protocol: tcp
    name: "Game Server"
    access: public

  - port: 8888
    protocol: tcp
    name: "Game Query Port"
    access: public

  # Management interfaces - trusted VLAN only
  - port: 8080
    protocol: tcp
    name: "AMP Web UI"
    access: trusted_vlan

  - port: 2223
    protocol: tcp
    name: "AMP Instance 1"
    access: trusted_vlan
```

### Example 5: VPN-Only Service

```yaml
# inventories/manual/host_vars/internal-app.yml
---
firewall_services:
  # Only accessible via WireGuard VPN
  - port: 8080
    protocol: tcp
    name: "Internal Dashboard"
    access: wireguard_vlan

  # Database - trusted VLAN only
  - port: 3306
    protocol: tcp
    name: "MySQL"
    access: trusted_vlan
```

## Safety Features

### 1. SSH Lockout Protection

- **Atomic transactions** - Rich rules added and tested BEFORE removing SSH service
- **Connectivity verification** - Tests SSH access after applying rules
- **Automatic rollback** - Restores SSH service on any failure

### 2. Block/Rescue Pattern

```yaml
- name: SSH Hardening with Atomic Safety and Rollback
  block:
    - name: Add SSH rich rules
      # ...
    - name: Reload firewall
      # ...
    - name: Test SSH connectivity (CRITICAL)
      # ...
    - name: Remove SSH service (now safe)
      # ...
  rescue:
    - name: Emergency - Re-enable SSH service
      # Automatic rollback!
```

### 3. Preflight Checks

- Validates all required variables are defined
- Verifies firewalld is installed and running
- Backs up current firewall configuration
- Port and protocol validation

### 4. Post-Implementation Validation

- Verifies firewalld is still running
- Checks SSH rich rules are active for all allowed subnets
- Confirms SSH service is NOT globally enabled
- Tests final SSH connectivity

### 5. Input Validation

```yaml
- Port must be 1-65535
- Protocol must be tcp or udp
- Access must be: public, management_vlan, trusted_vlan, dmz_vlan, wireguard_vlan, proxy, or custom
- Custom access requires sources list
```

## Deployment

### Phased Rollout Strategy

Process hosts **one at a time** (serial: 1) for maximum safety:

#### Phase 1: Critical Infrastructure (Phase Playbook)

```yaml
# playbooks/firewall_phase1.yml
- name: Phase 1 - Critical Infrastructure
  hosts: phase1_critical
  serial: 1  # One at a time!
  roles:
    - firewall_hardened
```

**Test on a single host first:**

```bash
# Dry run
ansible-playbook playbooks/firewall_phase1.yml --limit nginx --check --diff

# Apply
ansible-playbook playbooks/firewall_phase1.yml --limit nginx
```

#### Phase Groups (Define in Inventory)

```yaml
# inventories/manual/on_premise.yml
phase1_critical:
  hosts:
    nginx:
    docker:
    nginx-internal.localdomain:

phase2_infrastructure:
  hosts:
    semaphore.localdomain:
    crowdsec.localdomain:
    docker-internal.localdomain:

phase3_services:
  hosts:
    cupsserver.localdomain:
    linuxgameserver.localdomain:
    gitea:
```

### Rollback Procedure

If something goes wrong, use the rollback playbook:

```bash
ansible-playbook playbooks/firewall_rollback.yml --limit <hostname>
```

## Troubleshooting

### SSH Access Lost?

If you lose SSH access (this shouldn't happen with the safety features):

1. **Access via console** (IPMI, iLO, ESXi console, etc.)
2. **Re-enable SSH service:**
   ```bash
   firewall-cmd --add-service=ssh
   firewall-cmd --runtime-to-permanent
   ```

### Check Active Rules

```bash
# List all active rich rules
firewall-cmd --list-rich-rules

# List all active ports
firewall-cmd --list-ports

# List all active services
firewall-cmd --list-services
```

### View Firewall Logs

```bash
# View hardening log
cat /var/log/firewall_hardening.log

# View firewall configuration backup
ls -la /tmp/firewall_backup_*.txt
```

### Dry Run Mode

Always test with `--check --diff` first:

```bash
ansible-playbook firewall_test.yml \
  --limit myhost \
  --check --diff
```

## File Structure

```
roles/firewall_hardened/
├── README.md                      # This file
├── defaults/
│   └── main.yml                   # Default variables
├── handlers/
│   └── main.yml                   # Firewall reload handler
├── meta/
│   └── main.yml                   # Role metadata
└── tasks/
    ├── main.yml                   # Main orchestration
    ├── preflight.yml              # Pre-flight checks
    ├── ssh_hardening.yml          # SSH hardening with rollback
    ├── service_rules.yml          # Service rule application
    ├── docker_rules.yml           # Docker-specific rules
    └── validate.yml               # Post-implementation validation
```

## Requirements

- **OS:** RHEL/CentOS/AlmaLinux/Rocky 8+
- **Firewall:** firewalld (will be installed if missing)
- **Python:** 3.6+
- **Ansible:** 2.10+
- **Collection:** ansible.posix

## License

MIT

## Author

Generated with Claude Code 🤖
