# Troubleshooting

## CI says AAP skipped — why?
- In push workflow, AAP runs only if `apply == 'true'` OR `ansible_changed == 'true'`.
- If neither is true, the job is skipped. We added `aap-skip-report` to print those values.
- Also ensure AAP secrets are set; otherwise the step prints "AAP secrets not set; skipping" and exits.

## Terraform fmt/validate fails
- Run fmt and validate locally per env:
```sh
terraform -chdir=terraform/envs/prod fmt -check
terraform -chdir=terraform/envs/prod validate
```
- Fix spacing around `=` in tfvars (single spaces), remove stray tabs/alignment.

## Packer build failing with vCenter URL
- Ensure `VCENTER_SERVER` is only the host/IP (e.g., `10.37.10.35`). The workflow normalizes values by stripping scheme and path.

## Static IP not applied on first boot
- Confirm cloud-init sees `guestinfo.metadata` and network v2 config
- Check `/var/log/cloud-init.log` and `/var/log/cloud-init-output.log`

## Gitea service fails to start
- Check file permissions for `/etc/gitea/app.ini` (owner `git:git`, mode `0660`)
- `journalctl -u gitea --no-pager -n 200`

## Gitea upgrade didn't change version
- The role now forces binary overwrite; re-run the play
- Backup is taken by default to `/var/backups`
