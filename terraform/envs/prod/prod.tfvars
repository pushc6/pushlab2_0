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

    # Cloud-init will configure all additional interfaces with static IPs
    # Default gateway is set on App VLAN which has WAN access
    additional_interfaces = [
      { network_name = "VLAN 20 - Trusted", ipv4_address = "10.37.20.254", ipv4_netmask = 24 },
      { network_name = "VLAN 30 - Storage", ipv4_address = "10.37.30.254", ipv4_netmask = 24 },
      { network_name = "VLAN 40 - LAN Only (No WAN)", ipv4_address = "10.37.40.254", ipv4_netmask = 24 },
      { network_name = "VLAN 50 - IoT", ipv4_address = "10.37.50.254", ipv4_netmask = 24 },
      { network_name = "VLAN 60 - Guest", ipv4_address = "10.37.60.254", ipv4_netmask = 24 },
      { network_name = "VLAN 80 - App", ipv4_address = "10.37.80.254", ipv4_netmask = 24, ipv4_gateway = "10.37.80.1" },
      { network_name = "VLAN 100 - Test", ipv4_address = "10.37.100.254", ipv4_netmask = 24 }
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
