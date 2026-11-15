# push-lab architecture

These docs describe the homelab as it actually runs: the hypervisors, network, DNS, every host and container, how traffic gets in, where data lives, and how changes reach production.

**Last verified:** 2026-11-15. Sources:
- this repo (`push-lab_2_0`)
- the `docker-stacks` repo
- a read-only SSH survey of every host
- a read-only vCenter query

## Two audiences

| You are… | Read |
|---|---|
| A human getting oriented | The numbered docs below. They have diagrams (Mermaid, which renders in Gitea) and narrative |
| An AI agent / LLM | [`ARCHITECTURE.ai.md`](ARCHITECTURE.ai.md). It is a single dense file: tables, IPs, ports, invariants, traps, and "where to change things" |
| Fixing things | [`findings.md`](findings.md). It is the risk, drift and discrepancy register |

## Reading order

1. [Overview](01-overview.md): what the lab is, the domains, and the tool chain
2. [Physical](02-physical.md): ESXi hosts, storage boxes, Pis, VPS, UPS
3. [Network](03-network.md): VLANs, OPNsense, Tailscale, firewalls
4. [DNS & DHCP](04-dns-dhcp.md): Technitium ns01/ns02
5. [Hosts](05-hosts.md): one card per machine
6. [Services](06-services.md): every container stack, by host
7. [Ingress, auth & TLS](07-ingress-auth-tls.md): how requests reach apps
8. [Storage & backup](08-storage-backup.md)
9. [Observability & security](09-observability-security.md)
10. [Automation & GitOps](10-automation-gitops.md): Packer → Terraform → Ansible, Komodo, Renovate

## Keeping this current

Each doc says where its facts came from:
- **repo** — a file path
- **live** — the SSH survey
- **vc** — vCenter

Anything that couldn't be discovered is marked `TODO(owner):`.

Re-verify with read-only commands:

```bash
# hosts & containers
ssh push@<ip> 'ip -br a; docker ps --format "{{.Names}}\t{{.Image}}\t{{.Ports}}"'
# proxy vhosts → upstreams
ssh push@10.37.70.24 'sudo nginx -T' | grep -E 'server_name|proxy_pass'
# vCenter VM inventory (govc, read-only)
govc find / -type m ; govc vm.info -r '<vm>'
# NAS exports
ssh push@10.37.70.7 'showmount -e 10.37.70.22; showmount -e 10.37.20.4'
```

When a fact changes, update the matching numbered doc **and** `ARCHITECTURE.ai.md`.

Older docs in `docs/` (overview.md, `diagrams/*.drawio`, etc.) cover only the Gitea pipeline or are out of date. See [findings](findings.md#d-documentation-drift).
