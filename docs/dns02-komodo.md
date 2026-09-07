# dns02 Komodo handover — 2026-09-07

Technitium on the dedicated dns02 host is managed by Komodo Stack
`technitium-ns02`. The old `docker-internal/technitium` definition was stale and
has been removed so Renovate tracks the deployed stack.

- Server: `dns02`, Periphery `https://10.37.70.254:8120` (Core at 10.37.70.25).
- Source: `rangernet/docker-stacks`, branch `main`, `dns02/technitium/compose.yml`.
- Compose project: `technitium-ns02`; container: `dns-server`.
- Networking: host; existing DNS/DHCP interfaces and settings remain in `/etc/dns`.
- Persistent data: `/opt/technitium/config:/etc/dns`; no named volume or data move.
- Initial image: `technitium/dns-server:14.2.0`, pinned to the existing running digest.
- Web console: Trusted, DMZ and App interfaces. DMZ binding lets Semaphore keep
  reaching the API through the configured Ansible inventory address.
- Periphery uses dns01 (10.37.70.2) for DNS so it can clone while dns02 restarts.

## Ownership

Komodo owns image updates, container creation and restarts. Renovate opens
per-stack PRs; merges trigger the Gitea push webhook copied from the Stack's
Config → Webhooks → Deploy. Komodo image auto-update stays off.

In `push-lab_2_0`, `technitium_manage_container: false` on dns02 skips Ansible's
container deployment tasks. The DNS settings, secondary zones, DNS Apps, DHCP
scope configuration, offer delay and reservation-sync systemd timer stay under
Ansible. The shared role still defaults to managing containers on other hosts.

## Handover and recovery

The initial handover backs up `/opt/technitium/config` and Docker inspect metadata
under `/var/backups/technitium-komodo-*` on dns02 while the service is stopped.
The original container is retained, stopped, as `dns-server-pre-komodo`.
The new Compose container uses the same image and data, so rollback can stop the
Komodo stack, rename its stopped container out of the way, rename the original
back to `dns-server`, and start it. Never start both containers together: both
use host networking and the same data directory. Pause the reservation-sync
timer during a handover and start it again once DNS is healthy.

After migration, verify UDP/TCP queries, local secondary-zone answers, the web
console, container mount/image, and the reservation-sync timer. Verify the Gitea
webhook with a push and check its delivery plus Komodo's stack history.
