locals {
  proxmox_pool_id               = "sgfdevs"
  sgfdevs_cidr                  = "10.20.4.0/22"
  vm_user                       = "admin"
  vm_additional_ssh_public_keys = []
  vm_cpu_cores                  = 4
  vm_cpu_type                   = "x86-64-v2-AES"
  vm_memory_mb                  = 8192
  vm_disk_size_gb               = 80
  vm_datastore_id               = "vmdata"
  vm_cloud_init_datastore_id    = "vmdata"
  vm_network_bridge             = "sgfdevs"

  workload_vms = {
    vm-workload-01 = {
      node_name    = "x86-node-01"
      vm_id        = 4201
      ipv4_address = "10.20.4.10"
      role         = "server"
    }
    vm-workload-02 = {
      node_name    = "x86-node-02"
      vm_id        = 4202
      ipv4_address = "10.20.4.11"
      role         = "agent"
    }
  }

  sgfdevs_prefix  = tonumber(split("/", local.sgfdevs_cidr)[1])
  sgfdevs_gateway = cidrhost(local.sgfdevs_cidr, 1)
}

resource "proxmox_virtual_environment_vm" "workload" {
  for_each = local.workload_vms

  name        = each.key
  description = "Managed by OpenTofu for sgfdevs workload cluster"
  tags        = ["managed-by-tofu", "sgfdevs", "k3s"]
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  pool_id     = local.proxmox_pool_id

  started = true
  on_boot = true

  cpu {
    cores = local.vm_cpu_cores
    type  = local.vm_cpu_type
  }

  memory {
    dedicated = local.vm_memory_mb
    floating  = local.vm_memory_mb
  }

  disk {
    datastore_id = local.vm_datastore_id
    import_from  = "local:import/debian-13-generic-amd64.qcow2"
    interface    = "scsi0"
    discard      = "on"
    size         = local.vm_disk_size_gb
  }

  network_device {
    bridge = local.vm_network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = local.vm_cloud_init_datastore_id

    ip_config {
      ipv4 {
        address = format("%s/%d", each.value.ipv4_address, local.sgfdevs_prefix)
        gateway = local.sgfdevs_gateway
      }
    }

    user_account {
      username = local.vm_user
      keys = concat(
        [trimspace(module.ssh_key.public_key)],
        [for key in local.vm_additional_ssh_public_keys : trimspace(key)]
      )
    }
  }

  operating_system {
    type = "l26"
  }
}
