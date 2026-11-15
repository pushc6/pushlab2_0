# push-lab architecture — AI context file

> Dense reference for LLM agents. Facts were verified on **2026-11-15** against the IaC repo, the `docker-stacks` repo, a live SSH survey and vCenter (read-only).
> Human-oriented versions with diagrams are in `docs/architecture/01-…10-*.md`. Known problems are in `findings.md`.
> Source tags: `[reg]` = `ansible/group_vars/all/hosts_registry.yml`, `[ds]` = `../docker-stacks`, `[live]` = SSH survey, `[vc]` = vCenter, `[iac]` = this repo.
> Secrets are never recorded here. Where a secret lives is noted as "Semaphore env", "Komodo env" or ".env".

## 0. Ground rules for agents
- Two repos:
  - `push-lab_2_0` (this repo) holds the VMs, OS, firewall, proxies and DNS config. Ansible runs from **Semaphore**, not from a laptop.
  - `docker-stacks` holds the compose stacks. **Komodo** deploys them on merge, and Renovate opens the PRs.
- SSH as `push@<ip>`; passwordless `sudo -n` works. Ansible connects as the `ansible` user. Default inventory is `inventories/prod/hosts.yml`, but Semaphore uses the whole `ansible/inventories/` directory.
- **Read §9 (traps) before you change anything.**

## 1. Physical / virtualization [vc][live]
| Item | Facts |
|---|---|
| vCenter | VCSA 8.0.2 (build 22385739), VM "VMware vCenter Server 8", 10.37.10.35, VLAN 10, on chonkyboi. Datacenter `Push Datacenter`, cluster `Lab Cluster` (2 hosts, vCLS present) |
| ESXi `chonkyboi.localdomain` | Dell, 2× Xeon Gold 6154 (36 logical @3.0 GHz), 256 GB RAM, ESXi 8.0.3 b24674464. 4× 10 GbE Intel X710 (i40en). vmk: 10.37.10.17 (mgmt, static), 10.37.70.31/.32, 10.37.30.42 (storage/iSCSI). **Hosts the NVIDIA Quadro P2000 passed to VM `Docker`** |
| ESXi `slimboi.localdomain` | Dell, 2× Xeon E5-2697A v4 (32 logical @2.6 GHz), 192 GB RAM, ESXi 8.0.3. 4× 10 GbE X710 + 1× 82599 (link down). vmk: 10.37.10.18 (mgmt), 10.37.70.29/.30, 10.37.30.41 |
| vDS | `DSwitch`. Port groups `VLAN <id> - <name>` for 10,20,30,40,50,60,70,80,99 (Internet/WAN),100,120–170 + 1100 (Stage, unused), plus ISCSI-PG1 / ISCSI-PG2 |
| Datastores | `ssd-local` VMFS 1.86 TB (1.41 free) = Terraform default; `ssd_local1` VMFS 1.79 TB (986 GB free); `NVMe1 Datastore` VMFS 699 GB (447 free; used by Docker); `datastore1` VMFS 95 GB; `FreeNas iscsi` VMFS 400 GB (272 free); `FreeNas iscsi2` VMFS 400 GB (228 free); `FreeNas 10GbE` NFS 35 TB (25.9 free) |
| TrueNAS | **Physical** box at 10.37.70.22 (no SSH, :22 refused). Pool `tank`. NFS exports: `/mnt/tank/Media`→10.37.70.7; `/mnt/tank/Docker`→70.0/24; `/mnt/tank/DockerInternal`→10.37.70.25; `/mnt/tank/VMStorage`→70.0/24,20.0/24; `/mnt/tank/VMStorage/STLs`→70.0/24. Also serves iSCSI LUNs and the 10 GbE NFS datastore to ESXi |
| Synology `push-nas` | 10.37.20.4 (VLAN 20). NFS exports: `/volume1/digx`→.25, `/volume1/Backup`→.7,.11, `/volume1/Docker`→.7, `/volume1/ESXi`→.10. Model: TODO(owner) |
| Raspberry Pi 4B | `raspberrypi-ha`, hostname `ai`, 10.37.50.12 over **WiFi** (eth0 down), Debian 12 arm64. USB: Sonoff Zigbee 3.0 Dongle Plus (`/dev/ttyUSB0`), Z-Wave stick (`/dev/zwave`) |
| Raspberry Pi Zero 2 W | `cupsserver` 10.37.50.9, WiFi, CUPS :631 + avahi |
| VPS | RackNerd KVM `racknerd-5d374f3`, public 192.210.235.136, AlmaLinux 9.8, 6 vCPU / 7.5 GB / 144 GB. Tailscale 100.78.119.4 |
| UPS | Monitored by NUT `nut-upsd` (container on docker-internal :3493) + PeaNUT. Model and driver are in host `/srv/docker/peanut/nut-config`. Model: TODO(owner) |
| Unknown | Physical switch, APs, ISP/modem, rack: TODO(owner). OPNsense **is a VM** (see §2) |

