# SAFE TO COMMIT: Lab environment variables (non-sensitive only)
# Secrets (credentials and SSH keys) live in secrets.auto.tfvars which is ignored.

# vSphere connection (non-sensitive here; credentials moved to secrets.auto.tfvars)
vsphere_server       = "10.37.10.35"
allow_unverified_ssl = true

# vSphere inventory
datacenter = "Push Datacenter"
cluster    = "Lab Cluster"
datastore  = "ssd-local"
network    = "VLAN 70 - DMZ"
vm_folder  = "Templates/Lab"

# Template and VM settings
template_name    = "almalinux-10-minimal-template"
vm_name          = "almalinux10-lab"
cpu_count        = 2
memory_mb        = 2048
disk_size_gb     = 20
thin_provisioned = true

# Data disk
data_disk_size_gb = 10
data_mount_point  = "/data"
data_fs_type      = "ext4"

# SSH configuration (public/private keys moved to secrets.auto.tfvars)
vm_ssh_user = "root"
