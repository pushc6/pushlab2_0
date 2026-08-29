# Production environment
vsphere_server       = "10.37.10.35"
allow_unverified_ssl = true

datacenter = "Push Datacenter"
cluster    = "Lab Cluster"
datastore  = "ssd-local"
network    = "VLAN 70 - DMZ"
vm_folder  = "Templates"

# Template to clone (rebuilt with cloud-init 2025-12-14)
template_name = "almalinux-10-minimal-template"

# Per-VM definitions
vms = {
  # Gitea server VM (adjust IP/DNS to your environment)
  "gitea" = {
    network          = "VLAN 80 - App"
    cpu_count        = 4
    memory_mb        = 6144
    disk_size_gb     = 40
    thin_provisioned = true
    # Protect this critical VM from accidental destroy/recreate
    prevent_destroy = true

    # Separate data disk for repositories and app data
    data_disk_size_gb = 50
    data_mount_point  = "/var/lib/gitea"
    data_fs_type      = "xfs"

    # Static IP on VLAN 80
    ipv4_address = "10.37.80.4"
    ipv4_netmask = 24
    ipv4_gateway = "10.37.80.1"
    dns_servers  = ["10.37.80.2"]
    domain       = "localdomain"
  }

  # Secondary DNS server - multi-homed across all VLANs
  "dns02" = {
    network          = "VLAN 10 - Management"
    cpu_count        = 2
    memory_mb        = 8192
    disk_size_gb     = 40
    thin_provisioned = true
    hostname         = "dns02"
    domain           = "localdomain"

    ipv4_address = "10.37.10.254"
    ipv4_netmask = 24
    ipv4_gateway = "" # No gateway - Management VLAN has no WAN access
    dns_servers  = ["10.37.10.2"]

    # Primary interface IPv6: static ULA, no RA acceptance (VLAN 10 has no
    # upstream router we want to learn from). Suppresses the rogue default
    # route that OPNsense's RA on this VLAN would otherwise install.
    ipv6_address = "fd00:1337:1337:0010::254/64"
    accept_ra    = false

    # Use DMZ VLAN IP for Ansible: Semaphore (10.37.70.25) sits on this same
    # segment, so the path is symmetric. Reaching the App VLAN IP instead makes
    # the reply leave via eth4 while the request arrived on eth8, which strict
    # rp_filter (RHEL default on this 9-homed host) drops silently.
    ansible_host = "10.37.70.254"

    # Cloud-init will configure all additional interfaces with static IPs
    # Default gateway is set on App VLAN which has WAN access
    # IPv6 config mirrors dns01 (docker-secure)'s netplan:
    #   - stable ULA fd00:1337:1337:00X0::254/64 on every VLAN (parity with the .254 v4 convention)
    #   - accept_ra=true and ipv6_gateway only on App VLAN (uplink)
    #   - accept_ra=false elsewhere to prevent spurious GUAs from RAs
    # The IPv6 default route is critical: without it, the Technitium container
    # prefers AAAA records, tries IPv6, and hangs until install timeout.
    # The cloud-init runcmd fixup flips NM's ipv6.method=manual to "auto" on
    # the uplink so SLAAC runs alongside the static ULA -- otherwise NM under
    # method=manual suppresses RA acceptance and eth7 never gets a GUA.
    additional_interfaces = [
      { network_name = "VLAN 20 - Trusted", ipv4_address = "10.37.20.254", ipv4_netmask = 24, ipv6_address = "fd00:1337:1337:0020::254/64", accept_ra = false },
      { network_name = "VLAN 30 - Storage", ipv4_address = "10.37.30.254", ipv4_netmask = 24, ipv6_address = "fd00:1337:1337:0030::254/64", accept_ra = false },
      { network_name = "VLAN 40 - LAN Only (No WAN)", ipv4_address = "10.37.40.254", ipv4_netmask = 24, ipv6_address = "fd00:1337:1337:0040::254/64", accept_ra = false },
      { network_name = "VLAN 50 - IoT", ipv4_address = "10.37.50.254", ipv4_netmask = 24, ipv6_address = "fd00:1337:1337:0050::254/64", accept_ra = false },
      { network_name = "VLAN 60 - Guest", ipv4_address = "10.37.60.254", ipv4_netmask = 24, ipv6_address = "fd00:1337:1337:0060::254/64", accept_ra = false },
      { network_name = "VLAN 70 - DMZ", ipv4_address = "10.37.70.254", ipv4_netmask = 24, ipv6_address = "fd00:1337:1337:0070::254/64", accept_ra = false },
      { network_name = "VLAN 80 - App", ipv4_address = "10.37.80.254", ipv4_netmask = 24, ipv4_gateway = "10.37.80.1", ipv6_address = "fd00:1337:1337:0080::254/64", ipv6_gateway = "fe80::250:56ff:febc:bf", accept_ra = true },
      { network_name = "VLAN 100 - Test", ipv4_address = "10.37.100.254", ipv4_netmask = 24, ipv6_address = "fd00:1337:1337:0100::254/64", accept_ra = false }
    ]
  }

  # Dedicated Packer build VM with native Gitea Actions runner
  "packer_builder" = {
    network          = "VLAN 80 - App"
    hostname         = "packer-builder"
    cpu_count        = 4
    memory_mb        = 8192
    disk_size_gb     = 60
    thin_provisioned = true
    prevent_destroy  = false

    ipv4_address = "10.37.80.5"
    ipv4_netmask = 24
    ipv4_gateway = "10.37.80.1"
    dns_servers  = ["10.37.80.2"]
    domain       = "localdomain"
  }
}

vm_ssh_user = "root"
