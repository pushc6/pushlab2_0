# Findings register

Risks, drift and discrepancies found while compiling these docs (2026-11-15). Nothing here has been changed. The register is for triage only.

**Severity:**
- **High** = exposure or single point of failure with real impact
- **Med** = reliability or correctness problem
- **Low** = hygiene / documentation

## A. Security exposure

| # | Sev | Finding | Evidence | Suggested action |
|---|---|---|---|---|
| A1 | High | Host firewall isn't filtering on **docker, docker-internal, prusa3dbawkz**: the firewalld active zone has no interfaces bound. Docker-published ports also bypass firewalld on every host (including raspberrypi-ha :3000/:8080/:8091) | live `firewall-cmd`, `ss` | Bind interfaces to a zone in `firewall_hardened`; use DOCKER-USER chain rules or bind published ports to specific IPs |
| A2 | High | **wolfbawt Postgres published on 0.0.0.0:5432** on docker-internal | docker-stacks `docker-internal/wolfbawt` | Remove the `ports:` entry or bind to 127.0.0.1 |
| A3 | High | **Inline secrets committed** in docker-stacks: teslamate (encryption key, DB, Mailgun), plex claim token, code-server, peanut (Influx token), csadmin (bouncer key), wolfbawt, semaphore (default admin pw), `komodo/config.toml` (renovate-bot Gitea token) | docker-stacks compose files | Rotate, then move to Komodo env / `.env`. HANDOFF.md already lists "vault the credentials" |
| A4 | Med | Docker remote API listening on **:2376** on docker | live `ss` | Confirm TLS client-cert auth and who uses it; restrict to the admin VLAN at OPNsense |
| A5 | Med | Many internal admin apps use **traditional mode** (no SSO gate): semaphore, komodo, truenas, synology, sab, readarr, zigbee, zwave, git, digx | nginx-internal live config | Consider oauth2 mode for apps without strong auth (zigbee, zwave, sab) |
| A6 | Med | Nextcloud AIO, AMP, HAOS and the gameserver update themselves outside Renovate/Komodo | — | Track versions; include in the patch cadence |
| A7 | Low | Unused open firewall ports: nginx-dmz **5202/tcp**, nginx-internal **3002/tcp**, gameserver **15000, 15777** | live firewalld vs `ss` | Remove from host_vars |
| A8 | Low | Synology SSH answered with "Too many authentication failures", and every RHEL/Synology SSH server warns about no post-quantum KEX | live | Cosmetic; consider updating OpenSSH or crypto policy |

## B. Availability / single points of failure

