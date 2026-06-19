# Tailscale ACL Management

How the Tailscale tailnet (`crane-beaver.ts.net`) is governed in this project, and
what lives where. **Read this before adding a host to Tailscale or wiring up a new
service-to-service path over the tailnet.**

## TL;DR

The Tailscale **ACL policy is not in this repo.** `tagOwners`, grant rules, and the
OAuth clients are all managed by hand in the Tailscale admin console. Ansible only
*consumes* the ACL (it mints tagged auth keys and runs `tailscale up`). So when you
add a host or a new access path, you edit **two places**: the Ansible host_vars
(in this repo) **and** the ACL/OAuth client (in the admin console). They are not
synced automatically.

## What is managed where

| Concern | Managed in | Location |
| --- | --- | --- |
| Install Tailscale, `tailscale up`, hostname, which tags a host *requests* | **Ansible (this repo)** | `roles/tailscale/`, `inventories/**/host_vars/<host>.yml` |
| Auth-key generation (OAuth token → short-lived tagged key) | **Ansible (this repo)** | `roles/tailscale/tasks/join.yml` |
| OAuth client ID/secret used for key generation | **Vault (this repo) + console** | `group_vars/vault.yml` (encrypted); client created in console |
| `tagOwners` (which identities may apply a tag) | **Admin console only** | https://login.tailscale.com/admin/acls |
| Grant rules (which `src` tag may reach which `dst` tag:port) | **Admin console only** | same ACL editor |
| OAuth client tag scope (which tags a client may stamp on keys) | **Admin console only** | https://login.tailscale.com/admin/settings/oauth |

There is intentionally **no** `acl.hujson`, Terraform `tailscale` provider, or ACL
API call anywhere in the repo. The role only references the ACL in comments/hints
(e.g. `roles/tailscale/defaults/main.yml`, the failure message in
`roles/tailscale/tasks/join.yml`).

## How auth works (so the failure modes make sense)

The `tailscale` role does **not** use a static auth key. On each run it:

1. Exchanges the OAuth `client_id`/`client_secret` (from `vault.yml`) for a short-lived
   API token.
2. Calls the Tailscale API to mint a **single-use, ~5-minute** auth key tagged with the
   host's `tailscale_tags`.
3. Runs `tailscale up --authkey=… --hostname=…`.

For step 2 to succeed, **every tag in `tailscale_tags` must be:**
- defined in `tagOwners`, **and**
- within the **OAuth client's tag scope**.

If either is missing, key generation returns **HTTP 400** and the role fails with
"OAuth client doesn't have the required tags (...)". Adding the tag to `tagOwners`
alone is **not** enough — the OAuth client carries its own fixed tag set.

## Tags currently in use

| Tag | Applied to | Owner (`tagOwners`) |
| --- | --- | --- |
| `tag:crowdsec-lapi` | crowdsec.localdomain (LAPI) | `tag:ansible-managed` |
| `tag:crowdsec-agent` | rangernet-vps, other agents | `tag:ansible-managed` |
| `tag:komodo-core` | docker-internal (Komodo Core host) | `tag:ansible-managed` |
| `tag:komodo-periphery` | rangernet-vps (Periphery target) | `tag:ansible-managed` |

(Source of truth for *which host gets which tag* is the host_vars `tailscale_tags`.
Source of truth for ownership/grants is the console ACL.)

### Grant rules currently in place

- CrowdSec agents reach LAPI: `tag:crowdsec-agent → tag:crowdsec-lapi:8080`
- Komodo Core reaches Periphery: `tag:komodo-core → tag:komodo-periphery:8120`

## Runbook: add a host to the tailnet

1. **host_vars** (this repo): set `tailscale_enabled: true`, `tailscale_hostname`, and
   `tailscale_tags`. Commit/merge.
2. **ACL `tagOwners`** (console): ensure each tag exists, owned by `tag:ansible-managed`.
3. **OAuth client tag scope** (console): the client in `vault.yml` must be allowed to
   issue keys for those tags — see "Rotating / extending the OAuth client" below.
4. Run the relevant deploy (e.g. the `site.yml` Tailscale play) and confirm
   `tailscale status` shows the host Running with the expected tags.

## Runbook: allow a new service path over the tailnet

1. Add a grant rule in the console ACL: `src` tag → `dst` tag → `ip` `["*:<port>"]`.
2. If the destination service runs in Docker on a **public** host, do **not** rely on
   the host firewall — a published Docker port bypasses firewalld/nftables. Bind the
   published port to the host's Tailscale IP instead (see `komodo_periphery_bind_address`
   for the pattern). Keep the firewall rule as defense-in-depth only.

## Rotating / extending the OAuth client

Tailscale OAuth clients are **immutable** — you cannot add tags to an existing one.
To cover a new tag:

1. Console → Settings → OAuth clients → **Generate OAuth client**.
   - Scope: **Auth Keys → write** (`auth_keys`).
   - Tags: select **all** tags the fleet uses (currently the four above), so one client
     serves every host.
2. Copy the new `client_id` / `client_secret`.
3. Update the encrypted vault: `ansible-vault edit ansible/group_vars/vault.yml`
   (`tailscale_oauth_client_id`, `tailscale_oauth_client_secret`).
4. Delete the old client.

This rotates the credential for **all** Tailscale-managed hosts, but as long as the new
client's tag scope is a superset, nothing breaks — already-joined devices stay joined,
and each host picks up the new client on its next run.

## Known gap & future option

Because the ACL lives only in the console, it is **not version-controlled** — no diff
history, no review, and it can drift from the host_vars in this repo. If we want the
policy as code, the two clean options are:

- **Terraform** `tailscale` provider (`tailscale_acl`, `tailscale_oauth_client`) — fits
  the existing `terraform/` tree.
- **Tailscale ACL GitOps** (the official sync action) pointing at an `acl.hujson` in this
  repo.

Neither is implemented today; this doc is the interim source of truth.
