# Documentation Index

This directory contains detailed documentation for the AlmaLinux 10 vSphere IaC project.

## Getting Started

| Document | Description |
|----------|-------------|
| [Overview](overview.md) | High-level architecture and what this project delivers |
| [Prerequisites](prerequisites.md) | Required access, tools, and secrets |
| [Bootstrapping](bootstrapping.md) | Step-by-step guide from zero to running |

## Core Components

| Document | Description |
|----------|-------------|
| [Packer](packer.md) | How the vSphere VM template is built |
| [Terraform](terraform.md) | How VMs are cloned and configured with cloud-init |
| [Ansible](ansible.md) | Roles, playbooks, and configuration management |

## Operations

| Document | Description |
|----------|-------------|
| [CI/CD](ci-cd.md) | Gitea Actions workflows, triggers, and automation |
| [Secrets Setup](setup-secrets.md) | Where to configure secrets (CI vs local) |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |

## Quick Links

- **New to this project?** Start with [Overview](overview.md) then [Bootstrapping](bootstrapping.md)
- **Setting up CI/CD?** See [CI/CD](ci-cd.md) and [Secrets Setup](setup-secrets.md)
- **Something broken?** Check [Troubleshooting](troubleshooting.md)

## Project Structure

```
tf_generate_alma/
├── packer/              # VM template building
├── terraform/           # Infrastructure provisioning
│   └── envs/
│       ├── lab/         # Lab environment
│       └── prod/        # Production environment
├── ansible/             # Configuration management
│   ├── inventories/     # Environment inventories
│   ├── roles/           # Reusable roles
│   └── *.yml            # Playbooks
├── execution-environment/  # Ansible EE container
├── docker/              # CI container images
└── .gitea/workflows/    # CI/CD pipelines
```
