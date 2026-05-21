#!/usr/bin/env python3
# Technitium DHCP reservation sync.
#
# Mirrors per-scope DHCP reservations from a source Technitium instance to a
# destination Technitium instance. One-way (source -> dest). On any per-scope
# mismatch, the destination's reservations for that scope are purged and
# rewritten from the source.
#
# Scopes themselves are NOT created or modified -- they must already exist on
# the destination with matching subnet/pool. Active leases are NOT synced
# (no Technitium API exposes that today).
#
# Configuration is read from environment variables (typically populated by
# systemd via EnvironmentFile=):
#
#   TDNS_SOURCE_SCHEME  http|https              (default: http)
#   TDNS_SOURCE_HOST    hostname-or-ip          (required)
#   TDNS_SOURCE_PORT    1-65535                 (default: 5380)
#   TDNS_SOURCE_TOKEN   API token               (required)
#   TDNS_DEST_SCHEME    http|https              (default: http)
#   TDNS_DEST_HOST      hostname-or-ip          (required)
#   TDNS_DEST_PORT      1-65535                 (default: 5380)
#   TDNS_DEST_TOKEN     API token               (required)
#   TDNS_TIMEOUT        seconds                 (default: 10)
#   TDNS_VERIFY_TLS     true|false              (default: true)
#
# Derived from the approach in mrjackson/MiscScripts
# (https://github.com/mrjackson/MiscScripts/blob/main/technitium_dhcp_scope_reserve_sync.py).
# Rewritten for environment-driven config, structured logging, scoped error
# handling, and HTTPS support.

from __future__ import annotations

import logging
import os
import sys
from dataclasses import dataclass

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

LOG = logging.getLogger("technitium-reservation-sync")


@dataclass(frozen=True)
class Endpoint:
    scheme: str
    host: str
    port: int
    token: str

    @property
    def base(self) -> str:
        return f"{self.scheme}://{self.host}:{self.port}"


class ApiError(RuntimeError):
    pass


def _require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"missing required env var: {name}")
    return value


def _endpoint(prefix: str) -> Endpoint:
    return Endpoint(
        scheme=os.environ.get(f"{prefix}_SCHEME", "http").strip() or "http",
        host=_require_env(f"{prefix}_HOST"),
        port=int(os.environ.get(f"{prefix}_PORT", "5380")),
        token=_require_env(f"{prefix}_TOKEN"),
    )


def _make_session(verify_tls: bool) -> requests.Session:
    s = requests.Session()
    s.verify = verify_tls
    retry = Retry(
        total=3,
        backoff_factor=0.5,
        status_forcelist=(500, 502, 503, 504),
        allowed_methods=frozenset(("GET", "POST")),
    )
    adapter = HTTPAdapter(max_retries=retry)
    s.mount("http://", adapter)
    s.mount("https://", adapter)
    return s


def _api_call(
    session: requests.Session,
    endpoint: Endpoint,
    path: str,
    params: dict,
    timeout: float,
) -> dict:
    url = f"{endpoint.base}{path}"
    merged = {"token": endpoint.token, **params}
    resp = session.get(url, params=merged, timeout=timeout)
    resp.raise_for_status()
    data = resp.json()
    if data.get("status") != "ok":
        raise ApiError(f"{path} returned status={data.get('status')!r} body={data!r}")
    return data.get("response") or {}


def list_scopes(session, endpoint, timeout) -> list[str]:
    body = _api_call(session, endpoint, "/api/dhcp/scopes/list", {}, timeout)
    return [s["name"] for s in body.get("scopes", [])]


def get_reservations(session, endpoint, timeout, scope: str) -> list[dict]:
    body = _api_call(
        session, endpoint, "/api/dhcp/scopes/get", {"name": scope}, timeout
    )
    return list(body.get("reservedLeases") or [])


def remove_reservation(session, endpoint, timeout, scope: str, hw: str) -> None:
    _api_call(
        session,
        endpoint,
        "/api/dhcp/scopes/removeReservedLease",
        {"name": scope, "hardwareAddress": hw},
        timeout,
    )


def add_reservation(session, endpoint, timeout, scope: str, res: dict) -> None:
    params = {
        "name": scope,
        "hardwareAddress": res["hardwareAddress"],
        "ipAddress": res["address"],
    }
    if res.get("hostName"):
        params["hostName"] = res["hostName"]
    if res.get("comments"):
        params["comments"] = res["comments"]
    _api_call(
        session, endpoint, "/api/dhcp/scopes/addReservedLease", params, timeout
    )


def _reservation_key(res: dict) -> tuple:
    return (
        res.get("hardwareAddress", "").lower(),
        res.get("address", ""),
        res.get("hostName") or "",
        res.get("comments") or "",
    )


def reservations_equal(src: list[dict], dst: list[dict]) -> bool:
    return sorted(_reservation_key(r) for r in src) == sorted(
        _reservation_key(r) for r in dst
    )


def sync_scope(
    session,
    src: Endpoint,
    dst: Endpoint,
    timeout: float,
    scope: str,
) -> bool:
    """Returns True if any change was applied."""
    src_res = get_reservations(session, src, timeout, scope)
    dst_res = get_reservations(session, dst, timeout, scope)

    if reservations_equal(src_res, dst_res):
        LOG.debug("scope %r: %d reservations, in sync", scope, len(src_res))
        return False

    LOG.info(
        "scope %r: drift detected (src=%d, dst=%d) -- purge+copy",
        scope,
        len(src_res),
        len(dst_res),
    )
    for r in dst_res:
        remove_reservation(session, dst, timeout, scope, r["hardwareAddress"])
    for r in src_res:
        add_reservation(session, dst, timeout, scope, r)
    return True


def main() -> int:
    logging.basicConfig(
        level=os.environ.get("TDNS_LOG_LEVEL", "INFO").upper(),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    src = _endpoint("TDNS_SOURCE")
    dst = _endpoint("TDNS_DEST")
    timeout = float(os.environ.get("TDNS_TIMEOUT", "10"))
    verify_tls = os.environ.get("TDNS_VERIFY_TLS", "true").lower() != "false"
    session = _make_session(verify_tls)

    LOG.info("syncing reservations from %s -> %s", src.host, dst.host)
    src_scopes = list_scopes(session, src, timeout)
    if not src_scopes:
        LOG.info("no scopes on source; nothing to do")
        return 0

    # Intersect with destination scopes -- source scopes that don't exist on
    # dest are skipped. This avoids "DHCP scope was not found" errors in the
    # destination's web service log every sync cycle for scopes (e.g.
    # "VLAN100 (Unused)") that intentionally exist on the primary but not
    # on the secondary.
    dst_scopes = set(list_scopes(session, dst, timeout))
    syncable = [s for s in src_scopes if s in dst_scopes]
    skipped = [s for s in src_scopes if s not in dst_scopes]
    if skipped:
        LOG.info("skipping %d scope(s) absent on destination: %s",
                 len(skipped), ", ".join(skipped))

    changed = 0
    failed = 0
    for scope in syncable:
        try:
            if sync_scope(session, src, dst, timeout, scope):
                changed += 1
        except (ApiError, requests.RequestException) as e:
            failed += 1
            LOG.error("scope %r: sync failed: %s", scope, e)

    LOG.info(
        "done: %d source / %d syncable / %d changed / %d failed",
        len(src_scopes),
        len(syncable),
        changed,
        failed,
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
