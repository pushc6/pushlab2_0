# CI/CD Orchestration (Gitea Actions)

Workflows: `.gitea/workflows/`

## Available Workflows

### Core Orchestration

**orchestrate-push.yaml** (push-triggered)
- Triggers: push to branches like `orchestrate`, `orchestrate-*`, `main`
- Jobs:
  - `validate`: Installs tools, detects changes, runs `terraform fmt -check` and `validate`
  - `packer-build`: Runs only when `packer/` changed
  - `terraform`: Plans/applies based on branch name
  - `ansible-semaphore`: Triggers Semaphore when apply succeeds or ansible changed

**orchestrate-dispatch.yaml** (manual)
- Triggers: workflow_dispatch (Run button in Gitea UI)
- Inputs:
  - `environment`: lab or prod
  - `action`: plan or apply
  - `build_packer`: optionally rebuild template first
- Performs: Packer build → Terraform plan/apply → Semaphore trigger

### Supporting Workflows

**rebuild-packer-images.yaml**
- Rebuilds vSphere templates from Packer configs
- Triggered manually or when packer files change

**build-ee.yaml**
- Builds Ansible Execution Environment container
- Pushes to container registry
- Triggered when `execution-environment/` changes

**build-ci-image.yaml**
- Builds the AlmaLinux CI runner image
- Used by other workflows as base container

**schedule-drift-check.yaml**
- Scheduled daily drift detection
- Triggers Semaphore for full convergence check

**prod-drift-check.yaml**
- Production-specific drift detection
- Compares current state against desired

**redeploy-vm.yaml**
- Manual VM redeployment workflow
- Destroys and recreates specific VMs

## Secrets Required

| Secret | Purpose |
|--------|---------|
| `VSPHERE_USER` | vCenter username |
| `VSPHERE_PASSWORD` | vCenter password |
| `VCENTER_SERVER` | vCenter host/IP |
| `AWS_ACCESS_KEY_ID` | S3 backend (B2) |
| `AWS_SECRET_ACCESS_KEY` | S3 backend (B2) |
| `SEMAPHORE_URL` | Semaphore API endpoint |
| `SEMAPHORE_TOKEN` | Semaphore API token |
| `SEMAPHORE_PROJECT_ID` | Semaphore project |
| `SEMAPHORE_TEMPLATE_ID` | Task template to trigger |

## Typical Triggers

- **Push to `main`**: validation + gated Terraform, Packer (if changed)
- **Push to `orchestrate-apply`**: forces apply path
- **Manual dispatch**: choose environment/action via Gitea UI
- **Daily schedule**: drift check at 2:00 AM UTC