### VM inventory [vc] (vCPU / RAM GB / ESXi / datastore / port groups)
| VM name (vCenter) | Inventory host | vCPU | RAM | ESXi | Datastore(s) | NICs |
|---|---|---|---|---|---|---|
| opnSense | opnsense | 6 | 16 | chonkyboi | FreeNas iscsi | 10 NICs: VLAN 99 (WAN), 20,10,30,40,50,60,70,100,80 |
| Docker | docker | 12 | 60 | chonkyboi | ssd_local1, NVMe1 | VLAN 70 (+GPU passthrough) |
| NGINX | nginx (nginx-dmz) | 4 | 6 | chonkyboi | ssd_local1 | VLAN 70 |
| GameServer | linuxgameserver | 8 | 16 | chonkyboi | ssd_local1 | VLAN 70 |
| Veeam2022 | (Windows, not in inventory) 10.37.70.21 | 8 | 24 | chonkyboi | FreeNas iscsi, ssd_local1 | VLAN 10, 70 |
| VMware vCenter Server 8 | — | 6 | 24 | chonkyboi | ssd_local1 | VLAN 10 |
| Docker - Internal | docker-internal | 8 | 16 | slimboi | ssd-local | VLAN 10, 70 |
| Docker - Secure | docker-secure (ns01) | 6 | 16 | slimboi | FreeNas iscsi, iscsi2 | VLAN 20,10,30,40,50,60,70,100,80 |
| dns02 | ns02 | 2 | 8 | slimboi | ssd-local | 9 NICs (10,20,30,40,50,60,70,80,100) |
| gitea | gitea | 8 | 12 | slimboi | ssd-local | VLAN 80 |
| packer_builder | packer_builder | 12 | 18 | slimboi | ssd-local | VLAN 80 |
| NGINX - Internal | nginx-internal | 2 | 16 | slimboi | ssd-local | VLAN 70 |
| Crowdsec | crowdsec | 8 | 2 | slimboi | ssd-local | VLAN 70 |
| prusa3dbawkz | prusa3dbawkz | 8 | 16 | slimboi | ssd-local, FreeNas iscsi | VLAN 70 |
| HomeAssistant | HAOS 10.37.70.20 (not in Ansible) | 4 | 12 | slimboi | FreeNas iscsi2 | VLAN 70 |
| almalinux-10-minimal-template (+3 older templates) | Packer output | 2 | 4 | slimboi | ssd-local | VLAN 80 |

Terraform manages only gitea, dns02/ns02 and packer_builder (`terraform/envs/prod/prod.tfvars`). Every other VM is hand-built ("manual").

## 2. Network [iac][live][vc]
- Addressing: each VLAN is `10.37.<VLAN>.0/24`, gateway `.1` (OPNsense), IPv6 ULA `fd00:1337:1337:<VLAN>::/64`. VLAN 80 also has GUA `2600:2b00:7938:ef80::/64`.
- Hosts on many VLANs use a fixed last octet everywhere: ns01 = `.2`, ns02 = `.254`.

