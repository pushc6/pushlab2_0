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
}

vm_ssh_user = "root"
