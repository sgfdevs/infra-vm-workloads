module "k3s_data_owner" {
  for_each = local.k3s_vms

  source = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/proxmox-data-owner?ref=main"

  name         = "${each.key}-data"
  description  = "Persistent data disk owner for ${each.key}"
  tags         = ["tf", "sgfdevs", "k3s", "data-owner"]
  node_name    = each.value.node_name
  pool_id      = local.proxmox_pool_id
  datastore_id = "vmdata"
  disk_size_gb = 300
  disk_serial  = "${each.key}-data"
  protect      = false
}

module "k3s_vm" {
  for_each = local.k3s_vms

  source = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/proxmox-vm?ref=main"

  name        = each.key
  description = "Managed by OpenTofu for sgfdevs workload cluster"
  tags        = ["tf", "sgfdevs", "k3s"]
  node_name   = each.value.node_name
  pool_id     = local.proxmox_pool_id
  os_id       = "debian13"

  cpu_cores    = each.value.cpu_cores
  cpu_type     = each.value.cpu_type
  memory_mb    = each.value.memory_mb
  disk_size_gb = 80
  data_disks = {
    (local.data_disk_interface) = module.k3s_data_owner[each.key].disk
  }
  network_bridge = local.vm_network_bridge
  network_cidr   = local.sgfdevs_cidr
  ipv4_address   = each.value.ipv4_address
  vm_user        = local.vm_user

  ssh_public_keys    = [trimspace(module.ssh_key.public_key)]
  enable_guest_agent = true
}
