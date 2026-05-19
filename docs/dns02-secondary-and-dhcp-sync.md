# dns02: Technitium Secondary with DNS + DHCP Reservation Sync

## Goal

Make `dns02` a usable secondary alongside the existing `dns01` Technitium DNS Server, with three properties:

1. **DNS zones mirror automatically** from `dns01` (including the zone the DHCP server writes A/PTR records into) using Technitium's built-in AXFR/IXFR + NOTIFY.
2. **DHCP runs hot/active on both** — `dns02`'s scope is configured with `Offer Delay Time = 5000` (5 s), so `dns01` always wins the DHCPDISCOVER race when both are up. `dns02` only answers when `dns01` is down or unreachable. Automatic recovery when `dns01` returns; no manual failover step.
3. **DHCP reservations sync** from `dns01` → `dns02` every 5 minutes via a Python script on a systemd timer, so static MAC→IP mappings stay consistent regardless of which server answers.

### Non-goals / known gaps

- **Active DHCP leases are NOT replicated.** No Technitium API exposes that today. Under the hot-active model, `dns02` only leases when `dns01` is down, so there's a small window where `dns02` can hand out an IP from the dynamic pool that `dns01` has no record of. Acceptable for homelab; static reservations (which *are* synced) eliminate this for important clients.
- **Native v14 clustering is not used.** It's web-UI-only to enable (incompatible with IaC reproducibility), and its cluster-catalog zones require DNSSEC which would block DHCP-dynamic record updates. Revisit if Technitium adds API-driven cluster setup.
- **DHCP scope definitions are not synced** — defined manually once on each server. They rarely change.

## What replicates and how

| Item | Mechanism |
|---|---|
| DNS zones (static and DHCP-dynamic) | Technitium-native AXFR/IXFR + NOTIFY. Declared on `dns02` via the Technitium HTTP API by `tasks/zones.yml`. |
| DHCP scope definitions | Subnet/pool/options created manually once on each server. The role enforces `offerDelayTime` on every existing scope (5000 ms on `dns02` via `technitium_dhcp_offer_delay_ms` in host_vars), so `dns01` wins under normal conditions. |
| DHCP reservations (MAC→IP statics) | `technitium_reservation_sync.py` on `dns02`, systemd timer every 5 min. One-way, source = `dns01`. |
| Active DHCP leases | Not replicated. Lost on failover by design. |
| Server settings, blocklists, users | Manual for now. Out of scope. |

## Architecture diagram

```
                          ┌─────────────────────┐
   AXFR/IXFR + NOTIFY     │       dns01         │
        :53/tcp ◄─────────│  Technitium primary │
                          │  DHCP scope (no     │
                          │   offer delay)      │
                          └──────────┬──────────┘
                                     │
                                     │ HTTP API :5380
                                     │ (read reservations)
                                     │
                                     ▼
                          ┌─────────────────────┐
                          │       dns02         │
                          │  Technitium         │
                          │  • Secondary zone(s)│
                          │  • DHCP scope w/    │
                          │    offerDelay=5000  │
                          │  • systemd timer:   │
                          │    reservation sync │
                          └─────────────────────┘
```

## Status of work

### Done (this session)

All code/config changes are in `main`. The role builds and `ansible-lint` passes.

| File | Change |
|---|---|
| `ansible/roles/technitium/defaults/main.yml` | Added `technitium_api_token`, `technitium_api_{host,port,scheme}`, `technitium_secondary_zones`, `technitium_reservation_sync_*` |
| `ansible/roles/technitium/tasks/main.yml` | After container deploy: wait for `:5380`, conditionally include `zones.yml` and `reservation_sync.yml` |
| `ansible/roles/technitium/tasks/zones.yml` | **NEW** — idempotent Secondary zone creation via Technitium HTTP API |
| `ansible/roles/technitium/tasks/reservation_sync.yml` | **NEW** — installs script, env file, systemd unit + timer |
| `ansible/roles/technitium/files/technitium_reservation_sync.py` | **NEW** — env-driven Python sync (Session + retry, scoped exceptions, structured logging, HTTPS-capable). Derived from `mrjackson/MiscScripts` upstream. |
| `ansible/roles/technitium/templates/technitium-reservation-sync.service.j2` | **NEW** — systemd unit |
| `ansible/roles/technitium/templates/technitium-reservation-sync.timer.j2` | **NEW** — systemd timer (5 min) |
| `ansible/roles/technitium/templates/reservation-sync.env.j2` | **NEW** — EnvironmentFile rendered with tokens (mode 0600) |
| `ansible/roles/technitium/handlers/main.yml` | **NEW** — restart timer on config change |
| `ansible/inventories/prod/host_vars/dns02.yml` | Added 67/udp firewall rule, `technitium_dns_domain=dns02.push-lab.com`, `technitium_secondary_zones`, `technitium_dhcp_offer_delay_ms=5000`, reservation sync vars |
| `ansible/roles/technitium/tasks/dhcp_offer_delay.yml` | **NEW** — PATCHes `offerDelayTime` on every existing scope via API |
| `ansible/group_vars/vault.yml.example` | Documented `vault_technitium_api_token_dns01`, `vault_technitium_api_token_dns02` |