| VLAN | Name | OPNsense if | Purpose / notable members |
|---|---|---|---|
| 10 | Management | opt1 | No WAN. ESXi vmk .17/.18, vCenter .35, ns01 .2 (canonical mgmt IP **10.37.10.2**), docker-internal .42 (2nd NIC), ns02 .254 |
| 20 | Trusted | opt2 | Admin workstations (e.g. 10.37.20.41), Synology .4. **Admins reach ns01 at 10.37.20.2 and ns02 at 10.37.20.254** |
| 30 | Storage | opt3 | iSCSI/NFS vmk (.41/.42) |
| 40 | LAN Only (No WAN) | — | isolation |
| 50 | IoT | opt5 | raspberrypi-ha .12, cupsserver .9, scrypted .23 (scrypted.localdomain, not in inventory) |
| 60 | Guest | opt6 | — |
| 70 | DMZ | opt7 | Most servers: .2 ns01, .5 nginx-dmz, .7 docker, .19 gameserver, .20 HAOS, .21 Veeam, .22 TrueNAS, .24 nginx-internal, .25 docker-internal, .26 crowdsec, .28 prusa3dbawkz, .254 ns02 |
| 80 | App | opt9 | Terraform VMs: .4 gitea, .5 packer_builder; ns01 .2 and ns02 .254 **use this VLAN for their default gateway** |
| 90 | WireGuard VPN | opt8 | Remote access; allowed SSH everywhere |
| 99 | Internet | wan | WAN port group into OPNsense (backup WAN = opt4, group `WAN_Interfaces`) |
| 100 | Test | — | — |
| 120–170, 1100 | Stage | — | port groups exist in vDS, unused |

- **OPNsense** (VM): managed through its API by `ansible/opnsense.yml`, role `opnsense_firewall`, collection `ansibleguy.opnsense`, vars `ansible/group_vars/opnsense/vars.yml`.
  - IaC-managed rules: Semaphore→gitea/packer/ns02/Pi/cups on 22 and 3000; packer_builder→vCenter 443; Komodo Core→Pi :8120; Pi→nginx-internal 443; DMZ→IoT :8120.
  - **NAT / port forwards are hand-managed and not in IaC.** Public 80/443/8883 → nginx-dmz 10.37.70.5; 7777 → gameserver. TODO(owner): export them.
- **Tailscale** tailnet `crane-beaver.ts.net`, auth keys minted with OAuth:
  - crowdsec 100.91.248.91 (`tag:crowdsec-lapi`)
  - docker-internal 100.107.104.49 (`tag:komodo-core`), **subnet route 10.37.70.24/32**
  - rangernet-vps 100.78.119.4 (`tag:crowdsec-agent`, `tag:komodo-periphery`), accept-routes
- Host firewall is role `firewall_hardened` (firewalld, rich rules). **Docker-published ports bypass firewalld.** On docker, docker-internal and prusa the zone has no interfaces, so nothing is filtered at the host.

## 3. DNS / DHCP [iac][ds]
- **ns01** is the Technitium container on docker-secure (host network, :53, :67, web :5380). It is SOA primary and the active DHCP server (8 scopes). Komodo stack `technitium-ns01`; image `technitium/dns-server:latest` pinned by digest.
- **ns02** is the Technitium container on VM `dns02` (hostname `ns02.localdomain`, AlmaLinux 10.2). It is a secondary that receives zone transfers from ns01. Its DHCP scopes mirror ns01 but are disabled; they are standby with a 5000 ms offer delay plus a reservation-sync timer. Komodo stack `technitium-ns02`; config in `/opt/technitium/config`.
- Zones:
  - `localdomain` is authoritative; `technitium_dns.zone`; records-as-code via `hosts_registry.yml`.
  - Forwarder/split-horizon zones: push-lab.com, ryanpampush.com, patreons7.club, rangernet.dev (records hand-maintained in Technitium; `public_dns_records` documents them but no playbook applies it).
  - Reverse zones for each VLAN.
