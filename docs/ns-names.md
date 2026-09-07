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