### Not yet done

1. **`dns01` is not in Ansible inventory** — primary-side config has to be done by hand in the Technitium web UI (steps below).
2. **Semaphore env vars** — `TECHNITIUM_API_TOKEN_DNS01` and `TECHNITIUM_API_TOKEN_DNS02` need to be set on the template's Environment block (see Step 2). Without these the playbook will fail when it tries to talk to either Technitium API.
3. **Verify `dns01`'s IP** — `host_vars/dns02.yml` assumes `10.37.20.253`. Confirm and edit if wrong.
4. **DHCP scopes on `dns02`** — subnet/pool/options need to be created manually on `dns02` (matching `dns01`); the role automatically sets `offerDelayTime=5000` on each scope every play run.
5. **Run the playbook + verify** end-to-end (steps below).

## Step-by-step — pick up here tomorrow

### Step 1 — Generate API tokens on each Technitium

On `dns01` and `dns02` web UIs (`http://<host>:5380`):

1. Administration → Users → create a user (e.g. `ansible-sync`) with API access.
2. Under that user, generate a **non-expiring** API token.
3. Save both tokens for the next step.

### Step 2 — Add the tokens to Semaphore

In Semaphore: open the template you use for the technitium role → **Environment** → add two variables:

| Key | Value |
|---|---|
| `TECHNITIUM_API_TOKEN_DNS01` | the dns01 token (needs `DhcpServer.canView` at minimum) |
| `TECHNITIUM_API_TOKEN_DNS02` | the dns02 token (needs `Zones.canModify` + `DhcpServer.canModify`) |

`host_vars/dns02.yml` reads them via `lookup('env', '...')` with an ansible-vault fallback (`vault_technitium_api_token_dns0X`) for the rare case of a local run. The vault fallback is documented in `ansible/group_vars/vault.yml.example`; for Semaphore-only operation you don't need a vault file at all.

### Step 3 — Verify `dns01`'s IP in inventory

`dns01` lives at `10.37.80.2` on the App VLAN (handles both `:53` DNS and `:5380` API since Technitium uses host networking and listens on all interfaces). Both `technitium_secondary_zones[].primary_addresses` and `technitium_reservation_sync_primary_host` in `ansible/inventories/prod/host_vars/dns02.yml` should point there. Fix if wrong.

### Step 4 — Configure `dns01` manually (web UI)

For **each zone you want replicated** (start with `localdomain`):

1. Zones → click zone → Options.
2. **Zone Transfer**: `Allow only specified name servers` → add `dns02`'s App VLAN IP (`10.37.80.254`). This is the source IP `dns02` will use when reaching `dns01` at `10.37.80.2`.
3. **Notify**: `Specified name servers` → add `10.37.80.254`.
4. Save.

**DHCP scopes on `dns02`** (manual one-time per scope):

1. On `dns01`, open each existing DHCP scope and note all settings (subnet, pool start/end, lease time, options: gateway, DNS, domain, etc.). See `docs/dns01-config-snapshot/scopes/*.json` for the full list — 6 enabled scopes (VLAN10/20/30/50/60/70/80) plus VLAN90 which already has the delay pattern.
2. On `dns02`, DHCP → Scopes → create each scope with **identical** subnet/pool/options. Leave `Offer Delay Time = 0` — the role overrides it.
3. **Set `Dynamic DNS Updates` (dnsUpdates) = false** on every dns02 scope. `localdomain` is a Secondary zone on dns02 (read-only via AXFR), so dynamic update writes from dns02's DHCP would fail. dns01 already does the DNS updates and they replicate via NOTIFY; you don't need dns02 to also write them. During a brief failover, leases granted by dns02 won't get DNS records — acceptable tradeoff for the simpler topology.
4. Save and enable each scope.

