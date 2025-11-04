# Terraform envs usage

This folder contains per-environment roots. Each environment can use a remote backend (Terraform Cloud/Enterprise) via a backend file.

## Remote backend (Terraform Cloud/Enterprise)

1. Copy the example backend file for your env:
   - Lab: `cp terraform/envs/lab/backend.hcl.example terraform/envs/lab/backend.hcl`
   - Prod: `cp terraform/envs/prod/backend.hcl.example terraform/envs/prod/backend.hcl`

2. Edit `backend.hcl` and set your organization and workspace name.

3. Initialize Terraform to migrate state (or set up fresh state):

   ```bash
   terraform -chdir=terraform/envs/lab init -backend-config=backend.hcl
   terraform -chdir=terraform/envs/prod init -backend-config=backend.hcl
   ```

## Local secrets

Each env uses `secrets.auto.tfvars` in its folder for credentials and SSH keys. These files are gitignored.

- Lab: `terraform/envs/lab/secrets.auto.tfvars`
- Prod: `terraform/envs/prod/secrets.auto.tfvars`

## Plans

To preview changes without a backend:

```bash
terraform -chdir=terraform/envs/lab init -backend=false
terraform -chdir=terraform/envs/lab plan -var-file=lab.tfvars

terraform -chdir=terraform/envs/prod init -backend=false
terraform -chdir=terraform/envs/prod plan -var-file=prod.tfvars
```
