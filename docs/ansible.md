# Ansible: Configure Applications

Ansible configures the VMs provisioned by [Terraform](terraform.md).

## Gitea Role

The `ansible/roles/gitea` role installs and configures Gitea, and can optionally set up a Docker-based Gitea Actions runner.

### What It Does

- Installs Gitea binary to `/usr/local/bin/gitea`
- Creates and manages the `gitea` systemd service
- Renders `/etc/gitea/app.ini` with sane defaults (internal SSH on port 2222)
- Opens firewall rules for ports 3000 (HTTP) and 2222 (SSH)
- Creates an admin user if not present
- (Optional) Installs `gitea/act_runner` in Docker and registers it
- Supports upgrades to a specified version; backups enabled by default

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `gitea_version` | `1.24.6` | Gitea version to install |
| `gitea_backup_before_upgrade` | `true` | Backup before upgrading |
| `gitea_backup_dir` | `/var/backups` | Backup directory |
| `gitea_backup_include` | `[/etc/gitea, /var/lib/gitea]` | Paths to backup |

### Secrets

Store in `host_vars/<hostname>/secrets.yml`:

```yaml
gitea_admin_username: "admin"
gitea_admin_password: "secure-password"
gitea_admin_email: "admin@example.com"

# Optional: register a Gitea Actions runner
gitea_runner_registration_token: "token-from-gitea-ui"
```

See [Secrets Setup](setup-secrets.md) for more details.

## Running Locally

```sh
ANSIBLE_HOST_KEY_CHECKING=False \
  ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/site.yml
```

## Upgrade Behavior

1. Detects installed version via `gitea --version`
2. If different from `gitea_version`:
   - Stops service
   - Backs up config/data
   - Replaces binary
   - Restarts service
   - Waits for HTTP readiness

## Other Roles

The project includes additional roles for:
- Docker installation
- Firewall hardening
- System updates
- NFS client
- OPNsense firewall management
- Technitium DNS
- OAuth2 proxy/NGINX

See `ansible/roles/` for the full list.

---

**Having issues?** See [Troubleshooting](troubleshooting.md).