- Upstream: ControlD 76.76.2.198 / 76.76.10.198. Query logs go as syslog to Alloy 10.37.70.25:1514.
- Ansible: `ansible/technitium.yml` (Semaphore project 1, template 13). API tokens are Semaphore env `TECHNITIUM_API_TOKEN_NS0X`.
- Public DNS (Cloudflare) plus split-horizon internal A records:
  - **nginx-internal (10.37.70.24):** code, dashboard, digx, dozzle, git, grafana, lidarr, prusabawt, radarr, readarr, sab, semaphore, sonarr, syno, truenas, zigbee, zwave (all `.push-lab.com`), mqtt.rangernet.dev
  - **nginx-dmz (10.37.70.5):** auth, cargame-dev, invite, n8n, plex (`.push-lab.com`); cloud, plex, request (`.ryanpampush.com`); nc.patreons7.club
  - **direct:** ha → 10.37.70.20, satisfactory → .19, sso → .7, teslamate.ryanpampush.com → .7, logs.rangernet.dev → .25

## 4. Hosts [live][reg][iac]
| Host (inventory) | Primary IP | OS | vCPU/RAM | Purpose | Managed by | Komodo |
|---|---|---|---|---|---|---|
| docker | 10.37.70.7 | Ubuntu 24.04 | 12/58G | Media + apps, GPU (P2000), Keycloak | manual | server `6a2e1aab9b9bab33873ada80` |
| docker-internal | 10.37.70.25 (+10.37.10.42) | Ubuntu 24.04 | 8/15G | Platform: Komodo Core, Semaphore, observability, MQTT, oauth2-proxy, Immich | manual | `6a2d6968…` (Core) |
| docker-secure | 10.37.10.2 (mgmt), 10.37.20.2 (admin), .2 on every VLAN; gw 10.37.80.1 | Ubuntu 24.04 | 6/15G | ns01 Technitium DNS+DHCP | manual | `6a2ed40f…` |
| ns02 (vm `dns02`) | .254 on VLANs 10–100; Ansible `10.37.70.254`; reachable from VLAN 20 at 10.37.20.254; gw 10.37.80.1 | AlmaLinux 10.2 | 2/8G | ns02 secondary DNS + standby DHCP | Terraform | `6a9eecc0…` |
| gitea | 10.37.80.4 | AlmaLinux 10.2 | 8/11G | Gitea 1.24.x (sqlite, :3000, ssh :2222), registry, act_runner `alma` (container `gitea-runner`) | Terraform (prevent_destroy) | (Periphery via docker_hosts) |
| packer_builder | 10.37.80.5 | AlmaLinux 10 | 12/18G | Native runner label `packer-vm`; Packer 1.11.2, TF 1.7.5 | Terraform | — |
| nginx (hostname `nginx-dmz`) | 10.37.70.5 | RHEL 9.9 | 4/5.5G | Public reverse proxy :80/:443/:8883, postfix :25 | manual | — |
| nginx-internal | 10.37.70.24 | RHEL 9.9 | 2/15G | Internal reverse proxy :80/:443, git SSH stream :2222, MQTTS :8883 | manual | — |
| crowdsec | 10.37.70.26 | Ubuntu 24.04 | 8/1.9G | CrowdSec LAPI :8080 (Postgres), metrics :6060 | manual | — |
| raspberrypi-ha (hostname `ai`) | 10.37.50.12 | Debian 12 arm64 | 4/3.7G | zigbee2mqtt :8080, zwavejs :8091/:3000 | manual | `6a2f6006…` |
| cupsserver | 10.37.50.9 | Debian 12 (Pi Zero 2 W) | 4/0.4G | CUPS :631 | manual | — |
| linuxgameserver | 10.37.70.19 | Ubuntu 24.04 | 8/15G | CubeCoders AMP :8080, Satisfactory 7777/udp, /backups 393G | manual | — |
| prusa3dbawkz | 10.37.70.28 | Ubuntu 24.04 | 8/15G | Nextcloud AIO (:11000), SFTPGo :2022/:8081, STL NFS | manual | — |
| rangernet-vps | 192.210.235.136 / ts 100.78.119.4 | AlmaLinux 9.8 | 6/7.5G | Public nginx, uptime-kuma (uptime.push-lab.com), crowdsec agent | manual (vps.yml) | Periphery on tailnet :8120 |
| HAOS (not in Ansible) | 10.37.70.20 | Home Assistant OS | 4/12G | Home Assistant (ha.push-lab.com) | appliance | — |
| Veeam (not in Ansible) | 10.37.70.21 | Windows Server 2022 | 8/24G | Veeam B&R | manual | — |
| opnsense | 10.37.X.1 | OPNsense (FreeBSD 14) | 6/16G | Router/firewall/NAT | API (`opnsense.yml`) | — |

