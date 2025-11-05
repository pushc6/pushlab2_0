# Bootstrapping a Fresh Environment

This guide walks through getting from zero to a running Gitea in vSphere.

1) Fork/clone the repo
```sh
git clone <your-fork>
cd tf_generate_alma
```

2) Configure CI repository secrets (Gitea)
- VCENTER_SERVER (host/IP only)
- VSPHERE_USER / VSPHERE_PASSWORD
- AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (/ AWS_SESSION_TOKEN)
- SSH_PRIVATE_KEY (optional for TF/Ansible access)
- AAP_URL / AAP_TOKEN / AAP_JOB_TEMPLATE_ID (optional; enables AAP trigger)

3) (Optional) Prepare local files (ignored by VCS)
- `terraform/envs/*/backend.s3.secrets.hcl` from `.example`
- `ansible/inventories/*/host_vars/<host>/secrets.yml` with Gitea admin credentials

4) Build the template (CI or local)
- CI (push any change under `packer/`, or use the dispatch workflow with `build_packer=true`)
- Local:
```sh
cd packer
packer init .
packer build -var "vcenter_server=10.37.10.35" -var "vcenter_username=$VSPHERE_USER" -var "vcenter_password=$VSPHERE_PASSWORD" alma-template.pkr.hcl
```

5) Terraform plan/apply
- CI (push to `main` → plan; branch/tag `orchestrate-apply*` → apply)
- Manual dispatch: choose `environment` and `action`
- Local example:
```sh
terraform -chdir=terraform/envs/prod init
terraform -chdir=terraform/envs/prod plan -var-file=prod.tfvars -out=tfplan.out
terraform -chdir=terraform/envs/prod apply -auto-approve tfplan.out
```

6) Ansible provisioning
- CI: AAP job triggers automatically when `apply == 'true'` or Ansible changed
- Local: run
```sh
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/site.yml
```

7) Verify Gitea
- HTTP: http://<ip>:3000/ (or behind your proxy)
- SSH: `ssh -T -p 2222 git@<host>`

8) Optional: Register a Gitea Actions runner
- Provide `gitea_runner_registration_token` in host_vars
- The role will install Docker and register a runner automatically
