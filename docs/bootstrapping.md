# Bootstrapping a Fresh Environment

This guide walks through getting from zero to a running Gitea in vSphere.

> **Prerequisites:** Make sure you have the required access and tools. See [Prerequisites](prerequisites.md).

## 1. Fork/clone the repo

```sh
git clone <your-fork>
cd tf_generate_alma
```

## 2. Configure secrets

See [Secrets Setup](setup-secrets.md) for detailed instructions.

**CI repository secrets (Gitea):**
- `VCENTER_SERVER` (host/IP only)
- `VSPHERE_USER` / `VSPHERE_PASSWORD`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (/ `AWS_SESSION_TOKEN`)
- `SSH_PRIVATE_KEY` (optional for TF/Ansible access)
- `SEMAPHORE_URL` / `SEMAPHORE_TOKEN` / `SEMAPHORE_PROJECT_ID` (optional; enables Semaphore trigger)

## 3. (Optional) Prepare local files

These files are ignored by VCS:
- `terraform/envs/*/backend.s3.secrets.hcl` from `.example`
- `ansible/inventories/*/host_vars/<host>/secrets.yml` with Gitea admin credentials

## 4. Build the template

See [Packer docs](packer.md) for details.

**Via CI:**
- Push any change under `packer/`, or use the dispatch workflow with `build_packer=true`

**Local:**
```sh
cd packer
packer init .
packer build -var "vcenter_server=10.37.10.35" \
  -var "vcenter_username=$VSPHERE_USER" \
  -var "vcenter_password=$VSPHERE_PASSWORD" \
  alma-template.pkr.hcl
```

## 5. Terraform plan/apply

See [Terraform docs](terraform.md) for details.

**Via CI:**
- Push to `main` → plan
- Branch/tag `orchestrate-apply*` → apply
- Manual dispatch: choose `environment` and `action`

**Local:**
```sh
terraform -chdir=terraform/envs/prod init
terraform -chdir=terraform/envs/prod plan -var-file=prod.tfvars -out=tfplan.out
terraform -chdir=terraform/envs/prod apply -auto-approve tfplan.out
```

## 6. Ansible provisioning

See [Ansible docs](ansible.md) for details.

**Via CI:**
- Semaphore job triggers automatically when `apply == 'true'` or Ansible changed

**Local:**
```sh
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
  -i ansible/inventories/prod/hosts.yml \
  ansible/site.yml
```

## 7. Verify Gitea

- **HTTP:** http://<ip>:3000/ (or behind your proxy)
- **SSH:** `ssh -T -p 2222 git@<host>`

## 8. Optional: Register a Gitea Actions runner

- Provide `gitea_runner_registration_token` in host_vars
- The role will install Docker and register a runner automatically

---

**Having issues?** See [Troubleshooting](troubleshooting.md).
