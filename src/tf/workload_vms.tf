locals {
  sgfdevs_prefix        = tonumber(split("/", var.sgfdevs_cidr)[1])
  sgfdevs_gateway       = cidrhost(var.sgfdevs_cidr, 1)
  workload_node_names   = toset([for vm in values(var.workload_vms) : vm.node_name])
  vm_template_file_name = "debian-13-generic-amd64.qcow2"
  vm_template_image_url = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
}

resource "proxmox_virtual_environment_download_file" "debian13_cloud_image" {
  for_each = local.workload_node_names

  node_name    = each.value
  datastore_id = "iso"
  content_type = "iso"
  file_name    = local.vm_template_file_name
  url          = local.vm_template_image_url
}

resource "proxmox_virtual_environment_vm" "workload" {
  for_each = var.workload_vms

  name        = each.key
  description = "Managed by OpenTofu for sgfdevs workload cluster"
  tags        = ["managed-by-tofu", "sgfdevs", "k3s"]
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  pool_id     = var.proxmox_pool_id

  started = true
  on_boot = true

  agent {
    enabled = true
  }

  cpu {
    cores = var.vm_cpu_cores
    type  = var.vm_cpu_type
  }

  memory {
    dedicated = var.vm_memory_mb
    floating  = var.vm_memory_mb
  }

  disk {
    datastore_id = var.vm_datastore_id
    file_id      = proxmox_virtual_environment_download_file.debian13_cloud_image[each.value.node_name].id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.vm_disk_size_gb
  }

  network_device {
    bridge  = var.vm_network_bridge
    model   = "virtio"
    vlan_id = var.vm_vlan_id
  }

  initialization {
    datastore_id = var.vm_cloud_init_datastore_id

    ip_config {
      ipv4 {
        address = format("%s/%d", each.value.ipv4_address, local.sgfdevs_prefix)
        gateway = local.sgfdevs_gateway
      }
    }

    user_account {
      username = var.vm_user
      keys = concat(
        [module.ssh_key.public_key],
        [for key in var.vm_additional_ssh_public_keys : trimspace(key)]
      )
    }
  }

  operating_system {
    type = "l26"
  }

  depends_on = [terraform_data.proxmox_connectivity_check]
}
