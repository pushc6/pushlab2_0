# Custom Caddy build (ECH + caddy-l4)

The stock Caddy binary does not include third-party modules, so the DMZ proxy
needs a custom build that bundles:

| Module | Purpose |
| --- | --- |
| `github.com/caddy-dns/cloudflare` | ECH config publication to HTTPS DNS records + DNS-01 cert issuance |
| `github.com/mholt/caddy-l4` | MQTT-over-TLS layer4 stream (replaces the nginx `stream{}` block) |

Caddy **≥ 2.10** is required (native ECH; past the Cloudflare ECH-publish fix,
caddy issue #6887).

## Build & extract the binary

```bash
docker build --platform linux/amd64 \
  --build-arg CADDY_VERSION=2.10.2 \
  -t caddy-ech-l4 docker/caddy-build

id=$(docker create caddy-ech-l4)
docker cp "$id:/caddy" ./caddy
docker rm "$id"

sha256sum ./caddy   # record for caddy_binary_checksum
```

## Publish & wire up

1. Upload `./caddy` to an internal artifact location reachable by the DMZ host
   (e.g. a Gitea release on `git.push-lab.com`, or an internal HTTP share).
2. Set in `ansible/group_vars/caddydmz/caddy_vars.yml`:
   - `caddy_binary_url` → the artifact URL
   - `caddy_binary_checksum` → `sha256:<sum>`
3. Deploy with `ansible-playbook -i inventories/manual/on_premise.yml deploy_caddy_proxy.yml`.

> This binary statically links its own copy of dependencies; rebuild and
> re-publish on Caddy/module releases (this is the maintenance trade vs. a
> distro package — far cheaper than the nginx+OpenSSL-from-source alternative).
