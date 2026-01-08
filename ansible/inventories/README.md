# Ansible Inventories

This directory contains multiple Ansible inventory environments:

- `prod/` - Production infrastructure (Terraform-managed VMs)
- `manual/` - Manually managed hosts (Docker hosts, VPS, etc.)
- `lab/` - Lab/test environment
- `opnsense/` - OPNsense firewall configuration

## Directory Structure

```
inventories/
├── host_vars/           # Symlinks to all host_vars (auto-generated)
├── group_vars/          # Symlinks to all group_vars (auto-generated)
├── manual/
│   ├── on_premise.yml
│   ├── vps.yml
│   ├── host_vars/
│   │   └── docker-internal.localdomain.yml
│   └── group_vars/
│       └── all.yml -> ../../../group_vars/all.yml
├── prod/
│   ├── hosts.yml
│   ├── host_vars/
│   └── group_vars/
└── ...
```

## Important: Symlinked host_vars/group_vars

The `host_vars/` and `group_vars/` directories at the root of `inventories/` contain **symlinks** to the actual files in subdirectories.

### Why?

When using a directory as an Ansible inventory (e.g., `-i inventories/`), Ansible looks for `host_vars` and `group_vars` **relative to that directory**, not relative to each inventory file within it.

This means:
- Ansible looks for: `inventories/host_vars/<hostname>.yml`
- But files are actually at: `inventories/manual/host_vars/<hostname>.yml`

This is a known limitation when using directory-based inventories with subdirectories. See:
- [Semaphore Issue #376](https://github.com/semaphoreui/semaphore/issues/376)
- [Semaphore Issue #3356](https://github.com/semaphoreui/semaphore/issues/3356)

### Automatic Synchronization

A **pre-commit hook** automatically creates and maintains these symlinks:

```bash
# The hook runs automatically on commit, but you can run it manually:
./scripts/sync-inventory-symlinks.sh
```

The hook:
1. Scans all subdirectories for `host_vars/` and `group_vars/`
2. Creates relative symlinks in `inventories/host_vars/` and `inventories/group_vars/`
3. Removes broken symlinks
4. Stages the changes if any were made

### Adding New host_vars

When you add a new `host_vars` file:

1. Create the file in the appropriate subdirectory:
   ```bash
   # For manually managed hosts:
   vim ansible/inventories/manual/host_vars/new-host.localdomain.yml

   # For prod hosts:
   vim ansible/inventories/prod/host_vars/new-host.yml
   ```

2. Commit - the pre-commit hook will automatically create the symlink:
   ```bash
   git add ansible/inventories/manual/host_vars/new-host.localdomain.yml
   git commit -m "Add host_vars for new-host"
   # Hook runs, creates symlink, you may need to commit again
   ```

3. Or run the sync script manually:
   ```bash
   ./scripts/sync-inventory-symlinks.sh
   git add -A
   git commit -m "Add host_vars for new-host"
   ```

## Using with Semaphore

In Semaphore UI, configure your inventory as:
- **Type:** File
- **Path:** `ansible/inventories`
- **Repository:** (leave empty to use same repo as template)

This allows Semaphore to use the directory inventory with all subdirectories, and the symlinks ensure `host_vars` are found correctly.
