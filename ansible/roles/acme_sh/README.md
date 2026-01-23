# acme_sh Role

Manages SSL/TLS certificates using [acme.sh](https://github.com/acmesh-official/acme.sh) with Cloudflare DNS validation.

## Features

- Installs acme.sh if not present
- Configures Cloudflare DNS API credentials
- Issues wildcard certificates via DNS-01 challenge
- Deploys certificates to nginx ssl directory
- Generates dhparams for each domain
- Auto-renewal via cron (managed by acme.sh)

## Requirements

- Cloudflare account with API token
- Domain DNS managed by Cloudflare

## Role Variables

### Required (in group_vars or via environment)

```yaml
# Cloudflare API credentials
acme_cf_token: "your-cloudflare-api-token"
acme_cf_account_id: "your-cloudflare-account-id"

# Certificates to manage
acme_certificates:
  - domain: "example.com"
    wildcard: true           # Issue *.example.com
    key_length: "ec-256"     # Options: 2048, 4096, ec-256, ec-384
```

### Optional (with defaults)

```yaml
acme_email: ""                                    # Account email for notifications
acme_default_ca: "https://acme-v02.api.letsencrypt.org/directory"
acme_default_key_length: "ec-256"
acme_auto_upgrade: true
acme_cert_deploy_dir: "/etc/nginx/ssl"
acme_reload_cmd: "systemctl reload nginx"
acme_generate_dhparams: true
acme_dhparams_bits: 2048
```

## Providing Credentials

### Option 1: Environment Variables (Semaphore)

Set these in Semaphore as environment variables:
- `ACME_CF_TOKEN`
- `ACME_CF_ACCOUNT_ID`

The role looks up environment variables automatically.

### Option 2: Ansible Vault

Create encrypted group_vars:

```bash
ansible-vault create group_vars/reverse_proxies/vault.yml
```

```yaml
vault_acme_cf_token: "your-token"
vault_acme_cf_account_id: "your-account-id"
```

## Example Playbook

```yaml
- hosts: reverse_proxies
  become: true
  roles:
    - acme_sh
```

## Certificate Deployment

Certificates are deployed to:
```
/etc/nginx/ssl/<domain>/
├── <domain>.cer           # Certificate only
├── <domain>.fullchain.cer # Full chain (cert + intermediates)
├── <domain>.key           # Private key
└── dhparams.pem           # DH parameters
```

## Renewal

acme.sh installs a cron job that runs daily and renews certificates automatically when they're within 30 days of expiration. The `--reloadcmd` ensures nginx is reloaded after renewal.

## License

MIT
