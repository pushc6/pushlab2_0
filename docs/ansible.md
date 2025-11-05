# Ansible: Configure Gitea

The `ansible/roles/gitea` role installs and configures Gitea, and can optionally set up a Docker-based Gitea Actions runner.

What it does
- Installs Gitea binary to `/usr/local/bin/gitea`
- Creates and manages the `gitea` systemd service
- Renders `/etc/gitea/app.ini` with sane defaults (internal SSH on port 2222)
- Opens firewall rules for ports 3000 (HTTP) and 2222 (SSH)
- Creates an admin user if not present
- (Optional) Installs `gitea/act_runner` in Docker and registers it
- Supports upgrades to a specified version; backups enabled by default

Key variables (defaults)
- `gitea_version: "1.24.6"`
- `gitea_backup_before_upgrade: true`
- `gitea_backup_dir: /var/backups`
- `gitea_backup_include: [/etc/gitea, /var/lib/gitea]`

Secrets (host_vars)
- `gitea_admin_username`, `gitea_admin_password`, `gitea_admin_email`
- Optional: `gitea_runner_registration_token`

Run locally
```sh
ANSIBLE_HOST_KEY_CHECKING=False \
  ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/site.yml
```

Upgrade behavior
- Detects installed version via `gitea --version`
- If different from `gitea_version`, stops service, backs up config/data, replaces binary, restarts, and waits for HTTP readiness