Ansible roles (site.yml):
- **all:** `system_users`, `network_interfaces`, `firewall_hardened`, `tailscale`*, `crowdsec`* (*only where enabled), updates (`update_all.yml`: crowdsec and ns02 first, docker-internal **last**)
- **docker_hosts:** `docker`
- **dockerhost:** `docker_daemon`
- **docker_internal:** `nfs_client`
- **gitea:** `mount_data_disk`, `system_hostname`, `gitea`
- **ns02:** `technitium`
- **Periphery hosts:** `komodo_periphery` (`komodo-periphery.yml`)
- **proxies:** `enhanced_proxy_nginx` (`deploy_proxy_enhanced.yml`), `oauth2_proxy_nginx`, `acme_sh` + MQTT stream (`deploy_mqtt_proxy.yml`)

## 5. Services by host [ds][live]
Pinning: `image:tag@sha256` (Renovate). Ports are host ports. Storage tiers: `san` = NFS `/srv/docker/san/<stack>` on TrueNAS; `local` = `/srv/docker/<stack>` or `/opt/dockerconfigs/<stack>`; `git` = config in the repo.

**docker (10.37.70.7)**, data in `/opt/dockerconfigs/<stack>`, media `/nfs/media`:
| Stack | Services and ports |
|---|---|
| plex | Plex, host network :32400, nvidia runtime, `/transcode` |
| arr | prowlarr 9696, nzbhydra2 5076, sabnzbd 8085, radarr 7878, sonarr 8989, lidarr 8686, profilarr 6868 |
| media helpers | bazarr 6767, tautulli 8181, seerr 5055, wizarr 5690, maintainerr 6246, notifiarr 5454, tdarr 8265/8266 (GPU), nexroll (host network :9393), media_notifier 8088 |
| keycloak | Keycloak 8082 + postgres 18 → auth.push-lab.com, realm `prod` |
| other apps | n8n 5678, homepage 3002, dashy 8280, code-server 8443, dozzle 9999, changedetection 5000, apprise-api 8000, microbin 8081, flaresolverr 8191, smokeping 8281, openspeedtest 3006/3007, isponsorblocktv, fileshare ssh-readonly 2322 |
| teslamate | teslamate 4000, grafana 3001, pgadmin 8888/8889, own mosquitto (unpublished), postgres on `/nfs/teslamate` |
| non-container | dockerd TLS API **:2376**, metrics :9323; Veeam agent 6160/6162/10808 |

**docker-internal (10.37.70.25)**:
| Stack | Services and ports |
|---|---|
| komodo | Core :9120 + mongo 8.3 → komodo.push-lab.com |
| semaphore | host network :3004, SQLite → semaphore.push-lab.com |
| observability | grafana :3002 (san, Keycloak OAuth) → grafana.push-lab.com; victoriametrics :8428 (also 8089, 2003, 4242); victorialogs :9428 (san, 30d) → logs.rangernet.dev; alloy syslog :1514 tcp/udp, UI :12345; influxdb2 :8086 (san) |
| mqtt | mosquitto :1883 (behind MQTTS :8883 on both proxies; host mqtt.rangernet.dev) |
| auth | oauth2-proxy :4180 (keycloak-oidc, cookie domain `.push-lab.com`) |
| immich | :2283 → digx.push-lab.com; library on NFS `10.37.20.4:/volume1/digx` → `/var/digx` |
| peanut | PeaNUT :8080 + nut-upsd :3493 → Influx bucket SensorData |
| apps | tracearr :3005 (+timescale, redis) → tracearr.push-lab.com; cargame :3000 → cargame-dev / zero.push-lab.com (+postgres, nightly backup); wolfbawt web :8000 + postgres **:5432 on 0.0.0.0** → wolfbawt.push-lab.com |
| misc | caddy :8180 (landing pages for push-lab.com, ryanpampush.com, rangernet.dev); csadmin (crowdsec-api-manager) :5000; dozzle :9999; renovate (run-once, hourly Komodo procedure `renovate-nightly`) |
| not deployed | komodo-apprise-alerter, prusabawt |