| # | Sev | Finding | Evidence | Suggested action |
|---|---|---|---|---|
| B1 | High | **OPNsense, ns01 (docker-secure), HAOS and Veeam boot from TrueNAS iSCSI.** A TrueNAS outage takes out routing, primary DNS/DHCP and backups at the same time | vCenter datastores | Move OPNsense + ns01 to local datastores. **Progress 2026-11-15:** ns02 moved to chonkyboi/`ssd_local1`, so DNS now survives one host or NAS failure (PR #28 pins it in Terraform). Still open: ns01 and OPNsense; consider an OPNsense CARP pair on local disks, HA restart priorities (OPNsense highest), and an ns01/ns02 anti-affinity rule |
| B2 | High | OPNsense is a single VM on chonkyboi. If that host goes down, all routing goes down. DHCP failover to ns02 is manual | vCenter | Document recovery; consider HA/DRS affinity or a CARP pair |
| B3 | Med | docker-internal is the control plane (Komodo, Semaphore, oauth2-proxy, MQTT, logs) **and** docker hosts Keycloak. If either is lost, SSO and automation are lost | services | Document break-glass access (local admin accounts) |
| B4 | Med | ns02 was down or rebooting during the first survey (rebooted 15:01). From VLAN 20 only 10.37.20.254 answers SSH; .70.254 and .80.254 time out (asymmetric path) | live | Check why it rebooted; this is expected behaviour per the NIC/rp_filter design |
| B5 | Med | Terraform B2 backend has **no state locking** | `backend.hcl` | The concurrency group mitigates CI races; local runs can still collide |
| B6 | Low | crowdsec VM has **2 GB RAM** running Postgres + LAPI | vCenter / live | Bump to 4 GB |

## C. Operational issues / drift

| # | Sev | Finding | Evidence | Suggested action |
|---|---|---|---|---|
| C1 | Med | docker-internal has **two default routes** (VLAN 70 metric 100, VLAN 10 metric 200), and `systemd-resolved.service` has failed | live | Drop the gateway on the mgmt NIC; fix resolved |
| C2 | Med | docker host is on kernel **6.8.0-59** while the other Ubuntu hosts are on -149, so a reboot is pending. Failed unit `snap-core20-2769.mount` | live | Schedule a reboot (GPU host) |
| C3 | Med | Disk pressure: gitea `/` **70%** (it has filled up before), prusa3dbawkz `/` 65%, docker `/` 64% | live `df` | Clean up; alert on disk usage |
| C4 | Med | **VM sizing drift vs Terraform:** gitea is 8 vCPU / 12 GB in vCenter vs 4 / 6 GB in `prod.tfvars`; packer_builder is 12 / 18 GB vs 4 / 8 GB | vCenter vs tfvars | Update tfvars or confirm `ignore_changes`; check the drift-check output |
| C5 | Med | nginx-internal had **stale upstreams**: aap → 10.37.70.27, esxi → 10.37.70.17, vsphere → 10.37.70.14 (none exist; mgmt VLAN 10 isn't reachable from the proxy anyway). **Fix in progress:** branch `fix/retire-stale-internal-vhosts` adds `enhanced_proxy_nginx_retired_domains`. Still open: readarr → .7:8787 and prusabawt → .7:8083 (not running). scrypted → 10.37.50.23 is **live** (an earlier note wrongly called it stale) | live `nginx -T`, vCenter | Run deploy_proxy_enhanced.yml via Semaphore; delete the aap/esxi/vsphere A records in Technitium |
| C6 | Med | nginx-dmz `sso.push-lab.com` → .7:4180 (nothing listens), `request.ryanpampush.com` also references .7:3579, upstream `zerotier_backend`/`bigfile_backend` → .7:3000 (nothing listens) | live | Remove dead vhosts |
| C7 | Med | **nginx-dmz vhosts are mostly hand-managed.** Only cargame-dev and medianotifier are in `group_vars/nginxdmz/proxy_vars_enhanced.yml`. Most certificates outside rangernet.dev are hand-issued. **OPNsense NAT is not in IaC** | repo vs live | Bring them into IaC |
| C8 | Low | VictoriaMetrics `--vmalert.proxyURL` points at a vmalert that doesn't exist; the only scrape target is CrowdSec; there are no alert rules | docker-stacks | Add vmalert + node-exporter, or remove the flag |
| C9 | Low | Port 3000 is the default for both cargame and tracearr on docker-internal (tracearr is overridden to 3005 through env) | docker-stacks | Make it explicit in compose |
| C10 | Low | Periphery gets deployed to **gitea and packer_builder** because they're in `docker_hosts` | `komodo-periphery.yml` | Intended? |
| C11 | Low | prusa3dbawkz has a `copyparty_default` Docker network with no container | live | Prune |
| C12 | Low | NFS exports reference unknown hosts **10.37.70.10** (Synology `/volume1/ESXi`) and **10.37.70.11** (`/volume1/Backup`). `/nfs/docker` is mounted on docker but unused | showmount | Prune exports and the mount |
| C13 | Low | Gitea SSH host key for name `gitea` doesn't match (`~/.ssh/known_hosts` line 193); the IP entry does match | SSH survey | Verify the new key out-of-band, then refresh known_hosts |

## D. Documentation & inventory drift

| # | Finding | Where |
|---|---|---|
| D1 | `docs/README.md`, `overview.md`, `bootstrapping.md` describe a Gitea-only project | docs/ |
| D2 | `docs/diagrams/*.drawio` are stale: old dns02 name, missing VLANs and hosts, AWX/watchtower era. Superseded by this folder | docs/diagrams |
| D3 | `docs/ansible.md` references a `caddy_proxy` role that doesn't exist | docs/ansible.md |
| D4 | `docs/ci-cd.md` says orchestrate-* branches trigger the pipeline; only `main` does | docs/ci-cd.md |
| D5 | `docs/dns02-komodo.md` (both repos) uses the `dns02/` path; the real path is `ns02/technitium/` | docs |
| D6 | Wrong comments in host_vars: 10.37.70.5 labelled "nginx-internal", .24 labelled "nginx-external", .7 labelled "nginx dmz", .21 labelled "Ansible controller" (it's Veeam) | `ansible/inventories/*/host_vars/` |
| D7 | Broken symlink `inventories/manual/group_vars/all.yml` → `../../../group_vars/all.yml` (that path is a directory named `all/`) | inventories/manual |
| D8 | `debian` group_vars exist, but no inventory defines a `debian` group, so `update_debian.yml` targets nothing | ansible/ |
| D9 | `hosts_registry.yml`: docker_secure is 10.37.70.2 (canonical mgmt is 10.37.10.2, admin is 10.37.20.2); ns02 and HAOS (10.37.70.20) are missing; "Prusa 3D Printer" description is wrong (it's a Nextcloud/SFTP host) | registry |
| D10 | Hostnames differ from inventory names: nginx → `nginx-dmz`, raspberrypi-ha → `ai`, vCenter VM `dns02` → ns02 | live |
| D11 | docker-stacks `ENVIRONMENT.md` versions are stale (komodo 2.2.0 → 2.3.4, renovate 43 → 44, …); it still mentions Loki and dead ports 3010/3600 | docker-stacks |
| D12 | `truenas_proxy.yml` targets a host `truenas-proxy` that is in no inventory | ansible/ |
| D13 | The vDS has unused "Stage" port groups (VLAN 120–170, 1100) | vCenter |
