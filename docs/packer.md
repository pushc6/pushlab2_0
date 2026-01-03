# Packer: Build AlmaLinux 10 Template

Packer builds a vSphere template containing:
- AlmaLinux 10 minimal
- cloud-init (VMware datasource)
- open-vm-tools

**Entry point:** `packer/alma-template.pkr.hcl`

## Inputs

| Variable | Source | Description |
|----------|--------|-------------|
| `vcenter_server` | `VCENTER_SERVER` | vCenter host/IP |
| `vcenter_username` | `VSPHERE_USER` | vCenter username |
| `vcenter_password` | `VSPHERE_PASSWORD` | vCenter password |

SSH key for the communicator is generated ephemerally in CI.

See [Secrets Setup](setup-secrets.md) for configuration.

## CI Behavior

- Packer job runs only when files under `packer/` (or `*.pkr.hcl`) change
- Workflow normalizes `VCENTER_SERVER` by stripping `http(s)://` and `/sdk`
- Missing secrets will fail the job early with a helpful message

See [CI/CD docs](ci-cd.md) for workflow details.

## Local Build

```sh
cd packer
packer init .
PACKER_LOG=1 packer build \
  -var "vcenter_server=10.37.10.35" \
  -var "vcenter_username=$VSPHERE_USER" \
  -var "vcenter_password=$VSPHERE_PASSWORD" \
  alma-template.pkr.hcl
```

## Output

A vSphere template named similar to `almalinux-10-minimal-template-YYYYMMDD`

---

**Next step:** Use [Terraform](terraform.md) to clone VMs from this template.
