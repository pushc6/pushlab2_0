# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Infrastructure as Code (IaC) pipeline for provisioning and configuring Gitea on vSphere using AlmaLinux 10. Three-tier architecture: **Packer** (image build) → **Terraform** (provisioning) → **Ansible** (configuration).

## Rules
Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.


## Common Commands

### Pre-commit Hooks
```bash
pre-commit run --all-files
```
Runs gitleaks (secret scanning), terraform fmt, and inventory symlink sync.

### Terraform
```bash
# Lab environment
terraform -chdir=terraform/envs/lab init
terraform -chdir=terraform/envs/lab plan -var-file=lab.tfvars
terraform -chdir=terraform/envs/lab apply -var-file=lab.tfvars

# Production
terraform -chdir=terraform/envs/prod init
terraform -chdir=terraform/envs/prod plan -var-file=prod.tfvars
terraform -chdir=terraform/envs/prod apply -var-file=prod.tfvars

# Validation
terraform -chdir=terraform/envs/prod fmt -check
terraform -chdir=terraform/envs/prod validate
```

### Packer
```bash
cd packer
packer init .
packer build -var-file=secrets.pkrvars.hcl alma-template.pkr.hcl
```

### Ansible
```bash
ANSIBLE_HOST_KEY_CHECKING=False \
  ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/site.yml
```

### Linting
```bash
tflint --chdir=terraform/envs/prod  # Terraform linting (config: .tflint.hcl)
```

## Architecture

```
packer/                    # VM template building (AlmaLinux 10 + cloud-init)
├── alma-template.pkr.hcl  # Main Packer config
├── http/                  # Kickstart files
└── scripts/               # Build/cleanup/validate scripts

terraform/                 # Infrastructure provisioning
├── envs/lab/              # Lab environment root module
├── envs/prod/             # Production environment root module
└── modules/vm/            # Reusable VM module (clone, cloud-init, disks)

ansible/                   # Configuration management
├── inventories/           # Multi-environment (prod, lab, manual)
│   └── {env}/host_vars/   # Per-host variables
├── roles/                 # 21+ roles (gitea, firewall, docker, nginx, etc.)
├── site.yml               # Main playbook
└── *.yml                  # Specialized playbooks

execution-environment/     # Ansible EE container (AlmaLinux 10 base)
docker/ci-image/           # CI container (Terraform 1.7.5, Packer 1.11.2)
.gitea/workflows/          # Gitea Actions CI/CD (8 workflows)
docs/                      # Full documentation
```

## Key Design Patterns

- **Modular Terraform**: Environment-specific root modules (`envs/lab/`, `envs/prod/`) calling shared `modules/vm/`
- **Cloud-init integration**: VMware datasource with network v2 for static IP configuration
- **Inventory symlinks**: Consolidated `host_vars`/`group_vars` at inventories level with symlinks per environment
- **CI/CD gating**: Change detection in workflows to skip unnecessary Packer/Terraform runs
- **Semaphore integration**: External orchestration triggers Ansible playbooks via API

## CI/CD Workflows (.gitea/workflows/)

- `orchestrate-push.yaml`: Main pipeline - Packer (on change) → Terraform → Semaphore
- `orchestrate-dispatch.yaml`: Manual dispatch with environment/action inputs
- `build-ee.yaml`: Ansible Execution Environment container build
- `build-ci-image.yaml`: CI image with Terraform/Packer
- `rebuild-packer-images.yaml`: Manual/scheduled template rebuild
- `prod-drift-check.yaml`: Daily drift detection
- `redeploy-vm.yaml`: VM redeployment workflow

## Required Secrets

**CI and local development require:**
- `VSPHERE_USER`, `VSPHERE_PASSWORD`, `VCENTER_SERVER` - vSphere credentials
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` - Terraform S3 backend
- `SEMAPHORE_URL`, `SEMAPHORE_TOKEN`, `SEMAPHORE_PROJECT_ID`, `SEMAPHORE_TEMPLATE_ID` - Semaphore API

## Documentation

Comprehensive documentation in `docs/`:
- `overview.md` - Architecture and high-level flow
- `bootstrapping.md` - Step-by-step setup guide
- `packer.md`, `terraform.md`, `ansible.md` - Tool-specific guides
- `ci-cd.md` - Workflow documentation
- `troubleshooting.md` - Common issues and solutions
