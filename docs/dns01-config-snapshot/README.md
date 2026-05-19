# dns01 Configuration Snapshot

Captured 2026-05-18 from `http://10.37.80.2:5380` (Technitium DNS Server). Read-only API pulls; sensitive fields removed (`sessions` arrays per-user, TLS passwords already masked by API). All JSON in this directory is the raw API response after scrubbing.

## What's here

| File | Source endpoint |
|---|---|
| `settings.json` | `/api/settings/get` |
| `zones-list.json` | `/api/zones/list` |
| `zone-options/<zone>.json` | `/api/zones/options/get` per zone |
| `forwarder-zones/<zone>.json` | `/api/zones/records/get` per Forwarder-type zone |
| `dhcp-scopes-list.json` | `/api/dhcp/scopes/list` |
| `scopes/<scope>.json` | `/api/dhcp/scopes/get` per scope (includes `reservedLeases`) |
| `users-list.json` | `/api/admin/users/list` |
| `users/<user>.json` | `/api/admin/users/get` per user (sessions removed) |
| `groups-list.json` | `/api/admin/groups/list` |
| `permissions-list.json` | `/api/admin/permissions/list` |

## Headline findings

### DNS server settings
- **Hostname**: `dns01.push-lab.com`
- **Forwarders**: `76.76.2.198`, `76.76.10.198` (ControlD) over UDP.
- **Recursion**: `UseSpecifiedNetworkACL` (no allow/deny networks set yet — see `recursionAllowedNetworks` / `recursionDeniedNetworks` in settings).
- **Blocking type**: `NxDomain`. No blocklist URLs, no allowed/blocked zones configured.
- **DNSSEC validation**: not set (null) — defaults apply.
- **TSIG keys**: none. (No signed zone transfers in use; AXFR will rely on IP-based ACL.)

