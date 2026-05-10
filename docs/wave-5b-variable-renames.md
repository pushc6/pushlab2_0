# Wave 5B — Variable Renames

This document captures every Ansible variable renamed during the Wave 5B
`var-naming[no-role-prefix]` cleanup. Each role's internal variables now
use the role name as a prefix (per ansible-lint's production profile).

**External consumers (Semaphore surveys, out-of-repo group_vars, runbooks)
that reference any of these by their old name need to be updated.** The
in-repo references were swept exhaustively by the bulk perl renames.

---

## opnsense_firewall

| Old | New |
|---|---|
| `firewall_defaults` | `opnsense_firewall_defaults` |
| `opnsense_aliases` | `opnsense_firewall_aliases` |
| `terraform_host_firewall_rules` | `opnsense_firewall_terraform_rules` |
| `host_specific_rules` | `opnsense_firewall_host_specific_rules` |
| `custom_aliases` | `opnsense_firewall_custom_aliases` |
| `terraform_alias` | `opnsense_firewall_terraform_alias` |
| `host_aliases` | `opnsense_firewall_host_aliases` |
| `firewall_rules_list` | `opnsense_firewall_rules_list` |
| `firewall_rules` | `opnsense_firewall_rules` |

**Kept bare with `# noqa` (external API contract via Gitea secrets):**
`opnsense_api_key`, `opnsense_api_secret`

---

## debian_updates

| Old | New |
|---|---|
| `apt_cache_valid_time` | `debian_updates_apt_cache_valid_time` |
| `apt_upgrade_type` | `debian_updates_apt_upgrade_type` |
| `apt_autoremove` | `debian_updates_apt_autoremove` |
| `apt_autoclean` | `debian_updates_apt_autoclean` |
| `apt_update_cache_only` | `debian_updates_apt_update_cache_only` |
| `apt_update_result` | `debian_updates_apt_result` |
| `schedule_reboot` | `debian_updates_schedule_reboot` |
| `reboot_delay_minutes` | `debian_updates_reboot_delay_minutes` |
| `reboot_required_file` | `debian_updates_reboot_required_file` |

---

## acme_sh

| Old | New |
|---|---|
| `acme_default_ca` | `acme_sh_default_ca` |
| `acme_default_key_length` | `acme_sh_default_key_length` |
| `acme_auto_upgrade` | `acme_sh_auto_upgrade` |
| `acme_cert_deploy_dir` | `acme_sh_cert_deploy_dir` |
| `acme_reload_cmd` | `acme_sh_reload_cmd` |
| `acme_dns_provider` | `acme_sh_dns_provider` |
| `acme_generate_dhparams` | `acme_sh_generate_dhparams` |
| `acme_dhparams_bits` | `acme_sh_dhparams_bits` |
| `acme_certificates` | `acme_sh_certificates` |
| `acme_email` | `acme_sh_email` |
| `acme_cf_token` | `acme_sh_cf_token` |
| `acme_cf_account_id` | `acme_sh_cf_account_id` |
| `cert_domain` | `acme_sh_cert_domain` |
| `cert_ecc_suffix` | `acme_sh_cert_ecc_suffix` |
| `cert_key_length` | `acme_sh_cert_key_length` |
| `cert_wildcard` | `acme_sh_cert_wildcard` |
| `cert_list` | `acme_sh_cert_list` |
| `cert_file_check` | `acme_sh_cert_file_check` |
| `cert_needs_issue` | `acme_sh_cert_needs_issue` |
| `cert_deployed` | `acme_sh_cert_deployed` |
| `remove_result` | `acme_sh_remove_result` |
| `issue_result` | `acme_sh_issue_result` |
| `deploy_result` | `acme_sh_deploy_result` |
| `acme_install_result` | `acme_sh_install_result` |
| `dhparams_stat` | `acme_sh_dhparams_stat` |

---

## firewall_hardened

| Old | New |
|---|---|
| `firewall_custom_rich_rules` | `firewall_hardened_custom_rich_rules` |
| `firewall_default_zone` | `firewall_hardened_default_zone` |
| `firewall_dmz_vlan_subnet` | `firewall_hardened_dmz_vlan_subnet` |
| `firewall_dmz_vlan_subnet_ipv6` | `firewall_hardened_dmz_vlan_subnet_ipv6` |
| `firewall_enable_ipv6` | `firewall_hardened_enable_ipv6` |
| `firewall_enable_preflight` | `firewall_hardened_enable_preflight` |
| `firewall_enable_validation` | `firewall_hardened_enable_validation` |
| `firewall_global_services` | `firewall_hardened_global_services` |
| `firewall_log_denied_packets` | `firewall_hardened_log_denied_packets` |
| `firewall_log_level` | `firewall_hardened_log_level` |
| `firewall_management_services` | `firewall_hardened_management_services` |
| `firewall_management_vlan_subnet` | `firewall_hardened_management_vlan_subnet` |
| `firewall_management_vlan_subnet_ipv6` | `firewall_hardened_management_vlan_subnet_ipv6` |
| `firewall_proxy_services` | `firewall_hardened_proxy_services` |
| `firewall_public_services` | `firewall_hardened_public_services` |
| `firewall_purge_stale_rules` | `firewall_hardened_purge_stale_rules` |
| `firewall_reverse_proxy_ips` | `firewall_hardened_reverse_proxy_ips` |
| `firewall_rollback_timer` | `firewall_hardened_rollback_timer` |
| `firewall_services` | `firewall_hardened_services` |
| `firewall_ssh_allowed_subnets` | `firewall_hardened_ssh_allowed_subnets` |
| `firewall_ssh_allowed_subnets_ipv6` | `firewall_hardened_ssh_allowed_subnets_ipv6` |
| `firewall_ssh_hardening_enabled` | `firewall_hardened_ssh_hardening_enabled` |
| `firewall_ssh_port` | `firewall_hardened_ssh_port` |
| `firewall_strict_mode` | `firewall_hardened_strict_mode` |
| `firewall_trusted_vlan_subnet` | `firewall_hardened_trusted_vlan_subnet` |
| `firewall_trusted_vlan_subnet_ipv6` | `firewall_hardened_trusted_vlan_subnet_ipv6` |
| `firewall_wireguard_vlan_subnet` | `firewall_hardened_wireguard_vlan_subnet` |
| `firewall_wireguard_vlan_subnet_ipv6` | `firewall_hardened_wireguard_vlan_subnet_ipv6` |
| `firewalld_handler_status` | `firewall_hardened_firewalld_handler_status` |
| `firewalld_installed` | `firewall_hardened_firewalld_installed` |
| `firewalld_reload_handler` | `firewall_hardened_firewalld_reload_handler` |
| `firewalld_running` | `firewall_hardened_firewalld_running` |
| `firewalld_status` | `firewall_hardened_firewalld_status` |
| `ansible_controller_ip` | `firewall_hardened_ansible_controller_ip` |
| `controller_in_allowed_subnet` | `firewall_hardened_controller_in_allowed_subnet` |
| `current_firewall_state` | `firewall_hardened_current_firewall_state` |
| `current_rich_rules` | `firewall_hardened_current_rich_rules` |
| `current_rules_list` | `firewall_hardened_current_rules_list` |
| `current_rules_normalized` | `firewall_hardened_current_rules_normalized` |
| `docker_installed` | `firewall_hardened_docker_installed` |
| `emergency_reload` | `firewall_hardened_emergency_reload` |
| `expected_rules_list` | `firewall_hardened_expected_rules_list` |
| `expected_rules_normalized` | `firewall_hardened_expected_rules_normalized` |
| `final_firewall_services` | `firewall_hardened_final_services` |
| `final_firewall_state` | `firewall_hardened_final_state` |
| `final_rich_rules` | `firewall_hardened_final_rich_rules` |
| `final_ssh_test` | `firewall_hardened_final_ssh_test` |
| `listening_tcp_ports` | `firewall_hardened_listening_tcp_ports` |
| `listening_tcp_ports_ipv6` | `firewall_hardened_listening_tcp_ports_ipv6` |
| `listening_udp_ports` | `firewall_hardened_listening_udp_ports` |
| `listening_udp_ports_ipv6` | `firewall_hardened_listening_udp_ports_ipv6` |
| `normalized_services` | `firewall_hardened_normalized_services` |
| `permanent_rich_rules` | `firewall_hardened_permanent_rich_rules` |
| `ports_active` | `firewall_hardened_ports_active` |
| `proxy_sources` | `firewall_hardened_proxy_sources` |
| `rich_rules_active` | `firewall_hardened_rich_rules_active` |
| `rollback_firewalld_status` | `firewall_hardened_rollback_firewalld_status` |
| `rollback_reload` | `firewall_hardened_rollback_reload` |
| `services_active` | `firewall_hardened_services_active` |
| `ssh_rich_rules_ipv4` | `firewall_hardened_ssh_rich_rules_ipv4` |
| `ssh_rich_rules_ipv6` | `firewall_hardened_ssh_rich_rules_ipv6` |
| `ssh_service_check` | `firewall_hardened_ssh_service_check` |
| `ssh_service_enabled` | `firewall_hardened_ssh_service_enabled` |
| `ssh_service_removed` | `firewall_hardened_ssh_service_removed` |
| `ssh_was_enabled` | `firewall_hardened_ssh_was_enabled` |
| `stale_rules` | `firewall_hardened_stale_rules` |
| `stale_rules_normalized` | `firewall_hardened_stale_rules_normalized` |
| `unified_services` | `firewall_hardened_unified_services` |
| `unprotected_ports` | `firewall_hardened_unprotected_ports` |
| `backup_files` | `firewall_hardened_backup_files` |
| `_ssh_test_host` | `firewall_hardened_ssh_test_host` |

---

## enhanced_proxy_nginx

| Old | New |
|---|---|
| `all_services` | `enhanced_proxy_nginx_all_services` |
| `current_selinux_ports` | `enhanced_proxy_nginx_current_selinux_ports` |
| `default_auth_type` | `enhanced_proxy_nginx_default_auth_type` |
| `default_proxy_mode` | `enhanced_proxy_nginx_default_proxy_mode` |
| `default_ssl_domain` | `enhanced_proxy_nginx_default_ssl_domain` |
| `existing_http_ports` | `enhanced_proxy_nginx_existing_http_ports` |
| `filtered_services` | `enhanced_proxy_nginx_filtered_services` |
| `hsts_max_age` | `enhanced_proxy_nginx_hsts_max_age` |
| `hsts_preload` | `enhanced_proxy_nginx_hsts_preload` |
| `httpd_network_connect_status` | `enhanced_proxy_nginx_httpd_network_connect_status` |
| `httpd_network_status` | `enhanced_proxy_nginx_httpd_network_status` |
| `logout_config` | `enhanced_proxy_nginx_logout_config` |
| `monitoring` | `enhanced_proxy_nginx_monitoring` |
| `nginx_client_max_body_size` | `enhanced_proxy_nginx_client_max_body_size` |
| `nginx_conf_d` | `enhanced_proxy_nginx_conf_d` |
| `nginx_config` | `enhanced_proxy_nginx_config` |
| `nginx_proxy_timeout` | `enhanced_proxy_nginx_proxy_timeout` |
| `nginx_sites_available` | `enhanced_proxy_nginx_sites_available` |
| `nginx_sites_enabled` | `enhanced_proxy_nginx_sites_enabled` |
| `nginx_test` | `enhanced_proxy_nginx_test` |
| `oauth2_backend_ports` | `enhanced_proxy_nginx_oauth2_backend_ports` |
| `oauth2_backend_ports_check` | `enhanced_proxy_nginx_oauth2_backend_ports_check` |
| `oauth2_mode_services` | `enhanced_proxy_nginx_oauth2_mode_services` |
| `oauth2_proxy_host` | `enhanced_proxy_nginx_oauth2_proxy_host` |
| `oauth2_proxy_port` | `enhanced_proxy_nginx_oauth2_proxy_port` |
| `oauth2_services_filter` | `enhanced_proxy_nginx_oauth2_services_filter` |
| `ports_to_configure` | `enhanced_proxy_nginx_ports_to_configure` |
| `proxy_role_config` | `enhanced_proxy_nginx_role_config` |
| `referrer_policy` | `enhanced_proxy_nginx_referrer_policy` |
| `selinux_config` | `enhanced_proxy_nginx_selinux_config` |
| `selinux_port_result` | `enhanced_proxy_nginx_selinux_port_result` |
| `selinux_status` | `enhanced_proxy_nginx_selinux_status` |
| `selinux_tools_missing` | `enhanced_proxy_nginx_selinux_tools_missing` |
| `selinux_tools_needed` | `enhanced_proxy_nginx_selinux_tools_needed` |
| `services_with_proxy_modes` | `enhanced_proxy_nginx_services_with_proxy_modes` |
| `ssl_ciphers` | `enhanced_proxy_nginx_ssl_ciphers` |
| `ssl_prefer_server_ciphers` | `enhanced_proxy_nginx_ssl_prefer_server_ciphers` |
| `ssl_protocols` | `enhanced_proxy_nginx_ssl_protocols` |
| `ssl_resolver` | `enhanced_proxy_nginx_ssl_resolver` |
| `ssl_resolver_timeout` | `enhanced_proxy_nginx_ssl_resolver_timeout` |
| `ssl_session_tickets` | `enhanced_proxy_nginx_ssl_session_tickets` |
| `ssl_session_timeout` | `enhanced_proxy_nginx_ssl_session_timeout` |
| `ssl_stapling_enabled` | `enhanced_proxy_nginx_ssl_stapling_enabled` |
| `traditional_mode_services` | `enhanced_proxy_nginx_traditional_mode_services` |
| `traditional_proxy_config` | `enhanced_proxy_nginx_traditional_proxy_config` |
| `x_content_type_options` | `enhanced_proxy_nginx_x_content_type_options` |
| `x_frame_options` | `enhanced_proxy_nginx_x_frame_options` |
| `x_xss_protection` | `enhanced_proxy_nginx_x_xss_protection` |

---

## oauth2_proxy_nginx

| Old | New |
|---|---|
| `current_selinux_ports` | `oauth2_proxy_nginx_current_selinux_ports` |
| `default_auth_type` | `oauth2_proxy_nginx_default_auth_type` |
| `default_ssl_domain` | `oauth2_proxy_nginx_default_ssl_domain` |
| `enable_force_logout` | `oauth2_proxy_nginx_enable_force_logout` |
| `enable_id_token_logout` | `oauth2_proxy_nginx_enable_id_token_logout` |
| `enable_sso_logout` | `oauth2_proxy_nginx_enable_sso_logout` |
| `existing_http_ports` | `oauth2_proxy_nginx_existing_http_ports` |
| `filtered_oauth2_services` | `oauth2_proxy_nginx_filtered_services` |
| `httpd_network_connect_status` | `oauth2_proxy_nginx_httpd_network_connect_status` |
| `httpd_network_status` | `oauth2_proxy_nginx_httpd_network_status` |
| `keycloak_client_id` | `oauth2_proxy_nginx_keycloak_client_id` |
| `keycloak_realm` | `oauth2_proxy_nginx_keycloak_realm` |
| `logout_success_page` | `oauth2_proxy_nginx_logout_success_page` |
| `nginx_client_max_body_size` | `oauth2_proxy_nginx_client_max_body_size` |
| `nginx_conf_d` | `oauth2_proxy_nginx_conf_d` |
| `nginx_proxy_timeout` | `oauth2_proxy_nginx_proxy_timeout` |
| `nginx_sites_available` | `oauth2_proxy_nginx_sites_available` |
| `nginx_sites_enabled` | `oauth2_proxy_nginx_sites_enabled` |
| `nginx_test` | `oauth2_proxy_nginx_test` |
| `oauth2_backend_ports` | `oauth2_proxy_nginx_backend_ports` |
| `oauth2_backend_ports_check` | `oauth2_proxy_nginx_backend_ports_check` |
| `oauth2_proxy_host` | `oauth2_proxy_nginx_host` |
| `oauth2_proxy_port` | `oauth2_proxy_nginx_port` |
| `oauth2_role_config` | `oauth2_proxy_nginx_role_config` |
| `oauth2_services_filter` | `oauth2_proxy_nginx_services_filter` |
| `old_logout_files` | `oauth2_proxy_nginx_old_logout_files` |
| `ports_to_configure` | `oauth2_proxy_nginx_ports_to_configure` |
| `selinux_port_result` | `oauth2_proxy_nginx_selinux_port_result` |
| `selinux_status` | `oauth2_proxy_nginx_selinux_status` |
| `selinux_tools_missing` | `oauth2_proxy_nginx_selinux_tools_missing` |
| `selinux_tools_needed` | `oauth2_proxy_nginx_selinux_tools_needed` |
| `ssl_ciphers` | `oauth2_proxy_nginx_ssl_ciphers` |
| `ssl_prefer_server_ciphers` | `oauth2_proxy_nginx_ssl_prefer_server_ciphers` |
| `ssl_protocols` | `oauth2_proxy_nginx_ssl_protocols` |

---

## packer_builder

| Old | New |
|---|---|
| `act_runner_binary` | `packer_builder_act_runner_binary` |
| `act_runner_current_version` | `packer_builder_act_runner_current_version` |
| `act_runner_download` | `packer_builder_act_runner_download` |
| `act_runner_download_url` | `packer_builder_act_runner_download_url` |
| `act_runner_install_path` | `packer_builder_act_runner_install_path` |
| `act_runner_install_required` | `packer_builder_act_runner_install_required` |
| `act_runner_verify` | `packer_builder_act_runner_verify` |
| `act_runner_version` | `packer_builder_act_runner_version` |
| `gitea_instance_url` | `packer_builder_gitea_instance_url` |
| `gitea_runner_config_file` | `packer_builder_gitea_runner_config_file` |
| `gitea_runner_data_dir` | `packer_builder_gitea_runner_data_dir` |
| `gitea_runner_labels` | `packer_builder_gitea_runner_labels` |
| `gitea_runner_name` | `packer_builder_gitea_runner_name` |
| `gitea_runner_registration_token` | `packer_builder_gitea_runner_registration_token` |
| `gitea_runner_work_dir` | `packer_builder_gitea_runner_work_dir` |
| `packer_binary` | `packer_builder_packer_binary` |
| `packer_config_dir` | `packer_builder_packer_config_dir` |
| `packer_current_version` | `packer_builder_packer_current_version` |
| `packer_download` | `packer_builder_packer_download` |
| `packer_download_url` | `packer_builder_packer_download_url` |
| `packer_install_path` | `packer_builder_packer_install_path` |
| `packer_install_required` | `packer_builder_packer_install_required` |
| `packer_plugin_dir` | `packer_builder_packer_plugin_dir` |
| `packer_verify` | `packer_builder_packer_verify` |
| `packer_version` | `packer_builder_packer_version` |
| `packer_version_check` | `packer_builder_packer_version_check` |
| `packer_vsphere_plugin_source` | `packer_builder_packer_vsphere_plugin_source` |
| `runner_reg_file` | `packer_builder_runner_reg_file` |
| `runner_registration` | `packer_builder_runner_registration` |
| `runner_registration_file` | `packer_builder_runner_registration_file` |
| `runner_service_check` | `packer_builder_runner_service_check` |
| `terraform_binary` | `packer_builder_terraform_binary` |
| `terraform_current_version` | `packer_builder_terraform_current_version` |
| `terraform_download` | `packer_builder_terraform_download` |
| `terraform_download_url` | `packer_builder_terraform_download_url` |
| `terraform_install_path` | `packer_builder_terraform_install_path` |
| `terraform_install_required` | `packer_builder_terraform_install_required` |
| `terraform_verify` | `packer_builder_terraform_verify` |
| `terraform_version` | `packer_builder_terraform_version` |
| `terraform_version_check` | `packer_builder_terraform_version_check` |
| `vsphere_plugin_check` | `packer_builder_vsphere_plugin_check` |
| `vsphere_plugin_install` | `packer_builder_vsphere_plugin_install` |
| `vsphere_verify` | `packer_builder_vsphere_verify` |

---

## mount_data_disk

| Old | New |
|---|---|
| `data_fs_type` | `mount_data_disk_fs_type` |
| `data_mount_point` | `mount_data_disk_mount_point` |
| `disk_blkid` | `mount_data_disk_blkid` |
| `target_device` | `mount_data_disk_target_device` |
| `target_partition` | `mount_data_disk_target_partition` |
| `target_disk` | `mount_data_disk_target_disk` |

---

## system_hostname

| Old | New |
|---|---|
| `desired_hostname` | `system_hostname_desired` |
| `primary_ip` | `system_hostname_primary_ip` |

---

## system_users

| Old | New |
|---|---|
| `sudo_group` | `system_users_sudo_group` |

---

## network_interfaces

| Old | New |
|---|---|
| `network_interfaces` | `network_interfaces_list` |

---

## rhel_updates

| Old | New |
|---|---|
| `dnf_exclude_packages` | `rhel_updates_dnf_exclude_packages` |
| `dnf_security_updates_only` | `rhel_updates_dnf_security_updates_only` |
| `dnf_update_cache_only` | `rhel_updates_dnf_update_cache_only` |
| `dnf_update_result` | `rhel_updates_dnf_update_result` |
| `needs_restarting` | `rhel_updates_needs_restarting` |
| `needs_restarting_cmd` | `rhel_updates_needs_restarting_cmd` |
| `rhel_packages_to_install` | `rhel_updates_packages_to_install` |

---

## gitea (role-internal register vars only — `gitea_*` defaults already prefixed)

| Old | New |
|---|---|
| `act_runner_version` | `gitea_act_runner_version` |
| `create_admin` | `gitea_create_admin` |
| `docker_info` | `gitea_docker_info` |
| `extra_image_pull` | `gitea_extra_image_pull` |
| `git_docker_group` | `gitea_git_docker_group` |
| `runner_image_pull` | `gitea_runner_image_pull` |

---

## crowdsec

| Old | New |
|---|---|
| `bouncer_api_key` | `crowdsec_bouncer_api_key` |
| `bouncer_api_key_result` | `crowdsec_bouncer_api_key_result` |
| `bouncer_full_name` | `crowdsec_bouncer_full_name` |
| `existing_acquis_files` | `crowdsec_existing_acquis_files` |
| `legacy_acquis_file` | `crowdsec_legacy_acquis_file` |

---

## tailscale

| Old | New |
|---|---|
| `firewall_hardened_firewalld_status` *(unintended Wave-4-bulk side effect)* | `tailscale_firewalld_status` |
| `ufw_available` | `tailscale_ufw_available` |

---

## common

| Old | New |
|---|---|
| `disk_usage` | `common_disk_usage` |

---

## Kept bare with `# noqa: var-naming[no-role-prefix]`

These were left unprefixed because they're cross-role flags (set once in
`group_vars/all` and consumed by multiple roles) or external-API contracts:

