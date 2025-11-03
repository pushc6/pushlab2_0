# Production environment
vsphere_server       = "10.37.10.35"
allow_unverified_ssl = true

datacenter = "Push Datacenter"
cluster    = "Lab Cluster"
datastore  = "ssd-local"
network    = "VLAN 70 - DMZ"
vm_folder  = "Templates"

# Template to clone
template_name = "almalinux-10-minimal-template"

# Per-VM definitions
vms = {
  "almalinux10-prod-01" = {
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
    dns_servers  = []
    domain       = "localdomain"
  }
}

vm_ssh_user = "root"
