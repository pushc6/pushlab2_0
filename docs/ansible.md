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

Sensitive values must be stored in an `ansible-vault`-encrypted file alongside
the host_vars. Pattern:

1. Copy the example into a real file:
   ```sh
   cp ansible/inventories/prod/host_vars/gitea/vault.yml.example \
      ansible/inventories/prod/host_vars/gitea/vault.yml
   ansible-vault encrypt ansible/inventories/prod/host_vars/gitea/vault.yml
   ```
2. Reference the vault vars from a non-vault file (e.g. `host_vars/gitea/main.yml`):
   ```yaml
   gitea_admin_username: "{{ vault_gitea_admin_username }}"
   gitea_admin_password: "{{ vault_gitea_admin_password }}"
   gitea_admin_email:    "{{ vault_gitea_admin_email }}"
   # Optional: register a Gitea Actions runner
   gitea_runner_registration_token: "{{ vault_gitea_runner_registration_token }}"
   ```
3. In Semaphore, register the vault password under the project Key Store
   (Type: *Login With Password*) and select it as the *Vault Key* on the
   playbook template.

The role's create-admin and runner-registration tasks have `no_log: true` so
the password and token are not echoed to logs even after decryption.

See [Secrets Setup](setup-secrets.md) for more details.

## Linting and syntax checks

`ansible-lint` is wired into pre-commit and a dedicated CI workflow
(`.gitea/workflows/ansible-lint.yaml`). Run locally with:

```sh
ansible-lint ansible/
ansible-playbook --syntax-check -i ansible/inventories/prod/hosts.yml ansible/site.yml
```

Configuration lives in `.ansible-lint` at the repo root. The skip_list is
seeded with rules currently violated en masse — trim it as roles get
refactored, do not grow it.

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
- Docker installation and daemon configuration (`docker`, `docker_daemon`)
- Firewall hardening (`firewall_hardened`)
- System updates (`system_updates`, `rhel_updates`, `debian_updates`)
- NFS client
- OPNsense firewall management
- Technitium DNS (`technitium`)
- Reverse proxies: NGINX (`enhanced_proxy_nginx`, `oauth2_proxy_nginx`) and Caddy for the DMZ/ECH migration (`caddy_proxy`)
- ACME certificate issuance (`acme_sh`)
- CrowdSec agent/LAPI (`crowdsec`)
- Tailscale (`tailscale`)
- Komodo Periphery for Docker GitOps (`komodo_periphery`)

See `ansible/roles/` for the full list.

---

**Having issues?** See [Troubleshooting](troubleshooting.md).