**Other hosts**:
| Host | Services |
|---|---|
| docker-secure | technitium-ns01 |
| ns02 | technitium-ns02 |
| raspberrypi-ha | zigbee2mqtt 2.14.2, zwavejs2mqtt 11.25.0 |
| rangernet-vps | uptime-kuma 2 (127.0.0.1:3001) |
| prusa3dbawkz | Nextcloud AIO (7 containers, not in docker-stacks), sftpgo |
| gitea | gitea-runner container |

Every Komodo-managed host runs `komodo-periphery` 2.3.4 on :8120.

## 6. Ingress / auth / TLS [live][iac]
Ingress chains:
- **Public:** Internet → (Cloudflare DNS; proxied status per record: TODO(owner)) → OPNsense WAN NAT → **nginx-dmz 10.37.70.5** :443/:8883 → backend.
  Upstreams:
  | Host | Backend |
  |---|---|
  | auth | .7:8082 (Keycloak) |
  | invite | .7:5690 |
  | n8n | .7:5678 |
  | plex.push-lab.com, plex.ryanpampush.com | .7:32400 |
  | request.push-lab.com | .7:5055 |
  | request.ryanpampush.com | .7:5055 (+ stale 3579) |
  | speedtest | .7:3006 |
  | sso | .7:4180 (nothing listens) |
  | amp | .19:8080 |
  | nc.patreons7.club, bigfile.patreons7.club | .28:11000 |
  | cargame-dev | .25:3000 |
  | wolfbawt | .25:8000 |
  | medianotifier | .7:8088 |
  | apex domains | .25:8180 (caddy) |
  | MQTTS :8883 | .25:1883 |
- **Internal:** client on VLAN 20 → split-DNS → **nginx-internal 10.37.70.24** :443.
  - Default `proxy_mode: oauth2`: nginx `auth_request` → oauth2-proxy .25:4180 → Keycloak realm `prod` (group-gated, e.g. dozzle `admin,devops`).
  - OAuth2 vhosts: sonarr, radarr, lidarr, code, dozzle.
  - Traditional vhosts: dashboard, truenas, grafana (own OAuth), semaphore, komodo, tracearr, synology, prusabawt, medianotifier, git, sab, readarr, digx, zigbee, zwave, scrypted (→ 10.37.50.23:10443), zero.
  - Also git SSH stream :2222 → 10.37.80.4:2222, and MQTTS :8883 → .25:1883.
- **VPS:** nginx :443 serves uptime.push-lab.com → localhost:3001. Komodo Core reaches the VPS Periphery over Tailscale. The VPS reaches internal Gitea through the subnet route to 10.37.70.24.
- **TLS:** `acme.sh` + Let's Encrypt, DNS-01 through Cloudflare (`dns_cf`; Semaphore env `ACME_CF_*`). Wildcards live at `/etc/nginx/ssl/<domain>`; default key is ec-256, push-lab.com on nginx-internal is RSA-4096. **Only rangernet.dev is issued by Ansible**; the rest were issued by hand on the hosts.
- Proxy config: `group_vars/nginx_internal/proxy_vars_enhanced.yml`, `oauth2_vars.yml`, `group_vars/nginxdmz/proxy_vars_enhanced.yml` (that file defines only cargame-dev and medianotifier; **all other DMZ vhosts are hand-managed**), `group_vars/reverse_proxies/mqtt.yml`.

