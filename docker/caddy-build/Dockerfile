# docker/caddy-build/Dockerfile
# Produces a custom static Caddy binary for the DMZ proxy, with:
#   - github.com/caddy-dns/cloudflare  (ECH publication + DNS-01 certs)
#   - github.com/mholt/caddy-l4        (MQTT-over-TLS layer4 stream)
#
# Build (amd64, to match the AlmaLinux DMZ host) and extract the binary:
#   docker build --platform linux/amd64 -t caddy-ech-l4 docker/caddy-build
#   id=$(docker create caddy-ech-l4); docker cp "$id:/caddy" ./caddy; docker rm "$id"
#
# Then publish ./caddy to an internal artifact location and set caddy_binary_url
# (+ caddy_binary_checksum) in group_vars/caddydmz/caddy_vars.yml.

ARG CADDY_VERSION=2.10.2

FROM caddy:${CADDY_VERSION}-builder AS build
ARG CADDY_VERSION
RUN xcaddy build v${CADDY_VERSION} \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/mholt/caddy-l4

# Verify the modules are present in the resulting binary.
RUN /usr/bin/caddy list-modules | grep -E 'dns.providers.cloudflare|layer4'

FROM scratch
COPY --from=build /usr/bin/caddy /caddy
