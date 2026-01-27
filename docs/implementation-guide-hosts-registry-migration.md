# Implementation Guide: Migrate Configs to Hosts/Services Registry

**Document Version:** 1.0
**Created:** 2026-01-26
**Status:** Ready for Implementation
**Estimated Scope:** 26 files to update

---

## Overview

This document provides complete instructions for migrating all hardcoded IP references in Ansible configurations to use the centralized hosts/services registry at `ansible/group_vars/all/hosts_registry.yml`.

**Goal:** Replace all hardcoded IPs with Jinja2 variable references so that IP changes only require updating one file.

---

## Prerequisites

Before starting, ensure these files exist:

| File | Purpose |
|------|---------|
| `ansible/group_vars/all/hosts_registry.yml` | Hosts and services registry (ALREADY CREATED) |
| `ansible/group_vars/all/main.yml` | Global variables |
| `ansible/roles/technitium_dns_sync/` | DNS sync role (ALREADY CREATED) |
| `ansible/sync_dns.yml` | DNS sync playbook (ALREADY CREATED) |

---

## Registry Reference

### Hosts Lookup

Use `hosts.X.ip` when referencing a physical/virtual host:

```yaml
# Available hosts (key: hostname, ip)
hosts.synology           # 10.37.20.4
hosts.nginx_dmz          # 10.37.70.5
hosts.docker_secure      # 10.37.70.6
hosts.docker             # 10.37.70.7
hosts.veeam              # 10.37.70.21
hosts.truenas            # 10.37.70.22
hosts.nginx_internal     # 10.37.70.24
hosts.crowdsec           # 10.37.70.26
hosts.ansible_controller # 10.37.70.27
hosts.gitea              # 10.37.80.4
hosts.packer_builder     # 10.37.80.5
hosts.docker_internal    # 10.37.80.6 (MOVED from 10.37.70.25)
hosts.raspberrypi_ha     # 10.37.50.10
hosts.prusa3d            # 10.37.50.20
hosts.cupsserver         # 10.37.30.10
hosts.linuxgameserver    # 10.37.30.20
```

### Services Lookup

Use `services.X.ip` when referencing a service (preferred for application-level access):

```yaml
# Available services (key: ip, hostname, port, host)
services.semaphore            # docker_internal:3004
services.gitea                # gitea:3000
services.grafana              # docker_internal:3002
services.victoriametrics      # docker_internal:8428
services.victorialogs         # docker_internal:9428
services.alloy                # docker_internal:12345
services.influxdb             # docker_internal:8086
services.oauth2_proxy         # docker_internal:4180
services.crowdsec_lapi        # crowdsec:8080
services.crowdsec_api_manager # docker_internal:5000
services.mqtt                 # docker_internal:1883
services.immich               # docker_internal:2283
services.sonarr               # docker:8989
services.radarr               # docker:7878
services.lidarr               # docker:8686
services.home_assistant       # raspberrypi_ha:8123
services.peanut               # docker_internal:8080
services.nut                  # docker_internal:3493
services.technitium_dns       # docker_secure:5380
services.truenas              # truenas:443
```

### Usage Patterns

```yaml
# Firewall SSH access (service-based - recommended)
firewall_ssh_allowed_subnets:
  - "{{ services.semaphore.ip }}/32"  # Semaphore Ansible automation

# Firewall SSH access (host-based - when service doesn't apply)
firewall_ssh_allowed_subnets:
  - "{{ hosts.ansible_controller.ip }}/32"  # Ansible control node

# CrowdSec LAPI URL
crowdsec_lapi_url: "http://{{ services.crowdsec_lapi.ip }}:{{ services.crowdsec_lapi.port }}"

# Nginx proxy backend (can use hostname since nginx resolves DNS)
backend_host: "{{ services.grafana.hostname }}"

# OPNsense alias
opnsense_aliases:
  - name: "semaphore"
    content:
      - "{{ services.semaphore.ip }}"
```

---

## Files to Update

### Category 1: Firewall SSH Rules (13 files)

These files have `firewall_ssh_allowed_subnets` with hardcoded `10.37.70.25/32` for Semaphore access.

| File | Line | Current Value | New Value |
|------|------|---------------|-----------|
| `ansible/inventories/manual/host_vars/ansible.localdomain.yml` | 10 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/docker.yml` | 50 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/nginx-internal.localdomain.yml` | 53 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/linuxgameserver.localdomain.yml` | 10 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/docker-secure.localdomain.yml` | 10 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/prusa3dbawkz.localdomain.yml` | 11 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/crowdsec.localdomain.yml` | 22 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/nginx.yml` | 52 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/raspberrypi-ha.localdomain.yml` | 12 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/manual/host_vars/cupsserver.localdomain.yml` | 10 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/prod/host_vars/packer_builder.yml` | 9 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/prod/host_vars/dns02.yml` | 9 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |
| `ansible/inventories/prod/host_vars/gitea/firewall.yml` | 9 | `"10.37.70.25/32"  # semaphore` | `"{{ services.semaphore.ip }}/32"  # semaphore` |

