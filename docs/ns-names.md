# DNS service names: ns01 / ns02

The canonical DNS service names are `ns01.push-lab.com` (10.37.20.2) and
`ns02.push-lab.com` (10.37.20.254). Technitium owns the records on ns01 and
replicates them to ns02. The secondary host is `ns02.localdomain` and its
Ansible inventory name is `ns02`; the primary Docker host remains
`docker-secure.localdomain` because that is the host identity, separate from
its DNS service name.

Komodo stacks remain `technitium-ns01` and `technitium-ns02`; the secondary
Server is `ns02`. Compose source is `ns02/technitium/compose.yml` in docker-stacks.
The primary source remains `docker-secure/technitium/docker-compose.yml`.

## Stable internal identifiers

Terraform retains `module.vm["dns02"]` and the existing VM name. The new optional
`ansible_name` field maps that VM to inventory host `ns02` without moving state
or recreating infrastructure. The VM redeploy workflow still accepts its
Terraform key `dns02`. The OPNsense alias `dns02` likewise remains a stable
IP-based firewall identifier; it does not resolve the retired DNS hostname.

Token variables `TECHNITIUM_API_TOKEN_NS01` and `TECHNITIUM_API_TOKEN_NS02` are
preferred. Existing `TECHNITIUM_API_TOKEN_DNS01` / `TECHNITIUM_API_TOKEN_DNS02`
and legacy vault keys remain supported so stored Semaphore secrets continue
working. Historical runbooks and backups retain their original filenames.

## Retirement

Old DNS address/delegation records are retained through their existing cache
window, then removed only after checking both new service names, NS/SOA records,
zone-transfer health, and automation references. Record/configuration snapshots
are kept separately from Git; no API tokens are committed.

## Verified rollout — 2026-09-07

- Both Technitium services run version 15.4 on the pre-existing pinned image.
- Both canonical names resolve over UDP and TCP on both servers. The `localdomain`
  NS set is `ns01.push-lab.com` plus `ns02.push-lab.com`, with ns01 as SOA primary.
- All five secondary zones have matching serials and no expiry/sync errors.
- Komodo Server `ns02` and both Technitium stacks are healthy; rollouts were sequential.
- Semaphore project 1 / template 13 (Technitium) now selects inventory host `ns02`.
- Hostname and cloud-init persistence are configured as `ns02.localdomain`.
- Reservation sync completed across 8 scopes with 0 changed and 0 failed.
- Grafana dashboards and Homepage configuration contain no old-name references.
  The Uptime Kuma VPS could not be reached over SSH for a monitor audit.

Five legacy records are configured with Technitium's persistent `expiryTtl`
for automatic removal at approximately **2026-09-07 18:50:30 UTC (14:50:30 EDT)**:
`dns02.localdomain` (A), and the old `dns02` child-delegation NS records in
`patreons7.club`, `push-lab.com`, `rangernet.dev`, and `ryanpampush.com`. The
secondary receives the deletions through zone transfer. `dns01.push-lab.com`
already had no address record when the migration began.

Configuration and record snapshots are retained root-only on ns02 under
`/var/backups/technitium-ns-names-20260907`. No API credential is needed for the
automatic expiry. Historical backup paths and Terraform/firewall identifiers
retain their old spellings as documented above.
