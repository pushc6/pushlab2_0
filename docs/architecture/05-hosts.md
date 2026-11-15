# 5. Hosts

One card per machine. vCPU and RAM numbers are what the guest sees (live). **Managed by** says how the machine is built:
- **Terraform**: built by IaC from the Packer template
- **manual**: hand-built, configured by Ansible
- **appliance**: not managed by Ansible

## Summary

| Host | IP | VLAN | OS | vCPU / RAM | ESXi | Managed by | Purpose |
|---|---|---|---|---|---|---|---|
| opnsense | 10.37.X.1 | all + WAN | OPNsense | 6 / 16 GB | chonkyboi | appliance (API rules via Ansible) | Router, firewall, NAT, WireGuard |
| docker | 10.37.70.7 | 70 | Ubuntu 24.04 | 12 / 58 GB | chonkyboi | manual | Media + apps, Keycloak, GPU |
| docker-internal | 10.37.70.25 | 70 (+10) | Ubuntu 24.04 | 8 / 15 GB | slimboi | manual | Platform services |
| docker-secure (ns01) | 10.37.10.2 / 10.37.20.2 | all | Ubuntu 24.04 | 6 / 15 GB | slimboi | manual | Primary DNS/DHCP |
| ns02 | .254 (Ansible 10.37.70.254) | all | AlmaLinux 10.2 | 2 / 7.5 GB | chonkyboi | Terraform | Secondary DNS/DHCP |
| gitea | 10.37.80.4 | 80 | AlmaLinux 10.2 | 8 / 11 GB | slimboi | Terraform | Git, registry, CI runner |
| packer_builder | 10.37.80.5 | 80 | AlmaLinux 10 | 12 / 18 GB | slimboi | Terraform | Packer/TF runner |
| nginx (nginx-dmz) | 10.37.70.5 | 70 | RHEL 9.9 | 4 / 5.5 GB | chonkyboi | manual | Public reverse proxy |
| nginx-internal | 10.37.70.24 | 70 | RHEL 9.9 | 2 / 15 GB | slimboi | manual | Internal reverse proxy + SSO |
| crowdsec | 10.37.70.26 | 70 | Ubuntu 24.04 | 8 / 1.9 GB | slimboi | manual | CrowdSec LAPI |
| linuxgameserver | 10.37.70.19 | 70 | Ubuntu 24.04 | 8 / 15 GB | chonkyboi | manual | AMP + Satisfactory |
| prusa3dbawkz | 10.37.70.28 | 70 | Ubuntu 24.04 | 8 / 15 GB | slimboi | manual | Nextcloud AIO, SFTPGo |
| HomeAssistant | 10.37.70.20 | 70 | HAOS | 4 / 12 GB | slimboi | appliance | Home Assistant |
| Veeam2022 | 10.37.70.21 | 70 (+10) | Windows Server 2022 | 8 / 24 GB | chonkyboi | manual (not Ansible) | Veeam B&R |
| vCenter | 10.37.10.35 | 10 | VCSA 8.0.2 | 6 / 24 GB | chonkyboi | appliance | vSphere management |
| raspberrypi-ha (`ai`) | 10.37.50.12 | 50 | Debian 12 arm64 | 4 / 3.7 GB | Pi 4B | manual | Zigbee/Z-Wave → MQTT |
| cupsserver | 10.37.50.9 | 50 | Debian 12 | 4 / 0.4 GB | Pi Zero 2 W | manual | CUPS |
| rangernet-vps | 192.210.235.136 | public | AlmaLinux 9.8 | 6 / 7.5 GB | RackNerd | manual (vps.yml) | Public nginx, uptime-kuma |

---

### docker — 10.37.70.7
- **Role:** main application host. Runs the media stack (Plex, *arr, Tdarr), Keycloak SSO, n8n, dashboards, TeslaMate and dev tools. About 37 containers.
- **Hardware:**
  - NVIDIA Quadro P2000 passthrough (Plex/Tdarr NVENC).
  - Disks: `/` 110 GB, `/downloads` 246 GB on NVMe datastore, `/transcode` 98 GB.
