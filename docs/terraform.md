# Terraform: Clone and Configure VM

Terraform clones VMs from the Packer template and injects cloud-init for static IP configuration using the VMware datasource.

Key features
- guestinfo injection: sets `guestinfo.metadata` and `guestinfo.userdata`
- Cloud-init network v2 for static IPv4
- Optional data disk (e.g., for Gitea data)
- Emits an inventory file for Ansible

Layout
- `terraform/`
  - `envs/lab/` and `envs/prod/`: per-environment
  - `backend.hcl` and optional `backend.s3.secrets.hcl` (local only)
  - `*.tfvars` input files per environment (`lab.tfvars`, `prod.tfvars`)

Backend
- CI uses AWS_* secrets for an S3-compatible backend and `backend.hcl`
- Locally, you can place a `backend.s3.secrets.hcl` (ignored in VCS) for credentials

Typical runs (local)
```sh
# Lab
terraform -chdir=terraform/envs/lab init
terraform -chdir=terraform/envs/lab plan -var-file=lab.tfvars -out=tfplan.out
terraform -chdir=terraform/envs/lab apply -auto-approve tfplan.out

# Prod
terraform -chdir=terraform/envs/prod init
terraform -chdir=terraform/envs/prod plan -var-file=prod.tfvars -out=tfplan.out
terraform -chdir=terraform/envs/prod apply -auto-approve tfplan.out
```

Key vars (see `envs/*/*.tfvars`)
- vSphere inventory: `datacenter`, `cluster`, `datastore`, `network`, `vm_folder`
- Template: `template_name`
- Per-VM map: `vms = { "gitea" = { cpu_count, memory_mb, disk_size_gb, ipv4_* ... } }`
- SSH user for provisioners: `vm_ssh_user`

Validation
```sh
terraform -chdir=terraform/envs/prod fmt -check
terraform -chdir=terraform/envs/prod validate
```
