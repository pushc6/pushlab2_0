# dns02 Rollout — Step by Step

A production-safe order of operations for bringing `dns02` into service alongside `dns01` (which is currently serving DNS and DHCP for the lab). Each phase has a defined blast radius, verification checkpoint, and rollback. Don't advance until verification passes.

**Goal end state**: dns02 serves DNS authoritatively (via Secondary zones AXFR'd from dns01), runs DHCP hot with a 5-second offer delay so dns01 always wins the race, and mirrors dns01's DHCP reservations every 5 minutes. Clients learn both servers as DNS via DHCP option.

**Companion docs**:
- `docs/dns02-secondary-and-dhcp-sync.md` — design rationale.
- `docs/dns01-config-snapshot/README.md` — what's currently on dns01 (scopes, zones, settings).

---

## Network gotcha: dns02 needed IPv6 default route

dns02 originally couldn't install Technitium DNS Apps (Log Exporter) because the container's resolver prefers AAAA records and dns02 had no IPv6 default route. dns01 has one via netplan; dns02's cloud-init didn't include it.

Fixed in `terraform/envs/prod/prod.tfvars` and the VM module's cloud-init rendering — dns02's App VLAN entry now has `ipv6_gateway = "fe80::250:56ff:febc:bf"` (OPNsense link-local) and `accept_ra = true`. Other VLANs got stable ULAs (`fd00:1337:1337:00X0::54/64`) and `accept_ra = false` to mirror dns01's pattern. **Requires `terraform apply` + VM redeploy** to take effect; the change only lands via cloud-init on a fresh boot.

After redeploy, verify:
```bash
ssh 10.37.20.254 'ip -6 route show default; curl -sS --max-time 10 --ipv6 -o /dev/null -w "v6:%{http_code} %{time_total}s\n" https://download.technitium.com/'
# expect: default via fe80::250:56ff:febc:bf dev eth7 ...
# expect: v6:200 ~1s
```

## Phase 0 — Prerequisites

- [ ] dns02 VM exists, is reachable from Ansible (Semaphore can SSH into it).
- [ ] dns02 is **multi-homed on every VLAN as `.254`** (mirrors dns01's `.2` pattern).
- [ ] Semaphore has SSH and inventory access to dns02.
- [ ] You have web UI access to **both** dns01 and dns02 (or are willing to obtain it).
- [ ] You have ~30 min for the AXFR + scope-mirror + reservation sync phases, plus a flexible 24h window for client lease renewal.

**Take a backup of dns01 right now.** dns01 web UI → Settings → **Backup Settings** → save the `.zip`. If anything in phases 3–6 misbehaves, this is your rollback.

---

## Phase 1 — Deploy dns02 container (zero impact on dns01)

**Goal**: Stand up an empty Technitium on dns02. No zones, no scopes, no clients.

**What changes**: container + firewall rules on dns02 only. dns01 is untouched.

### Steps

1. Edit `ansible/inventories/prod/host_vars/dns02.yml` and **temporarily comment out the replication blocks** so the first run only deploys the container:

   ```yaml
   # Leave these set; they're needed by the container
   technitium_dns_domain: "dns02.push-lab.com"

   # COMMENT OUT for Phase 1 — re-enable in later phases
   # technitium_api_token: ...
   # technitium_secondary_zones: ...
   # technitium_dhcp_offer_delay_ms: 5000
   # technitium_reservation_sync_enabled: true
   # technitium_reservation_sync_primary_host: ...
   # technitium_reservation_sync_primary_token: ...
   ```

2. Commit and push. Run the Semaphore template that applies the `technitium` role to `dns02`.

### Verify

```bash
ansible dns02 -m shell -a 'docker ps --filter name=dns-server --format "{{.Status}}"'
# expect: "Up X seconds"
```

Open `http://10.37.80.254:5380` in a browser — you should see the Technitium login (factory `admin/admin`).

### Rollback

`ansible dns02 -m shell -a 'docker rm -f dns-server'`. No production impact.

**✅ Commit point**: `feat(dns02): deploy empty Technitium container`

---

## Phase 2 — Create API tokens (manual, one-time)

**Goal**: Create a non-admin service-account user with scoped permissions on each server, plus an API token for it.

**What changes**: a new user appears on dns01 and dns02. **No client-facing impact.**

### Steps on dns01

Skip if `automation` user already has a token labeled e.g. `dns02-sync`.

1. Web UI → Administration → **Users** → click `automation` (it already exists).
2. **Groups** tab → ensure `DHCP Administrators` is added (currently only `Zones` permission is direct-granted; the sync script needs DHCP read). Save.
3. **Session Tokens** tab → **Create Token** → name it `dns02-sync` → no expiry → copy the value.

### Steps on dns02

1. Web UI (`http://10.37.80.254:5380`) → log in as `admin/admin`.
2. Settings → **Change Password** → set a strong password. Store in your password manager (rarely used after this).
3. Administration → Users → **Create User** → username `automation`, set a password (won't be used by anything since we'll use a token).
4. Groups → add `automation` to `DHCP Administrators` **and** `DNS Administrators`. (Needs both: write reservations + create/manage Secondary zones.)
5. Session Tokens → Create Token → name `ansible-managed` → no expiry → copy the value.

### Add tokens to Semaphore

Open the Semaphore template you use for the `technitium` role → **Environment** block → add:

| Key | Value |
|---|---|
| `TECHNITIUM_API_TOKEN_DNS01` | the `dns02-sync` token from dns01 |
| `TECHNITIUM_API_TOKEN_DNS02` | the `ansible-managed` token from dns02 |

### Verify

```bash
# From your workstation or Semaphore worker:
curl -sS "http://10.37.80.2:5380/api/zones/list?token=${TECHNITIUM_API_TOKEN_DNS01}" \
  | jq -r '.status'
curl -sS "http://10.37.80.254:5380/api/zones/list?token=${TECHNITIUM_API_TOKEN_DNS02}" \
  | jq -r '.status'
# both should print "ok"
```

### Rollback

Revoke the token entries in each Technitium UI. No client impact.

**✅ Commit point**: nothing to commit — secrets stayed in Semaphore.

---

## Phase 3 — DNS replication (low risk, DNS-only)

**Goal**: dns02 holds Secondary copies of every user-managed Primary zone from dns01. AXFR runs on first poll, NOTIFY drives ongoing sync.

**What changes**: zone-transfer ACL on dns01 (9 zones); dns02 gains Secondary zones. **Clients are not yet pointed at dns02, so this is invisible to them.**

### Steps

1. **On dns01** (web UI), for each Primary zone (`localdomain` + 8 reverse `*.in-addr.arpa` zones — see snapshot README for the full list):
   - Zone → Options.
   - **Zone Transfer** = `Allow only specified name servers` → add `10.37.80.254`.
   - **Notify** = `Specified name servers` → add `10.37.80.254`.
   - Save.

2. **Uncomment in `host_vars/dns02.yml`** and expand to all 9 zones:

   ```yaml
   technitium_api_token: >-
     {{ lookup('env', 'TECHNITIUM_API_TOKEN_DNS02')
        | default(vault_technitium_api_token_dns02, true) }}

   technitium_secondary_zones:
     - { name: "localdomain",           primary_addresses: ["10.37.80.2"] }
     - { name: "10.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
     - { name: "20.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
     - { name: "30.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
     - { name: "40.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
     - { name: "50.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
     - { name: "60.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
     - { name: "70.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
     - { name: "80.37.10.in-addr.arpa", primary_addresses: ["10.37.80.2"] }
   ```

3. Commit and re-run the Semaphore template. The role declares each Secondary zone on dns02 via API; AXFR triggers immediately.

### Verify

```bash
TOKEN=$TECHNITIUM_API_TOKEN_DNS02
curl -sS "http://10.37.80.254:5380/api/zones/list?token=$TOKEN" \
  | jq -r '.response.zones[] | select(.type=="Secondary") | "\(.name)  serial=\(.soaSerial)"'
# expect 9 Secondary zones with non-zero serials matching dns01
```

Spot-check a record:
```bash
dig @10.37.80.254 +short <known-host>.localdomain
# should match dig @10.37.80.2 +short <known-host>.localdomain
```

Forwarder zones (`patreons7.club`, `push-lab.com`, `rangernet.dev`, `ryanpampush.com`) are **not** in the Ansible-managed list — they don't AXFR. Create them manually on dns02 web UI as Forwarder type with the same FWD records (see `docs/dns01-config-snapshot/forwarder-zones/*.json`). Low priority — only matters if clients ever query dns02 for those domains.

### Rollback

On dns01: revert each zone's transfer/notify to `AllowOnlyZoneNameServers` / `ZoneNameServers`. On dns02: web UI → delete each Secondary zone. No client impact (clients still point at dns01 only).

**✅ Commit point**: `feat(dns02): enable Secondary zone AXFR from dns01`

---

## Phase 4 — Configure dns02's recursive DNS + DNS Apps

**Goal**: dns02 can answer non-authoritative queries (e.g., google.com) via forwarders, and streams query logs to the same syslog receiver as dns01.

**What changes**: dns02 settings (manual UI) + DNS Apps installed via the role (automated). **Clients still not pointed at dns02, no impact.**

### Steps — recursive DNS settings (manual, dns02 web UI)

1. Settings → **General**:
   - DNS Server Domain: `dns02.push-lab.com` (already set via env var on container, but verify).
2. Settings → **Recursion**:
   - Recursion: `Use Specified Network ACL`.
   - Allowed Networks: `10.37.0.0/16` (or your client networks).
3. Settings → **Forwarders**:
   - Protocol: `UDP`.
   - Forwarders: `76.76.2.198`, `76.76.10.198` (match dns01's ControlD config — see `dns01-config-snapshot/settings.json`).
4. Save.

> Note: dns01 currently has `recursionAllowedNetworks=null` with `recursion=UseSpecifiedNetworkACL` — that's a bug on dns01. While you're configuring dns02, set its ACL properly. Fixing dns01 is a separate task; doesn't block this rollout.

### Steps — DNS Apps (Ansible)

The `technitium_dns_apps` list in `host_vars/dns02.yml` already declares Log Exporter pointed at `10.37.70.25:1514/udp` (same destination as dns01). The role's `apps.yml` task installs the app via `/api/apps/downloadAndInstall` and applies the config via `/api/apps/config/set` on every play run; idempotent — installs only when absent, updates config only on drift.

Re-run the Semaphore template. No host_vars changes needed beyond what's already there.

### Verify

```bash
dig @10.37.80.254 +short google.com
# expect a public IP
dig @10.37.80.254 +short example.invalid
# expect empty (NXDOMAIN)

# Log Exporter installed?
TOKEN=$TECHNITIUM_API_TOKEN_DNS02
curl -sS "http://10.37.80.254:5380/api/apps/list?token=$TOKEN" \
  | jq -r '.response.apps[] | select(.name=="Log Exporter") | "\(.name) v\(.version)"'
# expect: Log Exporter v1.0.2

# Verify config applied
curl -sS --get \
  --data-urlencode "token=$TOKEN" \
  --data-urlencode "name=Log Exporter" \
  "http://10.37.80.254:5380/api/apps/config/get" \
  | jq -r '.response.config' | jq .syslog
# expect: enabled=true, address=10.37.70.25, port=1514, protocol=udp
```

Confirm logs land on the syslog receiver (`10.37.70.25:1514/udp`). If they don't, the most likely cause is App-VLAN → DMZ-VLAN routing or the receiver's source-IP allow list — add `10.37.80.254` if it's restricted.

### Rollback

UI → clear forwarders / set recursion to `Deny`. For the app: dns02 web UI → Apps → Log Exporter → Uninstall. dns02 stops answering external queries and stops shipping logs; authoritative zones still work.

**✅ Commit point**: nothing to commit (Log Exporter declaration already in `host_vars/dns02.yml` from initial setup; settings live in Technitium config volume).

---

## Phase 5 — DHCP scopes on dns02 (disabled)

**Goal**: dns02 has every scope dns01 has, with identical pool/options, but **disabled** so it can't serve any clients yet. The role enforces `offerDelayTime=5000` on each via API.

**What changes**: scope definitions on dns02 (all 7 mirrored from dns01). **Nothing serves DHCP from dns02 yet because every scope starts `enabled: false`.**

### Steps (Ansible — fully automated)

The `technitium_dhcp_scopes` block in `host_vars/dns02.yml` already declares all 7 scopes mirroring dns01 (VLAN10/20/30/50/60/70/80). Each has:

- Identical subnet/pool/lease time/router as dns01 (sourced from `docs/dns01-config-snapshot/scopes/*.json`).
- `use_this_dns_server: false` and `dns_servers: [<vlan>.2, <vlan>.254]` — clients learn both servers.
- `dns_updates: false` — dns02's `localdomain` is read-only (Secondary), so DHCP dynamic updates would fail.
- `enabled: false` — safe default; flip to `true` per scope in Phase 8.

The role's `dhcp_scopes.yml` task creates each scope (or updates it if drifted) via `/api/dhcp/scopes/set`, then enables/disables based on the `enabled` flag. The `dhcp_offer_delay.yml` task then PATCHes `offerDelayTime=5000` on every scope.

Just re-run the Semaphore template — no host_vars changes needed.

### Optional: clean up the factory placeholder scope

Fresh Technitium ships with a "Default" scope (network `192.168.1.0/24`, disabled). The role doesn't touch it. If you want to delete it:

```bash
TOKEN=$TECHNITIUM_API_TOKEN_DNS02
curl -sS --get --data-urlencode "token=$TOKEN" \
  --data-urlencode "name=Default" \
  "http://10.37.20.254:5380/api/dhcp/scopes/delete"
```

### Verify

```bash
TOKEN=$TECHNITIUM_API_TOKEN_DNS02
curl -sS "http://10.37.80.254:5380/api/dhcp/scopes/list?token=$TOKEN" \
  | jq -r '.response.scopes[] | "\(.name)  enabled=\(.enabled)"'
# expect 6 scopes, all enabled=false (or null)
```

```bash
# Spot-check one scope's offer delay
curl -sS --get \
  --data-urlencode "token=$TOKEN" \
  --data-urlencode "name=VLAN20 (Trusted)" \
  "http://10.37.80.254:5380/api/dhcp/scopes/get" \
  | jq '.response | {name, offerDelayTime, dnsUpdates, useThisDnsServer, dnsServers}'
# offerDelayTime=5000, dnsUpdates=false, useThisDnsServer=false, dnsServers=["10.37.20.2","10.37.20.254"]
```

### Rollback

Delete each scope from dns02 web UI. No client impact.

**✅ Commit point**: `feat(dns02): pre-stage DHCP scopes (disabled), enforce offer delay`

---

## Phase 6 — Enable reservation sync (read-only against dns01)

**Goal**: dns02's scopes get every reservation dns01 has, refreshed every 5 min.

**What changes**: a systemd timer on dns02. **Reads-only from dns01; no client-facing impact.**

### Steps

Uncomment in `host_vars/dns02.yml`:

```yaml
technitium_reservation_sync_enabled: true
technitium_reservation_sync_primary_host: "10.37.80.2"
technitium_reservation_sync_primary_token: >-
  {{ lookup('env', 'TECHNITIUM_API_TOKEN_DNS01')
     | default(vault_technitium_api_token_dns01, true) }}
```

Commit and re-run Semaphore template.

### Verify

```bash
ansible dns02 -m shell -a 'systemctl list-timers technitium-reservation-sync.timer'
# expect ACTIVATES in <5 min

# Force one run immediately to skip the first wait
ansible dns02 -b -m shell -a 'systemctl start technitium-reservation-sync.service'
ansible dns02 -b -m shell -a 'journalctl -u technitium-reservation-sync.service -n 30 --no-pager'
# expect "done: 10 scopes total, N changed, 0 failed"
```

Spot-check reservations in a populated scope:
```bash
TOKEN=$TECHNITIUM_API_TOKEN_DNS02
curl -sS --get \
  --data-urlencode "token=$TOKEN" \
  --data-urlencode "name=VLAN50 (IoT)" \
  "http://10.37.80.254:5380/api/dhcp/scopes/get" \
  | jq '.response.reservedLeases | length'
# expect 31 (matches dns01's VLAN50)
```

### Rollback

```bash
ansible dns02 -b -m shell -a 'systemctl stop technitium-reservation-sync.timer'
ansible dns02 -b -m shell -a 'systemctl disable technitium-reservation-sync.timer'
```

Or just set `technitium_reservation_sync_enabled: false` and re-run.

**✅ Commit point**: `feat(dns02): enable reservation sync from dns01`

---

## Phase 7 — Update dns01 scopes to hand out both DNS servers (MEDIUM RISK)

**Goal**: New DHCP leases on dns01 hand out **both** dns01 and dns02 as DNS servers. Clients gain real DNS-layer redundancy.

**What changes**: every enabled scope on dns01: `useThisDnsServer=false`, `dnsServers=[<vlan>.2, <vlan>.254]`. **Clients see the new DNS list at next DHCP renewal — within 24 h given 1-day leases.** Existing leases keep using their cached DNS until renewal.

> **Coordinate this.** If you do a system-wide DHCP release/renew (e.g. testing), clients briefly drop DNS. Off-hours recommended.

### Steps (manual, dns01 web UI, repeat per enabled scope)

For each of VLAN10, VLAN20, VLAN30, VLAN50, VLAN60, VLAN70, VLAN80:

1. DHCP → Scopes → click scope → **DNS Servers section**.
2. Untick `Use This DNS Server`.
3. Set DNS Servers to `<vlan>.2, <vlan>.254` (e.g. for VLAN20: `10.37.20.2, 10.37.20.254`).
4. Save.

(VLAN90 already has this pattern; leave alone or normalize. VLAN100 is disabled and has a typo — see snapshot README — fix only if you plan to use it.)

### Verify

```bash
# Force-renew a test client (laptop, etc.) and check it picks up both DNS servers:
# macOS:    sudo ifconfig en0 down; sudo ifconfig en0 up
# Linux:    sudo dhclient -r && sudo dhclient
# Windows:  ipconfig /release && ipconfig /renew

# Then on the client:
scutil --dns | grep nameserver       # macOS
resolvectl status | grep "DNS Server" # Linux
ipconfig /all | findstr DNS          # Windows
# expect both 10.37.<vlan>.2 AND 10.37.<vlan>.254
```

### Rollback

In each scope, re-tick `Use This DNS Server` (or revert dnsServers to `[<vlan>.2]` only). Clients pick up the old single-server config on next renewal.

**✅ Commit point**: no Ansible changes — dns01 isn't in inventory. Note the manual change in your ops log.

---

## Phase 8 — Enable dns02 DHCP service (HIGHEST RISK)

**Goal**: dns02 actively serves DHCP, but `offerDelayTime=5000` means dns01 always wins the race when both are up.

**What changes**: dns02's DHCP service starts answering. Under normal conditions dns01 still wins (its OFFER arrives ~5 s before dns02's). The risk is misconfiguration causing dns02 to win or double-respond.

### Pre-check (do not skip)

Confirm dns01 actually answers DHCP fast. From a test machine on any VLAN:

```bash
sudo nmap --script broadcast-dhcp-discover -e <iface>
# look at the response IP — should be 10.37.<vlan>.2 (dns01)
```

### Steps

Edit `host_vars/dns02.yml`: flip `enabled: false` → `enabled: true` for each scope in `technitium_dhcp_scopes`. Commit and re-run the Semaphore template — the role POSTs `/api/dhcp/scopes/enable` per scope. To gate carefully, flip one at a time and run between each.

Then on dns02: DHCP → top-level → ensure the DHCP service is enabled (this is usually on by default once scopes exist, but confirm).

### Verify

**Test 1: dns01 still wins.** From a fresh test client (or `nmap --script broadcast-dhcp-discover`):
- DHCPOFFER must come from dns01's IP, arriving within ~1 s.
- Check dns02's logs (`docker logs dns-server` or web UI → DHCP → Logs): dns02 received the DISCOVER but did **not** send an OFFER (waited out the 5 s, saw dns01's ACK, cancelled).

**Test 2: failover.**
```bash
# Stop dns01's container (or block 67/udp at OPNsense)
# From test client: trigger DISCOVER
sudo dhclient -r && sudo dhclient   # or release/renew on your OS
# Expect: OFFER from dns02, arriving ~5 s after DISCOVER
```

**Test 3: failback.**
```bash
# Restart dns01
# From test client: trigger DISCOVER
# Expect: OFFER from dns01 again, within ~1 s
```

### Rollback

dns02 web UI → DHCP → Scopes → disable every scope. dns02 stops responding to DHCP. dns01 continues unchanged.

**✅ Commit point**: no Ansible changes. Note the manual enable in your ops log.

---

## Phase 9 — Final polish

These are nice-to-haves; do them when convenient.

### NS record for dns02

On dns01 → Zones → `localdomain` → Add:
- `A` record: `dns02` → `10.37.80.254`.
- `NS` record (at zone apex): `dns02.localdomain.`.

Same for each reverse zone if you want full delegation. AXFR replicates these to dns02 automatically.

### Rotate the temp admin token

The `b22b1192…` token you generated for the dns01 config snapshot earlier in this work has full admin rights and should be revoked:

dns01 web UI → Administration → Users → `admin` → Session Tokens → revoke the entry whose `partialToken` starts with `b22b1192`.

### Recapture snapshot

Once dns01's scopes are updated (Phase 7), re-run the snapshot capture to update `docs/dns01-config-snapshot/` so it reflects current state:

```bash
export TDNS_TOKEN=$TECHNITIUM_API_TOKEN_DNS01 TDNS_HOST=10.37.80.2:5380
# Re-run the per-scope GET loop from docs/dns01-config-snapshot/README.md
```

Commit the refreshed snapshot.

### Add a dns02 snapshot too

Run the same capture loop against `10.37.80.254:5380` with `TECHNITIUM_API_TOKEN_DNS02` to create `docs/dns02-config-snapshot/`. Useful as a baseline for future change-detection.

---

## Rollback summary table

| Phase | Rollback | Time to roll back |
|---|---|---|
| 1 | `docker rm -f dns-server` on dns02 | seconds |
| 2 | Revoke Technitium tokens via UI | seconds |
| 3 | Revert dns01 zone transfer/notify; delete Secondary zones on dns02 | minutes |
| 4 | Clear dns02 forwarders / disable recursion | seconds |
| 5 | Delete scopes on dns02 | minutes |
| 6 | `systemctl stop technitium-reservation-sync.timer` | seconds |
| 7 | Re-tick `Use This DNS Server` on each dns01 scope | minutes (UI); 24 h for clients to roll back via renewal |
| 8 | Disable every scope on dns02 | seconds |

The hardest-to-reverse phase is 7 — once new DHCP options are out, clients won't fully revert until their leases renew. If you suspect trouble in phase 7, **immediately** revert each scope; affected clients keep working since dns01 still serves DNS.

---

## What's deliberately out of scope

- Bringing `dns01` into Ansible inventory (would let the role manage its zone-transfer ACLs, scope DNS handout, etc.). Today these are manual.
- Native v14 cluster setup (UI-only enable; incompatible with DHCP-dynamic zones).
- DHCP scope-definition sync (manual once per scope; rarely changes).
- DHCP lease replication (no Technitium feature exists).
- Automated failback procedure beyond what's in `dns02-secondary-and-dhcp-sync.md`.
