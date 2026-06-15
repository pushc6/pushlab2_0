# Runbook: docker-stacks DB major upgrades (2026)

Bring the database images in `rangernet/docker-stacks` current **without data loss**, replacing
Renovate's grouped PR #32 with one careful per-stack migration each.

## Execution status — completed 2026-06-14

All four bumps landed on `docker-stacks` main (commits `def101d`, `ff7b52e`, `3e208dd`,
`02dcdd6`, `524b715`). Each Postgres stack migrated via dump → fresh PG18 initdb → restore,
verified end-to-end. Backups (`.dump` + raw `.tgz`/`.pg17.bak`) live under
`~dockeruser/db-upgrade-backups/` on each host — **keep until ~2026-06-21, then delete**
(teslamate's `/nfs/teslamate/dbdata.pg17.bak` is ~1.7 GB on an 87%-full disk).

| Stack | Result | Verify |
|---|---|---|
| wolfbawt | postgres **18.4** | data restored; web HTTP 200; bot logged into Discord |
| keycloak | postgres **18.4** | 2 realms / 7 users; both realms' OIDC well-known → 200; collation warning gone |
| teslamate | postgres **18.4** | positions 12,461,834 / drives 4521 / charges 1900 — exact match; app+grafana up |
| ntopng (redis) | redis tag → **8.8-alpine** (source only) | not deployed; no migration; Redis 8 already runs elsewhere on the host |

Pre-existing issues seen but **out of scope** (not caused by this work): teslamate's Tesla
`fleet-api 403` token errors; plaintext secrets in the compose files.

## Scope

| Stack | Host | Change | Volume | DB user / uid |
|---|---|---|---|---|
| teslamate | `docker` (10.37.70.7) | postgres `17-trixie`→`18-trixie` | **bind** `/nfs/teslamate/dbdata` | `teslamate` / `1001:1001` |
| keycloak | `docker` (10.37.70.7) | postgres `16.14`→`18.4` | **named** `postgres_data` | from `.env` / default 999 |
| wolfbawt | `docker-internal` (10.37.70.25) | postgres `16-alpine`→`18-alpine` | **named** `pgdata` | `wolfbawt` / default 999 |
| ntopng | `docker-internal` (10.37.70.25) | redis `6.2-alpine`→`8.8-alpine` | **bind** `./redis` (Komodo clone-relative) | requirepass |

## Why not just merge PR #32

- PostgreSQL's on-disk format changes between majors. A PG18 binary **refuses to start** against a
  16/17 `PGDATA` — it fails safe (no corruption) but the service stays down until data is migrated.
- PG18 enables **data checksums by default** on `initdb`, which breaks naive in-place `pg_upgrade`.
  Hence dump → restore.
- Deploys are **Komodo GitOps**: merging the tag in `docker-stacks` triggers a redeploy on the
  Periphery agent, so each data migration must be sequenced *around* its merge — never a blind merge.
- Direct `16→18` (skipping 17) and Redis `6→8` are both fine via dump/restore and AOF replay.

### ⚠️ Two gotchas confirmed during the wolfbawt run (apply to every Postgres stack)

1. **`postgres:18` image moved `PGDATA`.** The 18+ image defaults `PGDATA` to a
   version-specific subdir (`/var/lib/postgresql/18/docker`) and declares its `VOLUME` at
   `/var/lib/postgresql`. All our stacks mount the data volume at `/var/lib/postgresql/data`, so
   PG18 **refuses to start** ("there appears to be PostgreSQL data in: /var/lib/postgresql/data
   (unused mount/volume)") and crash-loops. **Fix:** add
   `PGDATA: /var/lib/postgresql/data` to the postgres service `environment:` in the compose file
   (committed alongside the image bump). Keeps the existing mount; PG18 inits into it normally.
2. **Never `docker exec -t` for a dump.** The `-t` pseudo-TTY does CR/LF translation that
   **corrupts the binary custom-format dump** (`pg_restore` then fails with "could not read from
   input file: end of file"). Use `docker exec` (no `-t`) or `docker exec -i`.

Also note: `pg_stat_user_tables.n_live_tup` is a stale estimate — don't trust it as a row-count
baseline. Use real `COUNT(*)` (or just trust the dump's TOC + a clean `pg_restore`).

> **Security follow-up (out of scope here):** these compose files commit plaintext secrets
> (teslamate `DATABASE_PASS`, the Mailgun SMTP key, the pgadmin password). Move these to
> Komodo/`.env` secrets in a separate change.

## Pinned image targets (digests from PR #32)

- redis → `redis:8.8-alpine@sha256:09160599abd229764c0fb44cb6be640294e1d360a54b19985ab4843dcf2d90f1`
- wolfbawt → `postgres:18-alpine@sha256:96d56f7f57c6aacd1fcb908bc83b345ec5f83231ee486dd66a1baadce274db88`
- keycloak → `postgres:18.4@sha256:29ee7bb30d804447dc9a91fd0d74322ae1dc3a4072cc6346f70a5ed6e783b565`
- teslamate → `postgres:18-trixie@sha256:29ee7bb30d804447dc9a91fd0d74322ae1dc3a4072cc6346f70a5ed6e783b565`

---

## Pre-flight (once)

1. **Close grouped PR #32** — it is replaced by four per-stack changes. In the `docker-stacks`
   Renovate config, optionally separate major DB-engine bumps so they are never grouped or
   automergeable again (follow-up).
2. On each host, discover the real names (Komodo's compose project naming — do not assume):
   ```bash
   docker ps --format '{{.Names}}\t{{.Image}}'
   docker volume ls                 # look for *_postgres_data, *_pgdata
   docker inspect <container> --format '{{json .Mounts}}'   # clone dir for bind mounts
   ```
3. Create a backup dir with space headroom on each host: `mkdir -p ~/db-upgrade-backups`.
4. Schedule a maintenance window for **keycloak** (SSO — downstream services depend on it).

---

## Per-Postgres-stack procedure (dump → restore)

Applies to **wolfbawt**, **keycloak**, **teslamate**. Substitute `<db>` / `<user>` / `<container>`.

### A. Backup (OLD version still running)
```bash
# Logical dump (custom format) — the source of truth for restore.
# NO -t (it corrupts the binary dump). Run as dockeruser; docker needs no sudo for that user.
docker exec <container> pg_dump -U <user> -d <db> -Fc > ~/db-upgrade-backups/<stack>.dump

# Sanity check: non-trivial size + valid header
ls -lh ~/db-upgrade-backups/<stack>.dump
docker exec -i <container> pg_restore -l < ~/db-upgrade-backups/<stack>.dump | head
```
Also snapshot the raw data dir for fast rollback:
- **named volume** (keycloak, wolfbawt):
  ```bash
  docker run --rm -v <project>_<vol>:/data -v ~/db-upgrade-backups:/b alpine \
    tar czf /b/<stack>-datadir.tgz -C /data .
  ```
- **teslamate bind mount:**
  ```bash
  sudo tar czf ~/db-upgrade-backups/teslamate-datadir.tgz -C /nfs/teslamate dbdata
  ```

### B. Stop the stack
Via Komodo **Stop**, or `docker compose down` in the clone dir. For keycloak, ensure both
`keycloak` and `postgres` are down so nothing writes during the swap.

### C. Empty the data dir (so PG18 does a fresh initdb)
- **named volume:** `docker volume rm <project>_<vol>` (recreated empty on next deploy).
- **teslamate bind mount:**
  ```bash
  sudo mv /nfs/teslamate/dbdata /nfs/teslamate/dbdata.pg17.bak
  sudo install -d -o 1001 -g 1001 /nfs/teslamate/dbdata
  ```
  > **NFS caveat:** if `/nfs/teslamate` is an NFS export with `root_squash`, root `mv`/`chown`
  > fails (same trap as `/srv/docker/san`). Do the dir prep as the mapped owning uid, or
  > temporarily relax squash on the TrueNAS export and restore it afterward.

### D. Apply the image bump → let Komodo redeploy
Edit that stack's `image:` line to the pinned PG18 target **and add `PGDATA:
/var/lib/postgresql/data` to the postgres `environment:`** (see gotcha #1), on a per-stack branch;
commit; push to `main` (Komodo auto-redeploys via the Gitea webhook). PG18 `initdb` creates an
empty `<db>` from the `POSTGRES_*` env. Wait until ready:
```bash
docker exec <container> pg_isready -U <user>
```

### E. Restore
```bash
docker exec -i <container> pg_restore -U <user> -d <db> --clean --if-exists \
  < ~/db-upgrade-backups/<stack>.dump
```
A single-DB dump carries objects owned by `<user>`, which the new container recreates as the
superuser (roles/passwords come from `POSTGRES_*` env) — no `pg_dumpall` needed.

### F. Verify, then retain
Run the verification block below. Keep backups ~1 week before deleting `*.pg17.bak` /
`*-datadir.tgz`.

---

## ntopng / Redis procedure (low risk)

Redis 8 replays the existing AOF on startup, so this is close to a straight tag swap.

1. **Confirm compatibility first:** ntopng pins `:latest`; after redeploy, check its logs for Redis
   connection/version warnings. If ntopng rejects Redis 8, pin redis to `7-alpine` instead.
2. **Backup** the bind mount:
   ```bash
   docker exec ntopng-redis redis-cli -a redispassword SAVE
   sudo tar czf ~/db-upgrade-backups/ntopng-redis.tgz -C <clone_dir> redis
   ```
3. Bump the redis `image:` line to the pinned `8.8-alpine` target (per-stack branch → merge →
   Komodo redeploy).
4. Verify ntopng UI (`:3000`) loads, redis auth works, flows/prefs intact. Rollback = restore the
   tgz + revert the tag.

---

## Rollout order (one at a time; verify each before the next)

1. **ntopng / redis** — lowest risk; also validates the close-PR-then-per-stack-merge Komodo flow.
2. **wolfbawt** — small internal DB.
3. **keycloak** — SSO; maintenance window.
4. **teslamate** — largest dataset; bind mount + uid 1001 + NFS caveat.

---

## Verification (per stack, end-to-end)

- **wolfbawt:** web UI `:8000` loads; `bot`/`web` healthy; `docker exec <c> psql -U wolfbawt -d
  wolfbawt -c '\dt'` shows expected tables and row counts match pre-upgrade.
- **keycloak:** log in at `https://auth.push-lab.com`; realms, clients, users present; a downstream
  OAuth/SSO login works.
- **teslamate:** UI `:4000` and Grafana `:3001` load; historical data present;
  `select count(*) from positions;` matches pre-upgrade.
- **ntopng:** UI `:3000`; no Redis errors in logs; live flows + saved prefs intact.
- **General:** `docker inspect <c> --format '{{.Image}}'` matches the target digest;
  `docker exec <c> postgres --version` reports 18.x.

## Rollback (per stack)

1. Stop the stack.
2. Revert the `image:` line in git (redeploy old tag), or Komodo-redeploy the previous commit.
3. Restore data: named volume → recreate + untar `<stack>-datadir.tgz`; teslamate → `mv`
   `dbdata.pg17.bak` back into place.
4. Bring the stack up and verify. The `.dump` is the fallback if the raw snapshot is unusable.

---

## Appendix: Renovate config to stop grouping major DB upgrades

The grouped PR #32 happened because the **"shared base images"** rule in `docker-stacks/renovate.json`
matched `postgres`/`redis`/`eclipse-mosquitto` by name with **no `matchUpdateTypes` filter**, so it
swept majors into one cross-engine PR. The fix:

1. Scope the grouping rule to **non-major** updates only.
2. Add a **datastore-major** rule that splits majors **one PR per stack** (via
   `additionalBranchPrefix: "{{packageFileDir}}-"`). Without this, Renovate would still collapse all
   three `postgres`→18 bumps into a single PR, defeating the per-stack sequencing above.

> This config lives in the **`docker-stacks`** repo (not this one). Apply via the Gitea web editor
> on `renovate.json` or a branch/PR in that repo.

Updated `renovate.json` (changed: rule 3 + new rule 4; redundant `/^postgres$/` `/^redis$/` regex
dupes removed):

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    "docker:enableMajor",
    ":dependencyDashboard",
    ":semanticCommitsDisabled"
  ],
  "timezone": "America/New_York",
  "prHourlyLimit": 8,
  "prConcurrentLimit": 15,
  "docker-compose": {
    "managerFilePatterns": [
      "/(^|/)(docker-)?compose[^/]*\\.ya?ml$/"
    ]
  },
  "pinDigests": true,
  "packageRules": [
    {
      "description": "Hold automerge OFF until the loop is trusted; flip patch/digest to true later",
      "matchUpdateTypes": ["minor", "patch", "digest", "pin"],
      "automerge": false
    },
    {
      "description": "Major image bumps always get their own PR and stay manual",
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["major-update"]
    },
    {
      "description": "Group shared base images so one PR covers every stack using them - NON-major only",
      "matchUpdateTypes": ["minor", "patch", "digest", "pin"],
      "matchPackageNames": ["postgres", "redis", "eclipse-mosquitto"],
      "groupName": "shared base images"
    },
    {
      "description": "Major datastore bumps: never grouped; one PR per stack (per file) so each can be migrated + merged independently",
      "matchUpdateTypes": ["major"],
      "matchPackageNames": ["postgres", "redis", "mongo", "mariadb", "mysql"],
      "additionalBranchPrefix": "{{packageFileDir}}-",
      "labels": ["major-update", "datastore-major"]
    },
    {
      "description": "Group the big media stack into a single PR",
      "matchFileNames": ["docker/media/**"],
      "groupName": "media stack"
    },
    {
      "description": "Private Gitea-registry apps - keep separate, never automerge",
      "matchPackageNames": ["/^git\\.push-lab\\.com\\//"],
      "groupName": "push-lab registry apps",
      "automerge": false
    }
  ]
}
```

Resulting behavior:
- **Minor/patch/digest** of postgres/redis/mosquitto → still one grouped "shared base images" PR.
- **Major** datastore bumps → ungrouped, **one PR per compose file**, e.g.
  `renovate/docker/teslamate-postgres-18.x`, `renovate/docker/keycloak-postgres-18.x`,
  `renovate/docker-internal/wolfbawt-postgres-18.x` — each mergeable independently, labeled
  `datastore-major`.
