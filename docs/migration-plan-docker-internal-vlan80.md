# Migration Plan: docker-internal to VLAN 80

**Document Version:** 1.0
**Date:** 2026-01-26
**Target:** Move docker-internal from VLAN 70 (10.37.70.25) to VLAN 80 (10.37.80.6)
**Secondary Goal:** Transition from IP-based to DNS-based service references

---

## Executive Summary

This migration moves docker-internal from the DMZ VLAN (70) to the App/Servers VLAN (80). The host runs 15 critical containers including Semaphore (Ansible automation), Grafana, VictoriaMetrics, OAuth2-Proxy, Immich, and MQTT broker. The migration requires coordinated updates across:

- **26 files** containing hardcoded IP references to 10.37.70.25
- **OPNsense firewall** aliases and cross-VLAN rules
- **Technitium DNS** records
- **NFS mount configurations** (storage paths remain unchanged)
- **Firewall rules** on docker-internal itself (new VLAN subnet sources)

**Estimated Downtime:** 5-15 minutes (network cutover window)

---

## Table of Contents

1. [Pre-Migration Requirements](#1-pre-migration-requirements)
2. [Dependency Map](#2-dependency-map)
3. [DNS Strategy](#3-dns-strategy)
4. [Migration Phases](#4-migration-phases)
5. [Rollback Plan](#5-rollback-plan)
6. [Post-Migration Validation](#6-post-migration-validation)
7. [File Change Reference](#7-file-change-reference)

**Appendices:**
- [A: Hosts Registry - Single Source of Truth](#appendix-a-hosts-registry---single-source-of-truth-implemented)
- [B: Technitium DNS Sync Role](#appendix-b-technitium-dns-sync-role-implemented)
- [C: Migration with Hosts Registry](#appendix-c-migration-with-hosts-registry)
- [D: Quick Command Reference](#appendix-d-quick-command-reference)
- [E: Files Created/Modified](#appendix-e-files-createdmodified)

---

## 1. Pre-Migration Requirements

### 1.1 DNS Records to Create (Pre-Migration)

Create these A records in Technitium DNS pointing to the **NEW** IP (10.37.80.6) **before** migration:

| Hostname | Current IP | New IP | Purpose |
|----------|-----------|--------|---------|
| `docker-internal.localdomain` | 10.37.70.25 | 10.37.80.6 | Primary host record |
| `semaphore.localdomain` | (via docker-internal) | 10.37.80.6 | Ansible automation UI |
| `grafana.localdomain` | (via docker-internal) | 10.37.80.6 | Monitoring dashboards |
| `victoriametrics.localdomain` | (via docker-internal) | 10.37.80.6 | Metrics database |
| `victorialogs.localdomain` | (via docker-internal) | 10.37.80.6 | Logs database |
| `alloy.localdomain` | (via docker-internal) | 10.37.80.6 | Telemetry collector |
| `influxdb.localdomain` | (via docker-internal) | 10.37.80.6 | Time series DB |
| `mqtt.localdomain` | (via docker-internal) | 10.37.80.6 | MQTT broker |
| `oauth2-proxy.localdomain` | (via docker-internal) | 10.37.80.6 | SSO authentication |
| `immich.localdomain` | (via docker-internal) | 10.37.80.6 | Photo management |
| `peanut.localdomain` | (via docker-internal) | 10.37.80.6 | UPS web UI |
| `crowdsec-api-manager.localdomain` | (via docker-internal) | 10.37.80.6 | CrowdSec API |

### 1.2 Technitium DNS API

Technitium provides an HTTP API for DNS management:
- **API Documentation:** https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md
- **Endpoint:** `http://<dns-server>:5380/api/`
- **Authentication:** Session token required (login first)

**Example API calls:**
```bash
# Login (get token)
curl "http://docker-secure.localdomain:5380/api/user/login?user=admin&pass=<password>&includeInfo=true"

# Add A record
curl "http://docker-secure.localdomain:5380/api/zones/records/add?token=<token>&domain=docker-internal.localdomain&zone=localdomain&type=A&ipAddress=10.37.80.6&ttl=3600"

# Update existing record
curl "http://docker-secure.localdomain:5380/api/zones/records/update?token=<token>&domain=docker-internal.localdomain&zone=localdomain&type=A&ipAddress=10.37.70.25&newIpAddress=10.37.80.6"
```

### 1.3 Pre-Flight Checklist

- [ ] Backup all Ansible configuration files
- [ ] Export OPNsense configuration
- [ ] Verify 10.37.80.6 is unassigned and available
- [ ] Verify NFS mounts (TrueNAS/Synology) are accessible from VLAN 80
- [ ] Test DNS resolution from VLAN 80 subnet
- [ ] Notify users of maintenance window
- [ ] Ensure console/IPMI access to docker-internal (in case SSH breaks)

---

## 2. Dependency Map

### 2.1 Services Hosted on docker-internal

| Service | Port | Consumers | Impact Level |
|---------|------|-----------|--------------|
| **Semaphore** | 3000, 3004 | nginx-internal, nginx-dmz, users | **CRITICAL** - Ansible automation |
| **OAuth2-Proxy** | 4180 | nginx-internal, nginx-dmz | **CRITICAL** - SSO for all apps |
| **Grafana** | 3002 | nginx-internal, users | HIGH - Monitoring |
| **VictoriaMetrics** | 8428, 8089, 4242, 2003 | All hosts sending metrics | HIGH - Metrics storage |
| **VictoriaLogs** | 9428 | All hosts sending logs | HIGH - Log storage |
| **Alloy** | 1514, 12345 | All hosts (syslog/OTLP) | HIGH - Telemetry collector |
| **InfluxDB** | 8086 | Various services | MEDIUM |
| **Mosquitto MQTT** | 1883 | nginx proxies, IoT devices | MEDIUM |
| **Immich** | 2283 | nginx-internal, users | MEDIUM |
| **NUT** | 3493 | UPS clients | LOW |
| **PeaNUT** | 8080 | nginx-internal | LOW |
| **CrowdSec API Manager** | 5000 | CrowdSec agents | LOW |

### 2.2 Storage Dependencies (NFS Mounts)

```
10.37.20.4:/volume1/digx    → /var/digx           (Synology - VLAN 20)
10.37.70.22:/mnt/tank/DockerInternal → /var/dockerstorage (TrueNAS - VLAN 70)
```

**Action Required:** Verify TrueNAS NFS export allows 10.37.80.0/24 clients.

### 2.3 Hosts Referencing docker-internal IP

| Host | Purpose of Reference |
|------|---------------------|
| ansible.localdomain | SSH from semaphore |
| docker.yml | SSH from semaphore |
| nginx-internal.localdomain | SSH from semaphore |
| linuxgameserver.localdomain | SSH from semaphore |
| docker-secure.localdomain | SSH from semaphore |
| prusa3dbawkz.localdomain | SSH from semaphore |
| crowdsec.localdomain | SSH from semaphore |
| nginx.yml (nginx-dmz) | SSH from semaphore |
| raspberrypi-ha.localdomain | SSH from semaphore |
| cupsserver.localdomain | SSH from semaphore |
| packer_builder.yml | SSH from semaphore |
| dns02.yml | SSH from semaphore |
| gitea/firewall.yml | SSH from semaphore |
| nginx-internal (proxy) | Backend for grafana, semaphore, oauth2, mqtt |
| OPNsense | Firewall alias "semaphore" |

---

## 3. DNS Strategy

### 3.1 DNS-First Migration Approach

**Goal:** After migration, all services should reference DNS names instead of IPs.

**Phase 1 (Pre-Migration):**
- Create all DNS A records pointing to NEW IP (10.37.80.6)
- Keep TTL low (300 seconds) during migration

**Phase 2 (Migration):**
- Update Ansible files to use DNS hostnames
- Update OPNsense alias to use DNS hostname (if supported) or new IP

**Phase 3 (Post-Migration):**
- Verify all services use DNS names
- Increase TTL to 3600 seconds
- Document canonical hostnames

### 3.2 Hostname Conventions

| Service | Canonical DNS Name | Notes |
|---------|-------------------|-------|
| Host | `docker-internal.localdomain` | Primary A record |
| Semaphore | `semaphore.localdomain` | CNAME → docker-internal.localdomain |
| Grafana | `grafana.localdomain` | CNAME → docker-internal.localdomain |
| OAuth2-Proxy | `oauth2-proxy.localdomain` | CNAME → docker-internal.localdomain |
| VictoriaMetrics | `victoriametrics.localdomain` | CNAME → docker-internal.localdomain |
| VictoriaLogs | `victorialogs.localdomain` | CNAME → docker-internal.localdomain |
| Alloy | `alloy.localdomain` | CNAME → docker-internal.localdomain |
| MQTT | `mqtt.localdomain` | CNAME → docker-internal.localdomain |
| InfluxDB | `influxdb.localdomain` | CNAME → docker-internal.localdomain |
| Immich | `immich.localdomain` | CNAME → docker-internal.localdomain |

**Recommendation:** Use CNAME records pointing to `docker-internal.localdomain` so future IP changes only require updating one A record.

---

## 4. Migration Phases

### Phase 0: Preparation (No Downtime)

**Duration:** Can be done days ahead

#### 0.1 Create DNS Records

Using Technitium API or web UI, create:

```
docker-internal.localdomain  A      10.37.80.6   TTL=300
semaphore.localdomain        CNAME  docker-internal.localdomain
grafana.localdomain          CNAME  docker-internal.localdomain
oauth2-proxy.localdomain     CNAME  docker-internal.localdomain
victoriametrics.localdomain  CNAME  docker-internal.localdomain
victorialogs.localdomain     CNAME  docker-internal.localdomain
alloy.localdomain            CNAME  docker-internal.localdomain
mqtt.localdomain             CNAME  docker-internal.localdomain
influxdb.localdomain         CNAME  docker-internal.localdomain
immich.localdomain           CNAME  docker-internal.localdomain
peanut.localdomain           CNAME  docker-internal.localdomain
```

**Note:** DNS currently resolves `docker-internal.localdomain` to 10.37.70.25. You'll update this during the cutover.

#### 0.2 Verify TrueNAS NFS Access

On TrueNAS, ensure the NFS export for `/mnt/tank/DockerInternal` allows:
- Current: 10.37.70.25
- Add: 10.37.80.6 (or 10.37.80.0/24)

#### 0.3 Prepare OPNsense Firewall Rules

Plan new rules to allow traffic from VLAN 80 to services that previously only allowed VLAN 70.

**Current firewall rules in OPNsense (`group_vars/opnsense/vars.yml`):**
```yaml
opnsense_aliases:
  - name: "semaphore"
    type: host
    content:
      - "10.37.70.25"  # Change to 10.37.80.6 or DNS
```

Cross-VLAN rules that use "semaphore" source:
- semaphore → gitea:22 (SSH)
- semaphore → packer-builder:22 (SSH)
- semaphore → dns02:22 (SSH)
- semaphore → raspberrypi-ha:22 (SSH)
- semaphore → cupsserver:22 (SSH)

#### 0.4 Prepare Ansible Configuration Updates

Stage all file changes (see Section 7) but do not commit yet.

---

### Phase 1: Network Cutover (DOWNTIME BEGINS)

**Duration:** 5-15 minutes

#### 1.1 Stop Critical Services

SSH to docker-internal and stop containers to prevent data corruption:
```bash
ssh push@docker-internal.localdomain
sudo docker stop semaphore grafana victoriametrics victorialogs alloy influxdb oauth2-proxy immich mosquitto
```

#### 1.2 Change IP Address

Edit `/etc/netplan/` or `/etc/sysconfig/network-scripts/` (depending on OS):

**For AlmaLinux/RHEL (nmcli):**
```bash
# Identify the connection
nmcli con show

# Modify the connection
sudo nmcli con mod "ens192" ipv4.addresses "10.37.80.6/24"
sudo nmcli con mod "ens192" ipv4.gateway "10.37.80.1"
sudo nmcli con mod "ens192" ipv4.dns "10.37.70.6"  # docker-secure DNS

# Apply changes
sudo nmcli con down "ens192" && sudo nmcli con up "ens192"
```

**Warning:** You will lose SSH connection. Reconnect via new IP or console.

#### 1.3 Update DNS A Record

Change `docker-internal.localdomain` A record from 10.37.70.25 to 10.37.80.6:

```bash
# Via Technitium API
curl "http://docker-secure.localdomain:5380/api/zones/records/update?token=<token>&domain=docker-internal.localdomain&zone=localdomain&type=A&ipAddress=10.37.70.25&newIpAddress=10.37.80.6"
```

#### 1.4 Verify NFS Mounts

```bash
ssh push@10.37.80.6
sudo mount -a
df -h | grep nfs
# Verify both mounts are working
```

#### 1.5 Start Containers

```bash
sudo docker start semaphore grafana victoriametrics victorialogs alloy influxdb oauth2-proxy immich mosquitto
sudo docker ps  # Verify all running
```

#### 1.6 Update OPNsense Alias

Update the `semaphore` alias to new IP:
- OPNsense Web UI: Firewall → Aliases → Edit "semaphore"
- Change content from `10.37.70.25` to `10.37.80.6`
- Apply changes

Or via Ansible (after updating `group_vars/opnsense/vars.yml`).

**DOWNTIME ENDS** - Services should now be reachable at new IP.

---

### Phase 2: Configuration Updates (No Downtime)

#### 2.1 Update Ansible Firewall Rules (IP → DNS)

Update all `firewall_ssh_allowed_subnets` entries from `10.37.70.25/32` to use DNS:

**Problem:** Firewalld rich rules don't support DNS names directly.

**Solutions:**
1. **Option A (Recommended):** Update to new IP `10.37.80.6/32`
2. **Option B:** Create a script/role that resolves DNS to IP at runtime
3. **Option C:** Use subnet `10.37.80.0/24` (less precise but future-proof)

**Files to update (13 files):**
```
ansible/inventories/manual/host_vars/ansible.localdomain.yml
ansible/inventories/manual/host_vars/docker.yml
ansible/inventories/manual/host_vars/nginx-internal.localdomain.yml
ansible/inventories/manual/host_vars/linuxgameserver.localdomain.yml
ansible/inventories/manual/host_vars/docker-secure.localdomain.yml
ansible/inventories/manual/host_vars/prusa3dbawkz.localdomain.yml
ansible/inventories/manual/host_vars/crowdsec.localdomain.yml
ansible/inventories/manual/host_vars/nginx.yml
ansible/inventories/manual/host_vars/raspberrypi-ha.localdomain.yml
ansible/inventories/manual/host_vars/cupsserver.localdomain.yml
ansible/inventories/prod/host_vars/packer_builder.yml
ansible/inventories/prod/host_vars/dns02.yml
ansible/inventories/prod/host_vars/gitea/firewall.yml
```

**Change pattern:**
```yaml
# Before
firewall_ssh_allowed_subnets:
  - "10.37.70.25/32"  # semaphore

# After (Option A - IP update)
firewall_ssh_allowed_subnets:
  - "10.37.80.6/32"   # semaphore (docker-internal)
```

#### 2.2 Update Nginx Proxy Backends (IP → DNS)

**File:** `ansible/group_vars/nginx_internal/proxy_vars_enhanced.yml`

```yaml
# Before
oauth2_proxy_host: "10.37.70.25"

# Services with backend_host: "10.37.70.25"
#   - grafana
#   - semaphore

# After (DNS-based)
oauth2_proxy_host: "docker-internal.localdomain"

# Update each service block
- name: grafana
  backend_host: "docker-internal.localdomain"  # Was 10.37.70.25

- name: semaphore
  backend_host: "docker-internal.localdomain"  # Was 10.37.70.25
```

**File:** `ansible/group_vars/nginx_internal/oauth2_vars.yml`
```yaml
# Before
oauth2_proxy_host: "10.37.70.25"

# After
oauth2_proxy_host: "docker-internal.localdomain"
```

**File:** `ansible/group_vars/reverse_proxies/mqtt.yml`
```yaml
# Before
mqtt_backend_host: "10.37.70.25"

# After
mqtt_backend_host: "docker-internal.localdomain"
```

#### 2.3 Update OPNsense Ansible Config

**File:** `ansible/group_vars/opnsense/vars.yml`

```yaml
# Before
opnsense_aliases:
  - name: "semaphore"
    type: host
    content:
      - "10.37.70.25"
    description: "Semaphore Ansible UI server"

# After
opnsense_aliases:
  - name: "semaphore"
    type: host
    content:
      - "10.37.80.6"
    description: "Semaphore Ansible UI server (docker-internal)"
```

#### 2.4 Update docker-internal Host Vars

**File:** `ansible/inventories/manual/host_vars/docker-internal.localdomain.yml`

Update the firewall sources to reflect new VLAN membership:

```yaml
# Update comment at top
# Firewall configuration for docker-internal.localdomain (10.37.80.6)

# Review each firewall_services entry
# Sources referencing 10.37.70.0/24 may need updates if the service
# should be accessible from the old DMZ VLAN

# Example: VictoriaMetrics - add VLAN 70 to sources since docker-internal
# is no longer on that VLAN
- port: 8428
  sources:
    - "10.37.20.0/24"   # trusted_vlan
    - "10.37.70.0/24"   # DMZ (now external to this host)
    - "10.37.80.0/24"   # servers_vlan (local)
```

#### 2.5 Update Ansible Inventory

**File:** `ansible/inventories/manual/on_premise.yml`

```yaml
# Before
docker_internal:
  hosts:
    docker-internal.localdomain:
      ansible_host: 10.37.70.25

# After (use DNS)
docker_internal:
  hosts:
    docker-internal.localdomain:
      ansible_host: docker-internal.localdomain
      # Or: ansible_host: 10.37.80.6
```

---

### Phase 3: Apply Configuration Changes

#### 3.1 Run Ansible Playbooks

```bash
# Apply firewall rules to all hosts
ANSIBLE_HOST_KEY_CHECKING=False \
  ansible-playbook -i ansible/inventories/manual/on_premise.yml \
  ansible/site.yml --tags firewall

# Apply OPNsense changes
ANSIBLE_HOST_KEY_CHECKING=False \
  ansible-playbook -i ansible/inventories/opnsense/hosts.yml \
  ansible/opnsense.yml

# Apply nginx proxy changes
ANSIBLE_HOST_KEY_CHECKING=False \
  ansible-playbook -i ansible/inventories/manual/on_premise.yml \
  ansible/site.yml --tags nginx
```

#### 3.2 Verify Semaphore Connectivity

Test that Semaphore can still SSH to managed hosts:
1. Log into Semaphore UI
2. Run a test playbook against each managed host
3. Verify all hosts are reachable

---

### Phase 4: Cleanup

#### 4.1 Remove Old DNS Records

If you created temporary records, clean them up.

#### 4.2 Increase DNS TTL

Change TTL from 300 to 3600 for `docker-internal.localdomain`.

#### 4.3 Update Documentation

- Update network diagrams
- Update any hardcoded references in documentation

#### 4.4 Commit Ansible Changes

```bash
cd /path/to/tf_generate_alma
git add -A
git commit -m "Migrate docker-internal from VLAN 70 to VLAN 80

- Update IP from 10.37.70.25 to 10.37.80.6
- Convert hardcoded IPs to DNS hostnames where possible
- Update OPNsense alias
- Update firewall rules on all managed hosts"
```

---

## 5. Rollback Plan

### If Migration Fails (During Phase 1)

1. **Revert IP address on docker-internal:**
   ```bash
   sudo nmcli con mod "ens192" ipv4.addresses "10.37.70.25/24"
   sudo nmcli con mod "ens192" ipv4.gateway "10.37.70.1"
   sudo nmcli con down "ens192" && sudo nmcli con up "ens192"
   ```

2. **Revert DNS record:**
   Change `docker-internal.localdomain` back to 10.37.70.25

3. **Revert OPNsense alias:**
   Change "semaphore" alias back to 10.37.70.25

4. **Start containers:**
   ```bash
   sudo docker start semaphore grafana victoriametrics victorialogs alloy influxdb oauth2-proxy immich mosquitto
   ```

### If Issues Discovered Post-Migration

1. Do NOT revert without assessment
2. Check specific failing service
3. Verify firewall rules on both ends
4. Check DNS resolution from affected host
5. Rollback only if critical services are down

---

## 6. Post-Migration Validation

### 6.1 Connectivity Tests

```bash
# From trusted_vlan client
ping docker-internal.localdomain
curl -I http://docker-internal.localdomain:3002  # Grafana
curl -I http://docker-internal.localdomain:3004  # Semaphore

# From nginx-internal
ssh push@nginx-internal.localdomain
curl -I http://docker-internal.localdomain:4180  # OAuth2-Proxy

# From any host sending metrics
curl -X POST http://docker-internal.localdomain:8428/api/v1/write
```

### 6.2 Service Health Checks

| Service | Test Command | Expected Result |
|---------|--------------|-----------------|
| Semaphore | `curl http://10.37.80.6:3004/api/ping` | 200 OK |
| Grafana | `curl http://10.37.80.6:3002/api/health` | 200 OK |
| VictoriaMetrics | `curl http://10.37.80.6:8428/-/healthy` | 200 OK |
| OAuth2-Proxy | `curl http://10.37.80.6:4180/ping` | 200 OK |
| MQTT | `mosquitto_pub -h 10.37.80.6 -t test -m "ping"` | No error |

### 6.3 Semaphore Job Test

1. Log into Semaphore
2. Create test job targeting any managed host
3. Verify SSH connectivity works
4. Verify job completes successfully

### 6.4 Monitoring Verification

1. Check Grafana dashboards are receiving data
2. Verify VictoriaMetrics has recent data points
3. Check Alloy is receiving logs from all hosts

---

## 7. File Change Reference

### Files Requiring IP Update (10.37.70.25 → 10.37.80.6)

| File | Line(s) | Change Type |
|------|---------|-------------|
| `ansible/inventories/manual/host_vars/ansible.localdomain.yml` | 10 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/docker.yml` | 50 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/nginx-internal.localdomain.yml` | 53 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/linuxgameserver.localdomain.yml` | 10 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/docker-secure.localdomain.yml` | 10 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/prusa3dbawkz.localdomain.yml` | 11 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/crowdsec.localdomain.yml` | 22 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/nginx.yml` | 52 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/raspberrypi-ha.localdomain.yml` | 12 | SSH allowed subnet |
| `ansible/inventories/manual/host_vars/cupsserver.localdomain.yml` | 10 | SSH allowed subnet |
| `ansible/inventories/prod/host_vars/packer_builder.yml` | 9 | SSH allowed subnet |
| `ansible/inventories/prod/host_vars/dns02.yml` | 9 | SSH allowed subnet |
| `ansible/inventories/prod/host_vars/gitea/firewall.yml` | 9 | SSH allowed subnet |
| `ansible/group_vars/opnsense/vars.yml` | 63 | OPNsense alias |
| `ansible/group_vars/nginx_internal/oauth2_vars.yml` | 6 | Proxy backend |
| `ansible/group_vars/nginx_internal/proxy_vars_enhanced.yml` | 18, 139, 155 | Proxy backends |
| `ansible/group_vars/reverse_proxies/mqtt.yml` | 6 | MQTT backend |
| `ansible/inventories/manual/host_vars/docker-internal.localdomain.yml` | 2 | Comment |
| `ansible/deploy_mqtt_proxy.yml` | 10 | Comment |

### Files to Convert to DNS (IP → Hostname)

| File | Current | New Value |
|------|---------|-----------|
| `group_vars/nginx_internal/proxy_vars_enhanced.yml` | `10.37.70.25` | `docker-internal.localdomain` |
| `group_vars/nginx_internal/oauth2_vars.yml` | `10.37.70.25` | `docker-internal.localdomain` |
| `group_vars/reverse_proxies/mqtt.yml` | `10.37.70.25` | `docker-internal.localdomain` |

### Firewall Rules That Cannot Use DNS

The following must use IP addresses (firewalld limitation):

- All `firewall_ssh_allowed_subnets` entries → use `10.37.80.6/32`
- OPNsense alias → use `10.37.80.6` (or hostname if supported in your version)

---

## Appendix A: Hosts Registry - Single Source of Truth (IMPLEMENTED)

A hosts registry has been created at `ansible/group_vars/all/hosts_registry.yml` that serves as the single source of truth for all host IPs. This enables:

1. **One place to change IPs** - Update the registry, propagate everywhere
2. **Automatic DNS sync** - Technitium records created from registry
3. **Consistent firewall rules** - Reference `{{ hosts.docker_internal.ip }}`

### File Structure

```
ansible/group_vars/all/
├── main.yml              # Original global vars (renamed from all.yml)
└── hosts_registry.yml    # NEW: Hosts registry with all IPs and services
```

### Usage Examples

**In firewall configs:**
```yaml
# Before (hardcoded IP)
firewall_ssh_allowed_subnets:
  - "10.37.70.25/32"  # semaphore

# After (registry variable)
firewall_ssh_allowed_subnets:
  - "{{ hosts.docker_internal.ip }}/32"  # semaphore
```

**In nginx proxy configs:**
```yaml
# Before
oauth2_proxy_host: "10.37.70.25"

# After (can use hostname since nginx supports DNS)
oauth2_proxy_host: "{{ hosts.docker_internal.hostname }}"
```

**In OPNsense alias:**
```yaml
opnsense_aliases:
  - name: "semaphore"
    type: host
    content:
      - "{{ hosts.docker_internal.ip }}"
```

### Registry Structure

```yaml
hosts_vlan80:
  docker_internal:
    hostname: docker-internal.localdomain
    ip: "10.37.80.6"
    description: "Internal Docker host"
    dns_record: true
    aliases:
      - semaphore.localdomain
      - grafana.localdomain
      # ... more CNAME aliases
    services:
      - semaphore
      - grafana
      # ... more services

# Convenience lookup
hosts: "{{ hosts_vlan20 | combine(hosts_vlan70) | combine(hosts_vlan80) | ... }}"
```

---

## Appendix B: Technitium DNS Sync Role (IMPLEMENTED)

A new role `technitium_dns_sync` has been created that uses the `effectivelywild.technitium_dns` Ansible collection to sync DNS records from the hosts registry.

### Prerequisites

```bash
ansible-galaxy collection install effectivelywild.technitium_dns
```

### Create API Token in Technitium

1. Log into Technitium web UI (http://docker-secure.localdomain:5380)
2. Go to Administration → Users
3. Create or edit a user with API access
4. Generate a non-expiring API token
5. Store token in Ansible Vault:

```bash
ansible-vault create ansible/group_vars/all/vault.yml
```

```yaml
# ansible/group_vars/all/vault.yml
vault_technitium_api_token: "your-api-token-here"
```

### Running DNS Sync

```bash
# Dry run - show what would change
ansible-playbook ansible/sync_dns.yml \
  -e "technitium_dns_dry_run=true" \
  -e "technitium_dns_api_token=YOUR_TOKEN"

# Apply changes
ansible-playbook ansible/sync_dns.yml \
  -e "technitium_dns_api_token=YOUR_TOKEN"

# With vault
ansible-playbook ansible/sync_dns.yml --ask-vault-pass
```

### What Gets Synced

The role reads `hosts_registry.yml` and creates:
- **A records** for each host with `dns_record: true`
- **CNAME records** for each alias pointing to the parent hostname

Example output:
```
DNS Sync Complete:
- A records processed: 15
- CNAME aliases processed: 12
```

---

## Appendix C: Migration with Hosts Registry

### Updated Migration Steps

With the hosts registry in place, the migration becomes simpler:

#### Step 1: Update hosts_registry.yml (ALREADY DONE)

The registry already has docker-internal at the new IP:
```yaml
hosts_vlan80:
  docker_internal:
    hostname: docker-internal.localdomain
    ip: "10.37.80.6"  # New VLAN 80 IP
```

#### Step 2: Sync DNS Records

```bash
# After changing the IP in registry, sync to Technitium
ansible-playbook ansible/sync_dns.yml -e "technitium_dns_api_token=YOUR_TOKEN"
```

This creates/updates:
- `docker-internal.localdomain` → 10.37.80.6
- `semaphore.localdomain` → CNAME → docker-internal.localdomain
- `grafana.localdomain` → CNAME → docker-internal.localdomain
- etc.

#### Step 3: Update Firewall Configs to Use Registry

Replace hardcoded IPs with registry references:

```bash
# Find all files with hardcoded 10.37.70.25
grep -r "10.37.70.25" ansible/

# Update each file to use:
# {{ hosts.docker_internal.ip }}/32
```

#### Step 4: Apply Changes

```bash
# Apply firewall changes to all hosts
ansible-playbook -i ansible/inventories/manual/on_premise.yml \
  ansible/site.yml --tags firewall

# Apply OPNsense changes
ansible-playbook -i ansible/inventories/opnsense/hosts.yml \
  ansible/opnsense.yml
```

### Future IP Changes

When docker-internal's IP changes again:

1. Update `hosts_registry.yml` (one line)
2. Run `sync_dns.yml` (DNS updated)
3. Run `site.yml --tags firewall` (firewalls updated)

No more hunting through 26 files.

---

## Appendix D: Quick Command Reference

```bash
# SSH to new IP
ssh push@10.37.80.6

# Check all containers
ssh push@10.37.80.6 "sudo docker ps --format 'table {{.Names}}\t{{.Status}}'"

# Test DNS resolution
dig docker-internal.localdomain @10.37.70.6

# Test from another host
ssh push@nginx-internal.localdomain "curl -s http://docker-internal.localdomain:3002/api/health"

# OPNsense firewall reload (via API)
curl -k -u "user:pass" "https://opnsense.localdomain/api/firewall/filter/apply"

# Sync DNS after registry changes
ansible-playbook ansible/sync_dns.yml -e "technitium_dns_api_token=TOKEN"

# Apply firewall changes after registry update
ansible-playbook -i ansible/inventories/manual/on_premise.yml \
  ansible/site.yml --tags firewall
```

---

## Appendix E: Files Created/Modified

| File | Status | Purpose |
|------|--------|---------|
| `ansible/group_vars/all/hosts_registry.yml` | **NEW** | Single source of truth for all host IPs |
| `ansible/group_vars/all/main.yml` | RENAMED | Was `all.yml`, contains global settings |
| `ansible/roles/technitium_dns_sync/` | **NEW** | Role to sync DNS records from registry |
| `ansible/sync_dns.yml` | **NEW** | Playbook to run DNS sync |
| `docs/migration-plan-docker-internal-vlan80.md` | **NEW** | This migration plan |

---

**Document prepared for:** Migration of docker-internal to VLAN 80
**Author:** Claude Code
**Version:** 1.1 (with hosts registry implementation)
**Review required before execution**