**Additional IPs to update in these files:**

Many of these files also have other hardcoded IPs that should be updated:

```yaml
# Common pattern in firewall_ssh_allowed_subnets:
- "10.37.70.27/32"  # ansible.localdomain  →  "{{ hosts.ansible_controller.ip }}/32"
- "10.37.70.21/32"  # veeam/Ansible controller  →  "{{ hosts.veeam.ip }}/32"
```

---

### Category 2: Nginx Proxy Backends (3 files)

| File | Line | Current Value | New Value |
|------|------|---------------|-----------|
| `ansible/group_vars/nginx_internal/oauth2_vars.yml` | 6 | `oauth2_proxy_host: "10.37.70.25"` | `oauth2_proxy_host: "{{ services.oauth2_proxy.hostname }}"` |
| `ansible/group_vars/nginx_internal/proxy_vars_enhanced.yml` | 18 | `oauth2_proxy_host: "10.37.70.25"` | `oauth2_proxy_host: "{{ services.oauth2_proxy.hostname }}"` |
| `ansible/group_vars/nginx_internal/proxy_vars_enhanced.yml` | 139 | `backend_host: "10.37.70.25"` (grafana) | `backend_host: "{{ services.grafana.hostname }}"` |
| `ansible/group_vars/nginx_internal/proxy_vars_enhanced.yml` | 155 | `backend_host: "10.37.70.25"` (semaphore) | `backend_host: "{{ services.semaphore.hostname }}"` |
| `ansible/group_vars/reverse_proxies/mqtt.yml` | 6 | `mqtt_backend_host: "10.37.70.25"` | `mqtt_backend_host: "{{ services.mqtt.hostname }}"` |

**Note:** Nginx can resolve DNS hostnames, so using `.hostname` is preferred for proxy backends.

---

### Category 3: OPNsense Firewall (1 file)

**File:** `ansible/group_vars/opnsense/vars.yml`

```yaml
# Line 63 - Update alias
# BEFORE:
opnsense_aliases:
  - name: "semaphore"
    type: host
    content:
      - "10.37.70.25"
    description: "Semaphore Ansible UI server"

# AFTER:
opnsense_aliases:
  - name: "semaphore"
    type: host
    content:
      - "{{ services.semaphore.ip }}"
    description: "Semaphore Ansible UI server (docker-internal)"
```

---

### Category 4: CrowdSec LAPI References (Multiple files)

Many host_vars files have hardcoded CrowdSec LAPI URLs:

```yaml
# BEFORE:
crowdsec_lapi_url: "http://10.37.70.26:8080"

# AFTER:
crowdsec_lapi_url: "http://{{ services.crowdsec_lapi.ip }}:{{ services.crowdsec_lapi.port }}"
```

**Files to check:**
- `ansible/inventories/manual/host_vars/nginx-internal.localdomain.yml`
- `ansible/inventories/manual/host_vars/nginx.yml`
- `ansible/inventories/manual/host_vars/docker.yml`
- `ansible/inventories/manual/host_vars/docker-internal.localdomain.yml`
- Any other file with `crowdsec_lapi_url`

---

### Category 5: docker-internal Host Vars (1 file)

**File:** `ansible/inventories/manual/host_vars/docker-internal.localdomain.yml`

Update the comment at line 2:
```yaml
# BEFORE:
# Firewall configuration for docker-internal.localdomain (10.37.70.25)

# AFTER:
# Firewall configuration for docker-internal.localdomain ({{ hosts.docker_internal.ip }})
# Note: Actual IP defined in group_vars/all/hosts_registry.yml
```

---

### Category 6: Comments Only (2 files)

These files have IPs in comments that should be updated for accuracy:

| File | Line | Change |
|------|------|--------|
| `ansible/deploy_mqtt_proxy.yml` | 10 | Update comment from `10.37.70.25` to `docker-internal` |
| `ansible/inventories/manual/host_vars/docker-internal.localdomain.yml` | 2 | Update comment |

---

## Implementation Steps

### Step 1: Verify Registry

```bash
# Check that the registry loads correctly
cd /path/to/tf_generate_alma
ansible-inventory -i ansible/inventories/manual/on_premise.yml --list | grep -A5 '"hosts"'
```

### Step 2: Test Variable Resolution

```bash
# Create a test playbook to verify variables resolve
cat > /tmp/test_registry.yml << 'EOF'
- hosts: localhost
  connection: local
  gather_facts: false
  vars_files:
    - ansible/group_vars/all/hosts_registry.yml
  tasks:
    - debug:
        msg: |
          docker_internal IP: {{ hosts.docker_internal.ip }}
          semaphore IP: {{ services.semaphore.ip }}
          semaphore hostname: {{ services.semaphore.hostname }}
          semaphore port: {{ services.semaphore.port }}
EOF

ansible-playbook /tmp/test_registry.yml
```

Expected output:
```
docker_internal IP: 10.37.80.6
semaphore IP: 10.37.80.6
semaphore hostname: docker-internal.localdomain
semaphore port: 3004
```

