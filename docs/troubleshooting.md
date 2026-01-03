# Troubleshooting

Common issues and fixes.

## CI/CD Issues

### CI says Ansible skipped — why?

In push workflow, Ansible runs only if:
- `apply == 'true'` OR
- `ansible_changed == 'true'`

If neither is true, the job is skipped. For Semaphore integration, ensure the webhook or API trigger is configured in [CI/CD settings](ci-cd.md).

### Terraform fmt/validate fails

Run fmt and validate locally per environment:

```sh
terraform -chdir=terraform/envs/prod fmt -check
terraform -chdir=terraform/envs/prod validate
```

Common fixes:
- Fix spacing around `=` in tfvars (use single spaces)
- Remove stray tabs or alignment spaces

## Packer Issues

### Build failing with vCenter URL

Ensure `VCENTER_SERVER` is only the host/IP (e.g., `10.37.10.35`).

The workflow normalizes values by stripping scheme and path, but it's best to provide just the host.

See [Packer docs](packer.md) for more details.

## VM/Cloud-init Issues

### Static IP not applied on first boot

1. Confirm cloud-init sees `guestinfo.metadata` and network v2 config
2. Check logs:
   ```sh
   cat /var/log/cloud-init.log
   cat /var/log/cloud-init-output.log
   ```

See [Terraform docs](terraform.md) for cloud-init configuration.

## Gitea Issues

### Service fails to start

Check file permissions:
```sh
ls -la /etc/gitea/app.ini
# Should be: owner git:git, mode 0660
```

Check logs:
```sh
journalctl -u gitea --no-pager -n 200
```

### Upgrade didn't change version

The role now forces binary overwrite. Re-run the playbook:
```sh
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/gitea.yml
```

Backup is taken by default to `/var/backups`.

See [Ansible docs](ansible.md) for role configuration.

---

**Still stuck?** Check the [CI/CD workflow logs](ci-cd.md) or run playbooks with `-vvv` for verbose output.