| Variable | Reason |
|---|---|
| `pre_update_tasks_enabled` | Shared across `common`, `system_updates`, `debian_updates`, `rhel_updates` |
| `post_update_tasks_enabled` | Same |
| `enable_reboot` | Same |
| `reboot_timeout` | Same |
| `post_reboot_delay` | Same |
| `opnsense_api_key` | External — set via Gitea secret as Semaphore extra-var |
| `opnsense_api_secret` | Same |

---

## Downstream consumers to update

If any of the following references a renamed variable by its **old name**,
it must be updated:

1. **Semaphore surveys / extra-vars** — anywhere a survey defines or
   passes one of the renamed vars by its old name.
2. **`group_vars/` and `host_vars/` overrides outside `ansible/`** — none
   in this repo (the bulk renames swept all `ansible/group_vars/**` and
   `ansible/inventories/**`), but if any out-of-tree inventory is layered
   on top, those need updating.
3. **External documentation** — `roles/acme_sh/README.md` was updated by
   the bulk pass, but any wiki/runbook outside the repo is not.

Most likely Semaphore-side breakage candidates:

- `firewall_hardened_services`
- `firewall_hardened_ssh_allowed_subnets`
- `acme_sh_certificates`
- `acme_sh_email`
- `acme_sh_cf_token`
- `acme_sh_cf_account_id`
- `packer_builder_gitea_runner_*` (the `gitea_runner_*` set on
  packer_builder hosts only — the `gitea` role's own runner vars were
  left as-is)
- Survey-driven proxy deployment vars: `enhanced_proxy_nginx_role_config`,
  `oauth2_proxy_nginx_role_config`
