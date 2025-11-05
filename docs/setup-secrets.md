# Secrets and Configuration

This project supports local and CI execution. CI uses repository Secrets; local runs can use example files checked into the repo.

vSphere
- VCENTER_SERVER: Hostname or IP of vCenter (no http/https, no paths). Example: `10.37.10.35`
- VSPHERE_USER / VSPHERE_PASSWORD: vCenter credentials

Terraform Remote State (S3-compatible)
- AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (/ AWS_SESSION_TOKEN): Credentials for B2 (or S3)
- Region: `us-east-005` for Backblaze B2
- In CI: Terraform init reads backend config from `backend.hcl` and uses AWS_* env for credentials
- Locally: create `backend.s3.secrets.hcl` from the example; CI ignores it

Ansible Automation Platform (optional)
- AAP_URL: e.g., `https://aap.example.com`
- AAP_TOKEN: OAuth token or PAT for API
- AAP_JOB_TEMPLATE_ID: The numeric ID to launch via API

Gitea app configuration (Ansible)
- Store in Ansible inventory `host_vars`:
  - `gitea_admin_username`, `gitea_admin_password`, `gitea_admin_email`
  - Optional: `gitea_runner_registration_token` to register a Gitea Actions runner

Local-only files
- `terraform/envs/*/backend.s3.secrets.hcl` (from `.example`) for local state init
- `ansible/inventories/*/host_vars/<host>/secrets.yml` for application secrets (ignored by VCS)
