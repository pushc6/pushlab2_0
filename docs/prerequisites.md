# Prerequisites

You’ll need the following access and tools.

Access
- vSphere: vCenter host/IP and credentials with permissions to create templates/VMs
- S3-compatible store (Backblaze B2 or similar) for Terraform state
- Ansible Automation Platform (optional) if you want CI to trigger Ansible

Local tools (optional if you rely solely on CI)
- Packer 1.11.x
- Terraform 1.7.x
- Ansible Core 2.15+
- macOS with zsh (this repo is developed/tested on macOS)

Secrets you’ll need in CI (Gitea → repository settings → Secrets)
- VSPHERE_USER / VSPHERE_PASSWORD
- VCENTER_SERVER (host or IP only; no scheme or /sdk)
- AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (/ AWS_SESSION_TOKEN) for the S3 backend
- SSH_PRIVATE_KEY (for Terraform to connect via SSH, if needed)
- AAP_URL / AAP_TOKEN / AAP_JOB_TEMPLATE_ID (optional; enables the AAP trigger)

Optional local-only backend secrets
- `terraform/envs/*/backend.s3.secrets.hcl` not committed; used locally, while CI uses AWS_* secrets