## 7. Data / storage / backup
| Mount | Host:path | Source |
|---|---|---|
| media | docker:`/nfs/media` | TrueNAS `/mnt/tank/Media` (53 TB, 53% used) |
| docker (unused) | docker:`/nfs/docker` | TrueNAS `/mnt/tank/Docker` |
| teslamate | docker:`/nfs/teslamate` | NAS (TODO confirm export) |
| san tier | docker-internal:`/srv/docker/san` | TrueNAS `/mnt/tank/DockerInternal`, root_squash → write as `dockeruser` uid 1006 |
| digx | docker-internal:`/var/digx` | Synology `/volume1/digx` |
| STLs | prusa3dbawkz:`/storage` | TrueNAS `/mnt/tank/VMStorage/STLs` |
| local disks | docker:`/downloads` (246G NVMe), `/transcode` (98G); gitea:`/var/lib/gitea` (50G xfs data disk); gameserver:`/backups` (393G) | — |

Rules:
- DBs and root-running containers stay on the local tier. Only uid-1006 non-DB data goes on san. Runbook: `docker-stacks/docs/host-storage-migration.md`.

Backups:
- Veeam B&R (10.37.70.21) with agents (Veeam ports opened globally by `group_vars/all/main.yml`). Synology `/volume1/Backup` is exported to .7 and .11.
- Terraform state on Backblaze B2 (S3 API), bucket `pushlabterraformstate`, keys `prod/` and `lab/`, **no locking**. Gitea release snapshots per apply.
- cargame nightly pg dump (03:15, 14d). Gitea pre-upgrade dump to `/var/backups`.

## 8. Automation / GitOps
**IaC pipeline** (`.gitea/workflows/orchestrate-push.yaml`, push to `main`, concurrency "production"):
1. Path filter.
2. ansible-lint.
3. Packer build if `packer/**` changed (runner `packer-vm`).
4. `terraform plan/apply` on prod if TF or Packer changed (runner `alma`, image `almalinux-cicd`).
5. Snapshot to a Gitea release.
6. Semaphore API trigger (template from `SEMAPHORE_TEMPLATE_ID`).

Other workflows:
| Workflow | What it does |
|---|---|
| orchestrate-dispatch | manual |
| prod-drift-check | daily 03:00 → Discord/PagerDuty |
| rebuild-packer-images | rebuilds the Packer template |
| redeploy-vm | `-target` apply |
| ansible-lint, terraform-lint | lint |
| build-ee | `git.push-lab.com/<owner>/ansible-ee` |
| build-ci-image | registry push disabled |

Pipeline details:
- Terraform `local_file` regenerates `ansible/inventories/prod/hosts.yml`.
- Pre-commit runs gitleaks, terraform fmt and `scripts/sync-inventory-symlinks.sh`.
- Packer template `almalinux-10-minimal-template`: AlmaLinux 10.1 ISO, EFI, 2 vCPU / 4G / 40G, VLAN 80, kickstart over HTTP :8080. Cloned by `terraform/modules/vm` with cloud-init (VMware datasource, netplan v2, static MAC).

**Containers** (`docker-stacks`, Gitea repo `rangernet/docker-stacks` at 10.37.80.4):
1. Renovate (Komodo procedure, hourly) opens PRs. Digest and minor/patch updates on "trusted stacks" automerge; majors need dashboard approval; minimumReleaseAge is 3d.
2. On merge, a Gitea webhook → nginx-internal → `komodo.push-lab.com/listener/github/stack/<name>/deploy`.
3. Komodo Core → Periphery :8120 (PKI; Core pubkey in `group_vars/all` `komodo_periphery_core_public_keys`) → `compose up`.
4. Rollback = revert the PR.

**Semaphore** (docker-internal :3004):
- Inventory is the whole `ansible/inventories/` dir. Runs site.yml, update_all.yml, technitium.yml, opnsense.yml, firewall, onboard, and so on.
- Secrets in Semaphore env: OPNsense API key, CF token, Technitium tokens, `KOMODO_PASSKEY` (legacy).

