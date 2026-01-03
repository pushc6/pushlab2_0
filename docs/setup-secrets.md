# Secrets and Configuration

This project supports local and CI execution. CI uses repository Secrets; local runs can use example files checked into the repo.

## vSphere Credentials

| Secret | Example | Notes |
|--------|---------|-------|
| `VCENTER_SERVER` | `10.37.10.35` | Hostname or IP only (no http/https, no paths) |
| `VSPHERE_USER` | `administrator@vsphere.local` | vCenter username |
| `VSPHERE_PASSWORD` | - | vCenter password |

## Terraform Remote State (S3-compatible)

For Backblaze B2 or other S3-compatible backends:

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | B2 Application Key ID |
| `AWS_SECRET_ACCESS_KEY` | B2 Application Key |
| `AWS_SESSION_TOKEN` | (Optional) If using STS |

**Region:** `us-east-005` for Backblaze B2

**How it works:**
- **CI:** Terraform init reads backend config from `backend.hcl` and uses AWS_* env vars
- **Local:** Create `backend.s3.secrets.hcl` from the `.example` file; CI ignores it

## Semaphore (Optional)

For automated Ansible triggering from CI:

| Secret | Example | Purpose |
|--------|---------|---------|
| `SEMAPHORE_URL` | `https://semaphore.example.com` | Semaphore server URL |
| `SEMAPHORE_TOKEN` | - | API token for authentication |
| `SEMAPHORE_PROJECT_ID` | `1` | Project ID to trigger tasks |
| `SEMAPHORE_TEMPLATE_ID` | `5` | Task template ID |

See [CI/CD docs](ci-cd.md) for workflow configuration.

## Gitea App Configuration (Ansible)

Store in Ansible inventory `host_vars/<hostname>/secrets.yml`:

```yaml
gitea_admin_username: "admin"
gitea_admin_password: "secure-password"
gitea_admin_email: "admin@example.com"

# Optional: register a Gitea Actions runner
gitea_runner_registration_token: "token-from-gitea-ui"
```

See [Ansible docs](ansible.md) for role configuration.

## Local-only Files

These files are gitignored and used only for local development:

| File | Purpose |
|------|---------|
| `terraform/envs/*/backend.s3.secrets.hcl` | Local state backend credentials |
| `ansible/inventories/*/host_vars/<host>/secrets.yml` | Application secrets |

Create from `.example` templates where provided.

---

**Next:** Follow the [Bootstrapping guide](bootstrapping.md) to deploy.
