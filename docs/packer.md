# Packer: Build AlmaLinux 10 Template

Packer builds a vSphere template containing:
- AlmaLinux 10 minimal
- cloud-init (VMware datasource)
- open-vm-tools

Entry point: `packer/alma-template.pkr.hcl`

Inputs
- vCenter: VCENTER_SERVER, VSPHERE_USER, VSPHERE_PASSWORD
- SSH key for the communicator is generated ephemerally in CI

CI behavior
- Packer job runs only when files under `packer/` (or `*.pkr.hcl`) change
- Workflow normalizes `VCENTER_SERVER` by stripping `http(s)://` and `/sdk`
- Missing secrets will fail the job early with a helpful message

Local build (optional)
```sh
cd packer
packer init .
PACKER_LOG=1 packer build \
  -var "vcenter_server=10.37.10.35" \
  -var "vcenter_username=$VSPHERE_USER" \
  -var "vcenter_password=$VSPHERE_PASSWORD" \
  alma-template.pkr.hcl
```

Output
- A vSphere template named similar to `almalinux-10-minimal-template-YYYYMMDD`
