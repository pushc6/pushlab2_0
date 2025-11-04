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

## Remote backend (S3-compatible, e.g., Backblaze B2 S3, MinIO, TrueNAS)

1. Create a non-secret backend config per env (commit this):
    - `terraform/envs/<env>/backend.hcl` with values like:

    ```hcl
    # Example S3-compatible backend (commit-safe)
    bucket              = "tf-state"
    key                 = "<env>/terraform.tfstate"
    region              = "us-east-1"          # required by provider
    endpoint            = "https://s3.example.local"
    force_path_style    = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
    ```

2. Provide credentials OUTSIDE Git, either:
    - As environment variables in your shell/CI:
       - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optionally `AWS_SESSION_TOKEN`
    - Or via an ignored file:
       - Copy `backend.s3.secrets.hcl.example` to `backend.s3.secrets.hcl` and fill

3. Initialize with both files:

    ```bash
    terraform -chdir=terraform/envs/<env> init \
       -backend-config=backend.hcl \
       -backend-config=backend.s3.secrets.hcl
    ```

Note: S3 backend locking requires DynamoDB (or compatible). If you don’t have that, there’s no state locking—avoid concurrent applies. For full locking on‑prem, consider the Consul backend.
