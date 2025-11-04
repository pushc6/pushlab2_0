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

module "vm" {
  source = "../../modules/vm"

  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  network    = var.network
  vm_folder  = var.vm_folder

  template_name    = var.template_name
  vm_name          = var.vm_name
  cpu_count        = var.cpu_count
  memory_mb        = var.memory_mb
  disk_size_gb     = var.disk_size_gb
  thin_provisioned = var.thin_provisioned

  data_disk_size_gb = var.data_disk_size_gb
  data_mount_point  = var.data_mount_point
  data_fs_type      = var.data_fs_type

  vm_ssh_user     = var.vm_ssh_user
  ssh_public_key  = var.ssh_public_key
  ssh_private_key = var.ssh_private_key
}

// Write Ansible SSH private key material to ansible/ssh_key (0600)
resource "local_file" "ansible_ssh_key" {
  content              = var.ssh_private_key
  filename             = "${path.module}/../../../ansible/ssh_key"
  file_permission      = "0600"
  directory_permission = "0755"
}

// Generate a YAML inventory for lab with the single VM under [almalinux]
locals {
  ansible_inventory_yaml = yamlencode({
    all = {
      children = {
        almalinux = {
          hosts = {
            "${module.vm.vm_name}" = {
              ansible_host = module.vm.vm_ip
              ansible_user = var.vm_ssh_user
              system_hostname = module.vm.vm_name
              ansible_ssh_private_key_file = "../../ssh_key"
            }
          }
        }
      }
    }
  })
}

resource "local_file" "ansible_inventory_lab" {
  content              = local.ansible_inventory_yaml
  filename             = "${path.module}/../../../ansible/inventories/lab/hosts.yml"
  file_permission      = "0644"
  directory_permission = "0755"
  depends_on           = [local_file.ansible_ssh_key]
}