## 9. Invariants & traps (READ BEFORE CHANGING)
1. **host_vars symlink trap:**
   - Semaphore reads top-level `ansible/inventories/host_vars/`, which should hold symlinks into `manual/` or `prod/`.
   - A stale regular-file copy there silently shadows edits. The sync script only creates a symlink when the file is absent.
   - Check with `ls -l` before editing host_vars.
2. **ns02 NIC order:**
   - Adding a NIC to a multi-homed VM breaks cross-VLAN reachability (strict rp_filter).
   - Always **append** NICs; never insert one mid-list. The DMZ NIC must stay last in `prod.tfvars`.
3. **NFS san tier root_squash:** create and copy files as `dockeruser` (uid 1006), never as root.
4. **Semaphore runs on docker-internal:**
   - A docker-ce upgrade or reboot there kills the Semaphore job that triggered it.
   - `update_all.yml` handles this: docker-internal goes last and `debian_updates_deferred_packages` uses a systemd-run timer.
   - A full `site.yml` or a docker role run can still kill its own job.
5. **Komodo Core self-redeploy:**
   - Core is itself a Komodo stack (`komodo`), so its redeploy always logs "failed".
   - Verify Core's health instead of trusting the status. Komodo is v2.x with PKI auth (passkey dropped).
6. **enhanced_proxy:**
   - The role hardcodes a `/health` "OK" stub on every vhost, which shadows any app's own `/health` (e.g. tracearr).
   - **Never deploy with `-e proxy_mode=traditional`**: it deletes the shared oauth2 configs that the oauth2-mode vhosts include.
   - Vhosts dropped from the service list are **not** removed automatically. List them in `enhanced_proxy_nginx_retired_domains` (nginx_internal group_vars). `public_dns_records` is documentation only: no playbook applies it, so delete Technitium records by hand.
7. **Docker bypasses firewalld:**
   - A published port is reachable from the whole L2/L3 path that OPNsense allows.
   - Bind sensitive ports to 127.0.0.1 or a specific IP.
8. **Firewall and gitea roles refuse to run from a laptop.** Run them through Semaphore.
9. **docker-stacks rules:**
   - Never put `=` inside `${}` default values.
   - Avoid relative bind mounts; they break Komodo deploys.
   - Use bare Docker Hub names for LinuxServer images (ghcr returns no-result errors in Renovate).
10. **Komodo on the public VPS:**
    - Periphery clones internal Gitea through the Tailscale subnet route.
    - The VPS needs accept-routes, firewalld trusted-zone **masquerade**, and periphery `extra_hosts` mapping git.push-lab.com → 10.37.70.24.
    - `dash` has no `/dev/tcp`, so reachability tests built on it give false negatives.
11. **docker-secure's own resolver:** it resolves through itself, so Periphery needs `komodo_periphery_dns: [10.37.70.2]`.
12. **ns02 management IP:**
    - Ansible uses 10.37.70.254. From the admin VLAN 20, only 10.37.20.254 answers SSH; asymmetric routing on a multi-homed host.
    - Test from the same VLAN as the source.

## 10. Where to change things
| Change | File |
|---|---|
| Add/rename host IP, DNS record | `ansible/group_vars/all/hosts_registry.yml` → run technitium.yml |
| New VM | `terraform/envs/prod/prod.tfvars` (+ module `terraform/modules/vm`) → PR to main |
| Host firewall | `ansible/inventories/*/host_vars/<host>.yml` (`firewall_hardened_*`) via Semaphore |
| OPNsense rule/alias | `ansible/group_vars/opnsense/vars.yml` → `opnsense.yml` |
| Internal vhost | `ansible/group_vars/nginx_internal/proxy_vars_enhanced.yml` → `deploy_proxy_enhanced.yml` |
| DMZ vhost | `ansible/group_vars/nginxdmz/proxy_vars_enhanced.yml` (most existing ones are hand-managed on the host) |
| Container change | `docker-stacks/<host>/<stack>/compose` → PR → Komodo webhook |
| Add Komodo host | `komodo-periphery.yml` + register server (see memory/runbook `docs/dns02-komodo.md`) |
