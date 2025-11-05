# CI/CD Orchestration (Gitea Actions)

Workflows: `.gitea/workflows/`

Key jobs and gating (push workflow)
- validate
  - Installs tools, checks out code
  - Detects changes across packer/terraform/ansible/workflows
  - Runs `terraform fmt -check` and `validate` for both lab and prod
- packer-build
  - Runs only when `packer/` changed
  - Normalizes `VCENTER_SERVER` and builds the template
- terraform
  - Needs: validate, packer-build
  - Decides environment based on branch/tag name
  - Decides whether to apply: true on `orchestrate-apply*` or auto-apply on lab when TF or Packer changed
  - Exposes outputs: `environment`, `apply`, `ansible_changed`
- ansible-aap
  - Needs: terraform
  - Runs when `apply == 'true'` OR `ansible_changed == 'true'`
  - Triggers AAP job template via API (if AAP secrets present)
- aap-skip-report
  - Needs: terraform
  - Runs when AAP is skipped (the inverse of the condition above) and prints why

Manual dispatch workflow
- Inputs: `environment`, `action`, `build_packer`
- Optionally builds the template first, then does Terraform plan/apply
- Triggers AAP only on `action == apply`

Secrets mapping
- vSphere: `VSPHERE_USER`, `VSPHERE_PASSWORD`, `VCENTER_SERVER`
- AWS_*: for S3-compatible backend (B2)
- AAP_*: for triggering Ansible Automation Platform

Typical triggers
- Push to `main`: validation + gated Terraform, Packer (if changed)
- Push to `orchestrate-apply` (or tag `orchestrate-apply*`): forces apply path
- Manual Run (dispatch): choose environment/action; optional Packer build
