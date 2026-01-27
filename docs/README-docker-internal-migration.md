# Docker-Internal Migration Documentation Index

**Project:** Migrate docker-internal from VLAN 70 to VLAN 80 + implement hosts/services registry

---

## Document Overview

| Document | Purpose | When to Use |
|----------|---------|-------------|
| [migration-plan-docker-internal-vlan80.md](migration-plan-docker-internal-vlan80.md) | Complete migration plan with phases, rollback, validation | Planning the actual IP/VLAN migration |
| [implementation-guide-hosts-registry-migration.md](implementation-guide-hosts-registry-migration.md) | Step-by-step guide to update all config files | **Use this to tell Claude "do the migration"** |

---

## Files Created

### Configuration Files

| File | Status | Purpose |
|------|--------|---------|
| `ansible/group_vars/all/hosts_registry.yml` | **CREATED** | Single source of truth for hosts and services |
| `ansible/group_vars/all/main.yml` | RENAMED | Was `all.yml` |
| `ansible/roles/technitium_dns_sync/` | **CREATED** | Role to sync DNS from registry |
| `ansible/sync_dns.yml` | **CREATED** | Playbook to run DNS sync |
| `ansible/requirements.yml` | UPDATED | Added technitium_dns collection |

### Documentation

| File | Purpose |
|------|---------|
| `docs/migration-plan-docker-internal-vlan80.md` | Migration plan |
| `docs/implementation-guide-hosts-registry-migration.md` | Implementation guide |
| `docs/README-docker-internal-migration.md` | This index |

---

## Quick Start Commands

### Install Dependencies
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### Test Registry Variables
```bash
ansible-playbook -e @ansible/group_vars/all/hosts_registry.yml \
  -e "technitium_dns_dry_run=true" \
  ansible/sync_dns.yml
```

### Sync DNS Records
```bash
ansible-playbook ansible/sync_dns.yml \
  -e "technitium_dns_api_token=YOUR_TOKEN"
```

---

## How to Tell Claude to Implement

When ready to update all configuration files to use the registry, say:

> "Read `docs/implementation-guide-hosts-registry-migration.md` and implement all the changes described in the 'Files to Update' section."

Or more specifically:

> "Update all hardcoded IP references to use the hosts/services registry as documented in `docs/implementation-guide-hosts-registry-migration.md`"

Claude will:
1. Read the implementation guide
2. Update each file according to the documented changes
3. Validate syntax
4. Provide a summary of changes made

---

## Two-Phase Approach

### Phase 1: Update Configs (No Downtime)
- Update all Ansible files to use registry variables
- Registry still points to OLD IP (10.37.70.25)
- Run playbooks - no actual change since IP is same
- Validates that variable resolution works

### Phase 2: IP Migration (Brief Downtime)
- Update `hosts_registry.yml` with new IP (10.37.80.6)
- Change actual IP on docker-internal host
- Run playbooks to propagate changes
- Sync DNS

This approach lets you validate the registry integration before the actual migration.

---

## Registry Usage Summary

```yaml
# Reference by service (preferred for applications)
"{{ services.semaphore.ip }}/32"      # 10.37.80.6
"{{ services.semaphore.hostname }}"   # docker-internal.localdomain
"{{ services.semaphore.port }}"       # 3004

# Reference by host (for host-level things like NFS, SSH)
"{{ hosts.docker_internal.ip }}/32"   # 10.37.80.6
"{{ hosts.truenas.ip }}"              # 10.37.70.22
```

---

## Current State

- [x] Hosts registry created (`hosts_registry.yml`)
- [x] Services registry created (in `hosts_registry.yml`)
- [x] DNS sync role created (`technitium_dns_sync`)
- [x] DNS sync playbook created (`sync_dns.yml`)
- [x] Migration plan documented
- [x] Implementation guide documented
- [ ] Config files updated to use registry ← **PENDING**
- [ ] DNS sync tested
- [ ] Actual IP migration performed