- **Mounts:** `/nfs/media` (TrueNAS `/mnt/tank/Media`, 53 TB), `/nfs/docker` (unused), `/nfs/teslamate`.
- **Non-container listeners:** dockerd TLS API :2376, Docker metrics :9323, Veeam agent, CrowdSec agent :6060.
- **Ansible:** common, `docker_daemon`, firewall_hardened, crowdsec agent, updates, komodo_periphery.
- **Komodo:** server `6a2e1aab9b9bab33873ada80`, about 26 stacks.
- **Notes:** kernel 6.8.0-59 is behind the other hosts (-149), so a reboot is pending. The firewalld zone has no interfaces.

### docker-internal — 10.37.70.25 (+ 10.37.10.42), Tailscale 100.107.104.49
- **Role:** platform host: Komodo Core, Semaphore, Grafana, VictoriaMetrics/Logs, Alloy, InfluxDB, Mosquitto, oauth2-proxy, Immich, NUT/PeaNUT, Caddy landing pages, tracearr, cargame, wolfbawt. About 29 containers.
- **Mounts:** `/srv/docker/san` (TrueNAS `/mnt/tank/DockerInternal`, root_squash) and `/var/digx` (Synology).
- **Tailscale:** subnet router for 10.37.70.24/32 (`tag:komodo-core`).
- **Ansible:** common, `nfs_client`, firewall, tailscale, updates (**always last**: it hosts Semaphore), komodo_periphery.
- **Notes:** two default routes, `systemd-resolved` failed, firewalld zone has no interfaces. A planned move to VLAN 80 (10.37.80.6) is in `docs/migration-plan-docker-internal-vlan80.md` (not executed).

### docker-secure (ns01) — 10.37.10.2 mgmt / 10.37.20.2 admin
- **Role:** primary Technitium DNS + DHCP. It has a leg on every VLAN so it can serve DHCP without relays. Gateway 10.37.80.1.
- **Storage:** boots from TrueNAS iSCSI datastores.
- **Firewall:** dns, dhcp and 5380 allowed. **Ansible:** common, firewall, updates, komodo_periphery.

