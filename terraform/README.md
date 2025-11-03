# Terraform

Enterprise-style structure using modules, with per-environment roots.

- envs/lab and envs/prod: root modules (provider + module call)
- modules/vm: Encapsulates VM clone logic and post-clone disk mount
- variables.tf / outputs.tf at repository root still define inputs the env roots use

Usage
- cd envs/lab && terraform init && terraform apply
- or use helpers: ../bin/apply.sh lab

Conventions
- No guest customization by default; DHCP assumed
- Optional data disk provisioned and mounted via remote-exec
- Use remote backend per env (configure backend in env root if desired)
