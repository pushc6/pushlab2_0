# Overview

This repository defines an end-to-end pipeline to provision and configure a Gitea service on vSphere using Infrastructure as Code.

## What it delivers

- A [Packer](packer.md)-built AlmaLinux 10 vSphere template with cloud-init and open-vm-tools
- [Terraform](terraform.md) modules to clone VMs from that template with a static IP via cloud-init network v2 and optional data disk
- [Ansible](ansible.md) role to install/configure Gitea, create the admin user, and optionally install a Docker-based Gitea Actions runner
- [CI/CD](ci-cd.md) (Gitea Actions) to orchestrate Packer → Terraform → Ansible (via Semaphore) with change detection and gating

## Key components

| Component | Location | Purpose |
|-----------|----------|---------|
| Packer | `packer/` | VM template building |
| Terraform | `terraform/envs/{lab,prod}/` | Infrastructure provisioning |
| Ansible | `ansible/` | Configuration management |
| CI/CD | `.gitea/workflows/` | Automation pipelines |

## High-level flow

```
┌─────────┐    ┌───────────┐    ┌─────────┐
│ Packer  │───▶│ Terraform │───▶│ Ansible │
└─────────┘    └───────────┘    └─────────┘
     │              │               │
     ▼              ▼               ▼
  Template      VM + disk       Configured
  in vSphere    provisioned     application
```

1. Build or update the vSphere template with Packer (only when packer files change)
2. Terraform plans/applies for lab/prod to clone and configure the VM(s)
3. Ansible (Semaphore) provisions Gitea and optional runner
4. CI gating ensures only relevant parts run based on changes

## Next steps

- **New here?** See [Prerequisites](prerequisites.md) then [Bootstrapping](bootstrapping.md)
- **Ready to deploy?** Follow the [Bootstrapping](bootstrapping.md) guide
- **Need help?** Check [Troubleshooting](troubleshooting.md)
