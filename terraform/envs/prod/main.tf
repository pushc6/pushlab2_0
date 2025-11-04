terraform {
  required_version = ">= 1.0"
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.15"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = var.allow_unverified_ssl
}

locals {
  effective_private_key = var.ssh_private_key_file != "" ? file(var.ssh_private_key_file) : var.ssh_private_key
}

module "vm" {
  source   = "../../modules/vm"
  for_each = var.vms

  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  # Prefer per-VM network override when provided; fall back to root var.network
  network    = coalesce(try(each.value.network, null), var.network)
  vm_folder  = var.vm_folder

  template_name    = var.template_name
  vm_name          = each.key
  cpu_count        = each.value.cpu_count
  memory_mb        = each.value.memory_mb
  disk_size_gb     = each.value.disk_size_gb
  thin_provisioned = each.value.thin_provisioned

  data_disk_size_gb = each.value.data_disk_size_gb
  data_mount_point  = each.value.data_mount_point
  data_fs_type      = each.value.data_fs_type

  vm_ssh_user = var.vm_ssh_user

  ssh_public_key  = var.ssh_public_key
  ssh_private_key = local.effective_private_key

  # Optional static IP customization (if provided per-VM)
  ipv4_address    = try(each.value.ipv4_address, "")
  ipv4_netmask    = try(each.value.ipv4_netmask, 24)
  ipv4_gateway    = try(each.value.ipv4_gateway, "")
  dns_server_list = try(each.value.dns_servers, [])
  domain          = try(each.value.domain, "localdomain")
}

// Write Ansible SSH private key material to ansible/ssh_key (0600)
resource "local_file" "ansible_ssh_key" {
  content              = local.effective_private_key
  filename             = "${path.module}/../../../ansible/ssh_key"
  file_permission      = "0600"
  directory_permission = "0755"
}

// Generate a simple inventory with the VM IPs under group [almalinux]
locals {
  ansible_inventory_lines = concat([
    "[almalinux]"
  ], [for name, m in module.vm : "${name} ansible_host=${m.vm_ip} ansible_user=${var.vm_ssh_user}"])
}

// YAML inventory compatible with Ansible
locals {
  ansible_inventory_yaml = yamlencode({
    all = {
      children = {
        almalinux = {
          hosts = { for name, m in module.vm : name => {
            ansible_host     = m.vm_ip
            ansible_user     = var.vm_ssh_user
            system_hostname  = try(var.vms[name].hostname, name)
            ansible_ssh_private_key_file = "../../ssh_key"
          } }
        }
      }
    }
  })
}

resource "local_file" "ansible_inventory_prod" {
  content              = local.ansible_inventory_yaml
  filename             = "${path.module}/../../../ansible/inventories/prod/hosts.yml"
  file_permission      = "0644"
  directory_permission = "0755"
  depends_on           = [local_file.ansible_ssh_key]
}

output "vm_names" {
  value = keys(module.vm)
}
output "vm_ips" {
  value = { for k in keys(module.vm) : k => (can(module.vm[k].vm_ip) ? module.vm[k].vm_ip : null) }
}