### Zones
9 user-managed Primary zones (the ones we need to replicate to dns02 as Secondary) + 4 Forwarder zones (must be recreated on dns02 as Forwarder type — they don't replicate via AXFR).

| Zone | Type | Why on dns02 |
|---|---|---|
| `localdomain` | Primary | Hostnames + DHCP-dynamic records. **Secondary on dns02.** |
| `10.37.10.in-addr.arpa` through `80.37.10.in-addr.arpa` (8 zones) | Primary | Reverse PTRs per VLAN. **Secondary on dns02.** |
| `patreons7.club`, `push-lab.com`, `rangernet.dev`, `ryanpampush.com` | Forwarder | Re-create as Forwarder zones on dns02; same forwarder target. |

**Zone-transfer ACL on every Primary**: `zoneTransfer=AllowOnlyZoneNameServers`, `notify=ZoneNameServers`. That means dns01 will only allow transfers/notifies to servers listed as **NS records inside the zone**. To make dns02 a valid secondary, **either**:

- **Option A (DNS-native)**: Add `dns02` as an NS record in each zone (+ a glue A record for `dns02.localdomain` → `10.37.80.254`). Cleanest, no settings change.
- **Option B (explicit)**: Change each zone to `zoneTransfer=AllowOnlySpecifiedNameServers` with `zoneTransferNameServers=["10.37.80.254"]` and `notify=SpecifiedNameServers` with `notifyNameServers=["10.37.80.254"]`. More explicit but more zones to touch.

### DHCP scopes (10 total, 6 enabled)

| Scope | Range | Lease | Router | DNS handed out | Offer delay | Reservations |
|---|---|---|---|---|---|---|
| VLAN10 (Management) | 10.37.10.1–.254 | 1d | 10.37.10.1 | useThisDnsServer=true (→ dns01) | **0** | **10** |
| VLAN20 (Trusted) | 10.37.20.1–.254 | 1d | 10.37.20.1 | useThisDnsServer=true (→ dns01) | **0** | **11** |
| VLAN30 (Storage) | 10.37.30.1–.254 | 1d | 10.37.30.1 | useThisDnsServer=true (→ dns01) | **0** | 0 |
| VLAN50 (IoT) | 10.37.50.1–.254 | 1d | 10.37.50.1 | useThisDnsServer=true (→ dns01) | **0** | **31** |
| VLAN60 (Guest) | 10.37.60.1–.254 | 1d | 10.37.60.1 | useThisDnsServer=true (→ dns01) | **0** | 0 |
| VLAN70 (DMZ) | 10.37.70.1–.254 | 1d | 10.37.70.1 | useThisDnsServer=true (→ dns01) | **0** | **15** |
| VLAN80 (App) | 10.37.80.1–.254 | 1d | 10.37.80.1 | useThisDnsServer=true (→ dns01) | **0** | **1** |
| VLAN40 (Isolation) | 10.37.40.1–.254 | 1d | 10.37.40.1 | useThisDnsServer=true | 0 | 0 (disabled) |
| VLAN90 (OpenVPN) | 10.37.90.1–.254 | 1d | 10.37.90.1 | `10.37.90.2` (no useThis) | **5000** | 0 (disabled) |
| VLAN100 (Unused) | 10.37.100.1–.254 | 1d | 10.37.100.1 | `10.37.10.2` (typo?) | 0 | 0 (disabled) |

**Total reservations to sync: 68.**

Observations:
- **`useThisDnsServer=true` on every enabled scope** — dns01 hands out itself as the only DNS server. If dns01 dies, clients have no fallback DNS. **Recommended change on both servers**: set `useThisDnsServer=false` and explicit `dnsServers=[<dns01_vlan_ip>, <dns02_vlan_ip>]` so clients learn about both.
- **VLAN90 already has `offerDelayTime=5000` and explicit DNS** — looks like a leftover from earlier experimentation. Good template for what we want everywhere on dns02.
- **VLAN100 has `dnsServers=["10.37.10.2"]`** — almost certainly a typo (should be `10.37.100.2` if you ever enable it). Worth fixing on dns01.

### Users and groups
- **Groups**: 3 defaults — `Administrators`, `DHCP Administrators`, `DNS Administrators`.
- **Users**: 2 — `admin` (in `Administrators`) and `automation` (in **no group** — granted permissions individually or has stale config). Existing `automation` API token `fa97…a355` is in active use from `10.37.70.25` (Semaphore).
- **Token you just gave me**: `b22b1192…` — it's the **admin user's** "temp token" slot, not the automation user. Full admin rights. **Rotate after we're done** (Administration → Users → admin → revoke that token).

## What to do on dns02

The Ansible role is wired but `host_vars/dns02.yml` currently only declares one Secondary zone (`localdomain`). Concrete changes needed:

### 1. Expand `technitium_secondary_zones` to cover all 9 user-managed primaries

In `ansible/inventories/prod/host_vars/dns02.yml`:

```yaml
technitium_secondary_zones:
  - { name: "localdomain",            primary_addresses: ["10.37.80.2"] }
  - { name: "10.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
  - { name: "20.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
  - { name: "30.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
  - { name: "40.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
  - { name: "50.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
  - { name: "60.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
  - { name: "70.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
  - { name: "80.37.10.in-addr.arpa",  primary_addresses: ["10.37.80.2"] }
```

### 2. Allow transfer/notify on dns01 (manual, web UI)

Pick **Option A or B** above. Option A (NS records) is cleaner; Option B (explicit ACL) is faster to apply.

Note: dns01 and dns02 are on the same VLAN (App, `10.37.80.0/24`), so AXFR and the reservation-sync API call are intra-VLAN — no OPNsense rule needed. Only dns01's host firewall could block it, and `:53/tcp` is almost certainly already open to App VLAN; check `:5380/tcp` for any IP-based restriction.

### 3. DHCP scopes on dns02 (manual one-time in web UI)

For each enabled scope (VLAN10/20/30/50/60/70/80), recreate on dns02 with:
- **Identical** subnet/pool/lease time/router as dns01 (see table above).
- `Offer Delay Time` — leave at 0; the Ansible role's `dhcp_offer_delay.yml` task sets it to `technitium_dhcp_offer_delay_ms` (5000 on dns02) on every play run.
- `useThisDnsServer` = **false**.
- `dnsServers` = `[<dns01_vlan_ip>, <dns02_vlan_ip>]` for that VLAN (e.g. for VLAN20: `["10.37.20.2", "10.37.20.254"]`).
- Leave scope **enabled**.

The reservation sync timer (already deployed) will populate reservations within ~5 min once scopes exist.

### 4. (Optional but recommended) Update dns01's scopes too

So clients get both DNS servers regardless of which scope they're on:
- Set `useThisDnsServer=false`.
- `dnsServers=[<dns01_vlan_ip>, <dns02_vlan_ip>]`.

Without this, clients DHCP'd from dns01 today only know about dns01 as DNS — failover at the DNS layer won't help them until their lease renews against dns02.

### 5. Forwarder zones (manual on dns02)

For each of `patreons7.club`, `push-lab.com`, `rangernet.dev`, `ryanpampush.com`: create as Forwarder-type zone on dns02 with the same forwarder addresses as in `forwarder-zones/<zone>.json`. These don't AXFR.

### 6. Server settings to mirror

Set on dns02 via web UI (or follow-up Ansible work):
- Forwarders: `76.76.2.198`, `76.76.10.198`, protocol `Udp`.
- DNS server domain: `dns02.push-lab.com`.
- Recursion: `UseSpecifiedNetworkACL`.

### 7. Users

Recreate the `automation` user on dns02 with a token for use by the reservation sync script and any future Semaphore-driven automation. Group assignment to be decided — `DHCP Administrators` + `DNS Administrators` (or `Administrators` if you don't want to split).

### 8. Rotate the admin token used for this capture

Once you're satisfied with the snapshot, revoke `b22b1192…` from the admin user's tokens.

## Recapture

To re-run this snapshot later:

```bash
export TDNS_TOKEN=<token> TDNS_HOST=10.37.80.2:5380
OUT=docs/dns01-config-snapshot
# scopes
curl -sS "http://${TDNS_HOST}/api/dhcp/scopes/list?token=${TDNS_TOKEN}" | jq . > $OUT/dhcp-scopes-list.json
jq -r '.response.scopes[].name' $OUT/dhcp-scopes-list.json | while read s; do
  safe=$(echo "$s" | tr ' /()' '____' | tr -s '_')
  curl -sS --get --data-urlencode "token=${TDNS_TOKEN}" --data-urlencode "name=${s}" \
    "http://${TDNS_HOST}/api/dhcp/scopes/get" | jq . > "$OUT/scopes/${safe}.json"
done
# settings / zones / users / groups / permissions: similar one-liners
```
