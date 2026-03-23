locals {
  sgfdevs_prefix  = tonumber(split("/", var.sgfdevs_cidr)[1])
  sgfdevs_gateway = cidrhost(var.sgfdevs_cidr, 1)
  vm_template_file_ids = {
    x86-node-01 = "x86-node-01:iso/debian-13-generic-amd64.qcow2"
    x86-node-02 = "x86-node-02:iso/debian-13-generic-amd64.qcow2"
  }
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
    file_id      = local.vm_template_file_ids[each.value.node_name]
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

  lifecycle {
    precondition {
      condition     = contains(keys(local.vm_template_file_ids), each.value.node_name)
      error_message = "No VM template file ID is configured for node '${each.value.node_name}'."
    }
  }
}