### Step 3: Update Files

For each file in the categories above, make the specified replacements.

**Recommended order:**
1. Category 1: Firewall SSH rules (largest impact)
2. Category 3: OPNsense (affects cross-VLAN access)
3. Category 2: Nginx backends
4. Category 4: CrowdSec LAPI
5. Category 5 & 6: Comments

### Step 4: Validate Syntax

```bash
# Check YAML syntax
ansible-playbook --syntax-check ansible/site.yml

# Dry run to see what would change
ansible-playbook -i ansible/inventories/manual/on_premise.yml \
  ansible/site.yml --tags firewall --check --diff
```

### Step 5: Apply Changes

```bash
# Apply firewall changes
ansible-playbook -i ansible/inventories/manual/on_premise.yml \
  ansible/site.yml --tags firewall

# Apply OPNsense changes
ansible-playbook -i ansible/inventories/opnsense/hosts.yml \
  ansible/opnsense.yml

# Apply nginx changes
ansible-playbook -i ansible/inventories/manual/on_premise.yml \
  ansible/site.yml --tags nginx
```

### Step 6: Sync DNS

```bash
# Sync DNS records from registry
ansible-playbook ansible/sync_dns.yml \
  -e "technitium_dns_api_token=YOUR_TOKEN"
```

---

## Validation Checklist

After implementation, verify:

- [ ] `ansible-playbook --syntax-check ansible/site.yml` passes
- [ ] Test playbook shows correct IP resolution
- [ ] Semaphore can SSH to all managed hosts
- [ ] Nginx proxies can reach backends
- [ ] CrowdSec agents can reach LAPI
- [ ] OPNsense rules allow cross-VLAN traffic
- [ ] DNS records resolve to correct IPs

---

## Rollback

If issues occur, the original IPs are documented in this file. To rollback:

1. Revert the changed files: `git checkout -- ansible/`
2. Re-run the firewall playbook with original configs
3. Investigate the issue before re-attempting

---

## Quick Reference: Find All Hardcoded IPs

```bash
# Find all remaining hardcoded IPs for docker-internal (old IP)
grep -r "10\.37\.70\.25" ansible/

# Find all hardcoded IPs in host_vars
grep -rE "10\.37\.[0-9]+\.[0-9]+" ansible/inventories/*/host_vars/

# Find IPs that should be registry references
grep -rE '"10\.37\.' ansible/group_vars/ ansible/inventories/
```

---

## File Locations Summary

```
ansible/
├── group_vars/
│   └── all/
│       ├── hosts_registry.yml     ← SOURCE OF TRUTH (hosts + services)
│       └── main.yml               ← Global settings
│   ├── nginx_internal/
│   │   ├── oauth2_vars.yml        ← UPDATE: oauth2_proxy_host
│   │   └── proxy_vars_enhanced.yml ← UPDATE: backend_host entries
│   ├── opnsense/
│   │   └── vars.yml               ← UPDATE: opnsense_aliases
│   └── reverse_proxies/
│       └── mqtt.yml               ← UPDATE: mqtt_backend_host
├── inventories/
│   ├── manual/host_vars/
│   │   ├── ansible.localdomain.yml
│   │   ├── crowdsec.localdomain.yml
│   │   ├── cupsserver.localdomain.yml
│   │   ├── docker-internal.localdomain.yml
│   │   ├── docker-secure.localdomain.yml
│   │   ├── docker.yml
│   │   ├── linuxgameserver.localdomain.yml
│   │   ├── nginx-internal.localdomain.yml
│   │   ├── nginx.yml
│   │   ├── prusa3dbawkz.localdomain.yml
│   │   └── raspberrypi-ha.localdomain.yml
│   └── prod/host_vars/
│       ├── dns02.yml
│       ├── gitea/firewall.yml
│       └── packer_builder.yml
├── roles/
│   └── technitium_dns_sync/       ← DNS sync role
└── sync_dns.yml                   ← DNS sync playbook
```

---

## Appendix: Complete Replacement Commands

For automated replacement (use with caution, review changes before committing):

```bash
# Replace semaphore IP in firewall rules
find ansible/inventories -name "*.yml" -exec \
  sed -i '' 's/"10\.37\.70\.25\/32"  # semaphore/"{{ services.semaphore.ip }}\/32"  # semaphore/g' {} \;

# Replace ansible controller IP
find ansible/inventories -name "*.yml" -exec \
  sed -i '' 's/"10\.37\.70\.27\/32"  # ansible/"{{ hosts.ansible_controller.ip }}\/32"  # ansible/g' {} \;

# Replace veeam IP
find ansible/inventories -name "*.yml" -exec \
  sed -i '' 's/"10\.37\.70\.21\/32"/"{{ hosts.veeam.ip }}\/32"/g' {} \;
```

**Always review with `git diff` before committing.**

---

**Document End**

*This document is self-contained and provides all context needed to implement the hosts/services registry migration.*
