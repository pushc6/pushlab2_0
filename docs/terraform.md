# Terraform: Clone and Configure VM

Terraform clones VMs from the [Packer](packer.md) template and injects cloud-init for static IP configuration using the VMware datasource.

## Key Features

- **guestinfo injection:** sets `guestinfo.metadata` and `guestinfo.userdata`
- **Cloud-init network v2** for static IPv4
- **Optional data disk** (e.g., for Gitea data)
- **Emits inventory file** for Ansible at `ansible/inventories/*/hosts.yml`

## Layout

```
terraform/
├── envs/
│   ├── lab/           # Lab environment
│   │   ├── main.tf
│   │   ├── lab.tfvars
│   │   └── backend.hcl
│   └── prod/          # Production environment
│       ├── main.tf
│       ├── prod.tfvars
│       └── backend.hcl
```

## Backend Configuration

| Context | Method |
|---------|--------|
| CI | Uses AWS_* secrets + `backend.hcl` |
| Local | Uses `backend.s3.secrets.hcl` (gitignored) |

See [Secrets Setup](setup-secrets.md) for backend credentials.

## Usage

### Local Runs

```sh
# Lab environment
terraform -chdir=terraform/envs/lab init
terraform -chdir=terraform/envs/lab plan -var-file=lab.tfvars -out=tfplan.out
terraform -chdir=terraform/envs/lab apply -auto-approve tfplan.out

# Production environment
terraform -chdir=terraform/envs/prod init
terraform -chdir=terraform/envs/prod plan -var-file=prod.tfvars -out=tfplan.out
terraform -chdir=terraform/envs/prod apply -auto-approve tfplan.out
```

### CI Runs

See [CI/CD docs](ci-cd.md) for automated workflows.

## Key Variables

Configure in `envs/*/*.tfvars`:

| Variable | Description |
|----------|-------------|
| `datacenter` | vSphere datacenter name |
| `cluster` | vSphere cluster name |
| `datastore` | Datastore for VMs |
| `network` | Network/portgroup name |
| `vm_folder` | VM folder path |
| `template_name` | Packer template to clone |
| `vms` | Map of VMs with CPU, memory, disk, IP settings |
| `vm_ssh_user` | SSH user for provisioners |

## Validation

```sh
terraform -chdir=terraform/envs/prod fmt -check
terraform -chdir=terraform/envs/prod validate
```

---

**Next step:** Configure the VM with [Ansible](ansible.md).
