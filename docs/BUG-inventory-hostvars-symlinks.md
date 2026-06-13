# BUG: inventory `host_vars` stale regular-file copies shadow `manual/`/`prod/` edits

**Severity:** High (silent — edits appear applied but aren't)
**Component:** `ansible/inventories/` consolidation + `scripts/sync-inventory-symlinks.sh`
**Status:** Open. `docker-internal.localdomain.yml` already fixed (PR #4); the rest remain.

---

## Summary

Semaphore runs Ansible against the **top-level `ansible/inventories/` directory**, so Ansible
loads host_vars from **`ansible/inventories/host_vars/<host>.yml`** — not from the per-environment
`inventories/manual/host_vars/` or `inventories/prod/host_vars/` files where we actually edit.

`inventories/host_vars/<host>.yml` is *supposed* to be a **symlink** into the per-env source
(e.g. `dns02.yml -> ../prod/host_vars/dns02.yml`). But many entries are **stale regular-file
copies** instead. Because of a bug in `sync-inventory-symlinks.sh` (below), those copies are
never converted to symlinks, so **edits to the per-env source silently never reach Semaphore.**

## Impact / how it bit us (2026-06-13)

A new var `nfs_client_mounts` was added to `inventories/manual/host_vars/docker-internal.localdomain.yml`.
The Semaphore run read the stale **regular-file** copy at `inventories/host_vars/docker-internal.localdomain.yml`
(which lacked it), so `nfs_client_mounts` resolved empty and the NFS-mount tasks **skipped** with
no error. Worse, the two copies had **diverged in both directions**: the consolidated copy also
held a `Komodo Core - GitOps webhook listener` firewall rule that the `manual/` copy lacked — so
neither file was complete. Fixed for that one host by merging both changes into the canonical
`manual/` copy and replacing the consolidated copy with a real symlink (PR #4).

## Root cause

`scripts/sync-inventory-symlinks.sh` creates a symlink **only when the target does not already
exist**:

```bash
if [ ! -e "$INVENTORIES_DIR/host_vars/$name" ]; then
    ln -sf "$rel_path" "$INVENTORIES_DIR/host_vars/"
    ...
fi
```

So any `inventories/host_vars/<host>.yml` that already exists as a **regular file** is skipped
forever. The hook can't repair pre-existing regular files; it only fills in missing entries.
(`cleanup_broken_symlinks` only removes dangling *symlinks*, not stale regular files.)

Why a directory inventory reads `inventories/host_vars/`: when Ansible is pointed at a directory,
it composes all inventory sources under it and resolves adjacent `host_vars/`/`group_vars/` at the
**top level** of that directory — i.e. `inventories/host_vars/`, regardless of which subdir
(`manual/`, `prod/`) actually defines the host.

## Current state (audit on 2026-06-13)

Run from `ansible/inventories/`:

```bash
for f in host_vars/*; do
  if [ -L "$f" ]; then echo "SYMLINK  $(basename "$f")";
  else echo "FILE     $(basename "$f")"; fi
done
```

| Entry | Kind | Note |
|---|---|---|
| `dns02.yml` | ✅ symlink | → `../prod/host_vars/dns02.yml` |
| `gitea` | ✅ symlink | → `../prod/host_vars/gitea` (a directory) |
| `docker-internal.localdomain.yml` | ✅ symlink | → `../manual/host_vars/...` (fixed PR #4) |
| `nginx.yml` | ⚠️ **regular file, DIVERGED** | differs from `manual/host_vars/nginx.yml` (currently only a comment, but proves the hazard) |
| `crowdsec.localdomain.yml` | regular file (in sync) | source: `manual/` |
| `cupsserver.localdomain.yml` | regular file (in sync) | source: `manual/` |
| `docker-secure.localdomain.yml` | regular file (in sync) | source: `manual/` |
| `docker.yml` | regular file (in sync) | source: `manual/` |
| `linuxgameserver.localdomain.yml` | regular file (in sync) | source: `manual/` |
| `nginx-internal.localdomain.yml` | regular file (in sync) | source: `manual/` |
| `packer_builder.yml` | regular file (in sync) | source: `prod/` |
| `prusa3dbawkz.localdomain.yml` | regular file (in sync) | source: `manual/` |
| `rangernet-vps.yml` | regular file (in sync) | source: `manual/` |
| `raspberrypi-ha.localdomain.yml` | regular file (in sync) | source: `manual/` |

`group_vars/` entries are all proper symlinks (not affected), but apply the same fix/guard there.

## Proposed fix (two parts)

### 1. Repair existing entries → real symlinks (careful: merge divergence first)

For every regular-file entry in `inventories/host_vars/` (and `group_vars/`) that has a per-env
source counterpart:

1. **Diff** the consolidated copy against its `manual/`/`prod/` source.
2. If they differ, **merge** the unique content into the per-env source so it is the complete
   canonical file (do NOT blindly overwrite — each side may hold real, active config; see the
   docker-internal case where each had a different firewall/var change). `nginx.yml` is known
   diverged today.
3. Replace the consolidated copy with a relative symlink, e.g.:
   ```bash
   cd ansible/inventories/host_vars
   rm nginx.yml
   ln -s ../manual/host_vars/nginx.yml nginx.yml
   ```
4. If an entry has **no** per-env counterpart, decide where it should live (likely `manual/`),
   move it there, then symlink.

### 2. Fix the sync script so this can't recur

Make `sync-inventory-symlinks.sh` **idempotently enforce** symlinks: if
`inventories/host_vars/<name>` exists but is a regular file (or a symlink pointing somewhere
other than the expected `../<env>/host_vars/<name>`), replace it with the correct symlink.
Guard against the divergence trap — refuse (non-zero exit, clear message) if a regular file's
content differs from its source, so a human merges first rather than silently losing config.
Consider also flagging a source file that has **no** consolidated entry.

## Validation / acceptance criteria

- Every `inventories/host_vars/*` and `inventories/group_vars/*` with a per-env source is a
  symlink to that source (`ls -la` shows `->`; `git ls-files -s` shows mode `120000`).
- No content is lost relative to what Semaphore currently applies (diff each consolidated file
  against its source before converting; merge, don't drop).
- For a representative host, the Semaphore-equivalent resolution matches the per-env source:
  ```bash
  ansible-inventory -i ansible/inventories/ --host <host>            # what Semaphore sees
  ansible-inventory -i ansible/inventories/manual/on_premise.yml --host <host>   # the source
  # the relevant vars (e.g. nfs_client_mounts, firewall_hardened_services) must match
  ```
- Re-running `pre-commit run --all-files` (which runs the sync hook) is a no-op afterward, and
  re-running it after editing a per-env source does NOT silently leave the consolidated copy stale.
- A targeted Semaphore run picks up a fresh edit to a per-env source on the first try.

## Notes for whoever picks this up

- This repo's pre-commit also runs gitleaks + terraform fmt; keep changes scoped to the inventory
  consolidation so the diff is reviewable.
- Roles `firewall_hardened` and `gitea` refuse to run from a laptop (lockout-guard); apply via
  **Semaphore**. But the symlink/sync fix itself is just file restructuring — validate locally
  with `ansible-inventory` (no host connection needed) before any Semaphore run.
- The firewall_hardened role **purges stale rules**: if you accidentally drop a service from a
  host's canonical file during the merge, the next apply will remove that firewall rule. Diff
  carefully.
