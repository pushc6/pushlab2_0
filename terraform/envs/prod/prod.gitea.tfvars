# Overlay to deploy ONLY the Gitea VM in prod. Use with -var-file=prod.tfvars -var-file=prod.gitea.tfvars

vms = {
  "gitea" = {
    network          = "VLAN 80 - App"
    cpu_count        = 4
    memory_mb        = 6144
    disk_size_gb     = 40
    thin_provisioned = true

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
