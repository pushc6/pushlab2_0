# Prerequisites

You'll need the following access and tools before starting.

## Access Required

| Resource | Purpose |
|----------|---------|
| vSphere | vCenter host/IP with permissions to create templates/VMs |
| S3-compatible store | Backblaze B2 or similar for Terraform state |
| Semaphore | (Optional) For CI to trigger Ansible |

## Local Tools

Optional if you rely solely on CI:

| Tool | Version | Purpose |
|------|---------|---------|
| Packer | 1.11.x | Build VM templates |
| Terraform | 1.7.x | Provision infrastructure |
| Ansible Core | 2.15+ | Configuration management |

> This repo is developed/tested on macOS with zsh.

## CI Secrets

Configure in Gitea → Repository Settings → Secrets:

| Secret | Required | Purpose |
|--------|----------|---------|
| `VSPHERE_USER` | Yes | vCenter username |
| `VSPHERE_PASSWORD` | Yes | vCenter password |
| `VCENTER_SERVER` | Yes | Host or IP only (no scheme or /sdk) |
| `AWS_ACCESS_KEY_ID` | Yes | S3 backend credentials |
| `AWS_SECRET_ACCESS_KEY` | Yes | S3 backend credentials |
| `AWS_SESSION_TOKEN` | No | S3 backend (if using STS) |
| `SSH_PRIVATE_KEY` | No | For Terraform/Ansible SSH access |
| `SEMAPHORE_URL` | No | Enables Semaphore trigger |
| `SEMAPHORE_TOKEN` | No | Semaphore API token |
| `SEMAPHORE_PROJECT_ID` | No | Semaphore project ID |

See [Secrets Setup](setup-secrets.md) for detailed configuration.

## Local-only Backend Secrets

For local Terraform runs, create:
- `terraform/envs/*/backend.s3.secrets.hcl` (from `.example` template)

These files are gitignored. CI uses AWS_* environment variables instead.

---

**Ready to start?** Continue to [Bootstrapping](bootstrapping.md).
