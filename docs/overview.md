# Overview

This repository defines an end-to-end pipeline to provision and configure a Gitea service on vSphere using Infrastructure as Code.

What it delivers:
- A Packer-built AlmaLinux 10 vSphere template with cloud-init and open-vm-tools
- Terraform modules to clone VMs from that template with a static IP via cloud-init network v2 and optional data disk
- Ansible role to install/configure Gitea, create the admin user, and optionally install a Docker-based Gitea Actions runner
- CI/CD (Gitea Actions) to orchestrate Packer → Terraform → Ansible (via AAP) with change detection and gating

Key components:
- Packer: `packer/`
- Terraform: `terraform/` (envs: `lab/`, `prod/`)
- Ansible: `ansible/` (role: `roles/gitea`)
- CI/CD: `.gitea/workflows/`

High-level flow:
1. Build or update the vSphere template with Packer (only when packer files change)
2. Terraform plans/applies for lab/prod to clone and configure the VM(s)
3. Ansible (AAP) provisions Gitea and optional runner
4. CI gating ensures only relevant parts run based on changes
