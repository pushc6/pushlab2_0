# Production environment
vsphere_server       = "10.37.10.35"
allow_unverified_ssl = true

datacenter = "Push Datacenter"
cluster    = "Lab Cluster"
datastore  = "ssd-local"
network    = "VLAN 70 - DMZ"
vm_folder  = "Templates"

# Template to clone
template_name = "almalinux-10-minimal-template-20251104"

# Per-VM definitions
vms = {
  "truenas-proxy" = {
    cpu_count         = 4
    memory_mb         = 8192
    disk_size_gb      = 60
    thin_provisioned  = true
    data_disk_size_gb = 40
    data_mount_point  = "/data"
    data_fs_type      = "xfs"
    # Static IP configuration (set to DHCP by leaving ipv4_address empty)
    ipv4_address = "10.37.70.42"
    ipv4_netmask = 24
    ipv4_gateway = "10.37.70.1"
    dns_servers  = ["10.37.80.2"]
    domain       = "localdomain"
  }
  # Gitea server VM (adjust IP/DNS to your environment)
  "gitea" = {
    network          = "VLAN 80 - App"
    hostname         = "gitea"
    cpu_count        = 4
    memory_mb        = 6144
    disk_size_gb     = 40
    thin_provisioned = true
    # Optional separate data disk mounted at /var/lib/gitea
    data_disk_size_gb = 50
    data_mount_point  = "/var/lib/gitea"
    data_fs_type      = "xfs"
    # Set a static IP on VLAN 80 - App or leave empty for DHCP
    ipv4_address = "10.37.80.4"
    ipv4_netmask = 24
    ipv4_gateway = "10.37.80.1"
    dns_servers  = ["10.37.80.2"]
    domain       = "localdomain"
  }
}

vm_ssh_user = "root"
