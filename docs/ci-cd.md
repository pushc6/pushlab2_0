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

**ansible-lint.yaml**
- Runs `ansible-lint` (production profile) and `ansible-playbook --syntax-check`
- Triggered on push/PR when `ansible/` changes

**prod-drift-check.yaml**
- Scheduled daily drift detection for production (3:00 AM UTC) + manual dispatch
- `terraform plan -detailed-exitcode`; notifies Discord and PagerDuty on drift

**redeploy-vm.yaml**
- Manual VM redeployment workflow
- Destroys and recreates specific VMs

## Adding a Workflow That Runs `packer build`

Any new workflow that invokes `packer build` against vSphere **must** use this runner pattern:

```yaml
runs-on: [self-hosted, linux, x64, packer-vm]   # bare-metal on packer_builder VM
# do NOT set `container:` for this job
env:
  PACKER_HTTP_ADDR: "10.37.80.5"                # packer_builder's VLAN 80 IP
```

Why: Packer hosts the kickstart over HTTP, and the vSphere VM being built must reach
that listener. Container runners get a Docker-bridge IP (e.g. `172.18.0.2`) which is
not routable from the VLAN; the install hangs at the kickstart fetch.

Reference implementations: `orchestrate-push.yaml`, `orchestrate-dispatch.yaml`,
`rebuild-packer-images.yaml` (all use the same pattern).

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
- **Daily schedule**: drift check at 3:00 AM UTC