The role's `dhcp_offer_delay.yml` task then iterates every existing scope on `dns02` and PATCHes `offerDelayTime=5000` via the API. Re-running the play after adding a scope brings it into compliance.

**Firewall on `dns01`**:

- `dns01` (10.37.80.2) and `dns02` (10.37.80.254) are on the same VLAN (App), so traffic between them is L2-switched and **does not traverse OPNsense**. No network-firewall rule needed.
- The only thing that could block this is **dns01's host firewall**. AXFR (`:53/tcp`) is almost certainly already open to App VLAN clients. Check `:5380/tcp` — if dns01's host firewall restricts the API port to specific IPs, add `10.37.80.254` to that allow list.

### Step 5 — Run the playbook

Run the template from Semaphore (the Environment block injects the two tokens). For a one-off local run (with a vault file you've created):

```bash
ANSIBLE_HOST_KEY_CHECKING=False \
  ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/site.yml \
    --limit dns02 \
    --tags technitium \
    --ask-vault-pass
```

(If the `technitium` role doesn't have a `--tags technitium` selector wired in `site.yml`, drop the `--tags` flag and run the whole site against `dns02`.)

### Step 6 — Verify

Set `TOKEN=<dns02 token>` for the curl examples.

1. **Container up**:
   ```bash
   ansible dns02 -m shell -a 'docker ps --filter name=dns-server'
   ```
2. **Zones replicated** (should list `localdomain` as `Secondary`):
   ```bash
   curl -s "http://10.37.80.254:5380/api/zones/list?token=$TOKEN" | jq '.response.zones[] | {name, type}'
   ```
3. **AXFR worked** — query `dns02` for a record known to live on `dns01`:
   ```bash
   dig @10.37.20.254 some.known.record +short
   ```
4. **NOTIFY path** — add a test A record on `dns01`, wait ~5 s, query `dns02`. Should resolve without a manual refresh.
5. **Reservation sync timer is armed**:
   ```bash
   ansible dns02 -m shell -a 'systemctl list-timers technitium-reservation-sync.timer'
   ansible dns02 -m shell -a 'journalctl -u technitium-reservation-sync.service -n 50 --no-pager'
   ```
6. **Reservation actually copies** — add a reservation on `dns01`, force-run the unit, verify on `dns02`:
   ```bash
   ansible dns02 -m shell -a 'systemctl start technitium-reservation-sync.service'
   curl -s "http://10.37.80.254:5380/api/dhcp/scopes/get?token=$TOKEN&name=<scope>" \
     | jq '.response.reservedLeases'
   ```
7. **DHCP race — `dns01` wins** under normal conditions:
   - From a test client (or `dhcping` / `nmap --script broadcast-dhcp-discover`), issue a DHCPDISCOVER.
   - Confirm the OFFER comes from `dns01` and arrives within ~1 s.
   - `dns02`'s DHCP log should show the DISCOVER received but no OFFER sent (it's waiting out the 5 s delay; `dns01`'s ACK lands first).
8. **DHCP failover — `dns02` takes over**:
   - On `dns01`: `docker stop dns-server` (or block `:67/udp` in OPNsense).
   - Trigger a fresh DHCPDISCOVER. OFFER should now come from `dns02` after ~5 s.
   - Restart `dns01`. New DISCOVERs should return to `dns01` within 1 s.
9. **Idempotence** — re-run the playbook; no tasks should report `changed`.

## Files to reference

- Plan/scratch: `~/.claude/plans/i-think-someone-on-pure-journal.md`
- Role: `ansible/roles/technitium/`
- Inventory: `ansible/inventories/prod/host_vars/dns02.yml`
- Vault example: `ansible/group_vars/vault.yml.example`

## Future work (deferred)

- Automate `dns01` — add it to inventory and give the `technitium` role a "primary" mode that sets zone-transfer ACLs and NOTIFY targets via API. Would also let scope definitions be templated.
- Shrink `dns02`'s dynamic DHCP pool to a non-overlapping slice for a stricter no-collision guarantee. Optional hardening if the "same pool + offer delay" model ever bites.
- Revisit native v14 clustering once Technitium exposes cluster setup via API (would replace the manual primary-side config for settings/users/blocklists).
- DHCP scope-definition sync (the `besmirzanaj` gist approach) once scopes start changing frequently.