### ns02 — .254 on every VLAN
- **Role:** secondary DNS + standby DHCP. Built by Terraform (key `dns02`, VM name `dns02`); 2 vCPU / 8 GB / 40 GB on chonkyboi's local `ssd_local1` (per-VM `datastore` override in `prod.tfvars`), so it survives a TrueNAS outage and is on a different host from ns01.
- **Ansible:** common, docker, firewall, `system_hostname`, `technitium`, updates (first), komodo_periphery.
- **Notes:**
  - NIC ordering is fragile; see [network](03-network.md#multi-homed-hosts).
  - Reachable from VLAN 20 at 10.37.20.254; Ansible/Semaphore use 10.37.70.254.
  - Uptime was 0 h when surveyed (it rebooted at 15:01 on 2026-11-15).

### gitea — 10.37.80.4
- **Role:** Gitea 1.24.x on SQLite (HTTP :3000, SSH :2222), container registry (`git.push-lab.com/...`), Actions runner `alma` (container `gitea-runner`, image `gitea-act-runner:local`).
- **Sizing:** Terraform 4 vCPU / 6 GB in tfvars, but the guest shows 8 vCPU / 11 GB, so it was resized by hand (drift). 40 GB OS + 50 GB xfs data disk at `/var/lib/gitea`; `prevent_destroy`.
- **Exposure:** through nginx-internal: git.push-lab.com (HTTPS) and :2222 stream (SSH).
- **Notes:** root filesystem 70% full. Gitea's disk has filled up before (HANDOFF.md).

### packer_builder — 10.37.80.5
- **Role:** native Gitea runner label `packer-vm`. Packer 1.11.2 and Terraform 1.7.5 run on the host.
- **Sizing:** vCenter shows 12 vCPU / 18 GB, but tfvars says 4 / 8 GB (drift).
- **Access:** OPNsense allows → vCenter :443.
- **Ansible:** `packer-builder.yml` (not part of site.yml).

### nginx (nginx-dmz) — 10.37.70.5
- **Role:** public reverse proxy. nginx :80/:443/:8883 (MQTTS stream), postfix :25, CrowdSec agent + nftables bouncer.
- **OS:** RHEL 9.9; the hostname reports `nginx-dmz`.
- **IaC coverage:** only 2 vhosts are in IaC; the rest are hand-managed. See [ingress](07-ingress-auth-tls.md).

### nginx-internal — 10.37.70.24
- **Role:** internal reverse proxy with Keycloak/oauth2-proxy SSO. Also the git SSH stream :2222 and MQTTS :8883.
- **Reachability:** the target of Tailscale subnet route /32 (VPS → Gitea).
- **Ansible:** `deploy_proxy_enhanced.yml`, `deploy_oauth2_proxy.yml`, `deploy_mqtt_proxy.yml`.

### crowdsec — 10.37.70.26, Tailscale 100.91.248.91
- **Role:** CrowdSec LAPI :8080 on PostgreSQL, Prometheus metrics :6060.
- **Firewall:** only Tailscale 41641/udp opened explicitly.
- **Notes:** **1.9 GB RAM** (vCenter: 2 GB). Tight for Postgres + LAPI.

### linuxgameserver — 10.37.70.19
- **Role:** CubeCoders AMP (:8080, exposed as amp.push-lab.com via nginx-dmz) and a Satisfactory dedicated server (7777/udp, 8888); satisfactory.push-lab.com resolves directly to .19.
- **Storage:** `/backups` 393 GB.
- **Docker:** installed but unused.

### prusa3dbawkz — 10.37.70.28
- **Role:** despite the name, a file and cloud host. Nextcloud AIO (7 containers; served as nc / bigfile.patreons7.club via nginx-dmz → :11000) and SFTPGo (:2022 SFTP, :8081 web).
- **Mounts:** `/storage` = TrueNAS `/mnt/tank/VMStorage/STLs`.
- **Notes:** root filesystem 65% full. Not under Komodo (Nextcloud AIO manages itself).

### raspberrypi-ha (hostname `ai`) — 10.37.50.12
- **Role:** Zigbee2MQTT and Z-Wave JS UI. Publishes to Mosquitto on docker-internal; Home Assistant (HAOS VM) consumes from there.
- **Connectivity:** **Wi-Fi only** (eth0 down). Komodo Core reaches its Periphery on :8120 (OPNsense rule).
- **Exposure:** zigbee.push-lab.com and zwave.push-lab.com through nginx-internal.

### cupsserver — 10.37.50.9
- Pi Zero 2 W running CUPS :631 + avahi (mDNS). Wi-Fi.

### rangernet-vps — 192.210.235.136 / Tailscale 100.78.119.4
- **Role:** off-site box. nginx :80/:443 (uptime.push-lab.com → uptime-kuma), CrowdSec agent + bouncer → LAPI over Tailscale, Komodo Periphery bound to its tailnet IP :8120.
- **Firewall:** strict allowlist (ssh, 80, 443, 41641/udp).

### HomeAssistant — 10.37.70.20
- **Role:** HAOS VM (4 vCPU / 12 GB on TrueNAS iSCSI2). Served as ha.push-lab.com (direct). Consumes MQTT from Mosquitto.
- **Management:** not managed by Ansible. TODO(owner): integrations and add-ons inventory.

### Veeam2022 — 10.37.70.21
- **Role:** Windows Server 2022, Veeam Backup & Replication, NICs on VLAN 10 and 70.
- **Note:** several host_vars comments call this the "Ansible controller"; that is stale.
