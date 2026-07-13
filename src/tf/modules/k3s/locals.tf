locals {
  proxmox_pool_id     = "sgfdevs"
  sgfdevs_cidr        = "10.20.4.0/22"
  vm_network_bridge   = "sgfdevs"
  vm_user             = "admin"
  data_disk_interface = "scsi1"

  ssm_key_prefix = "/vm-workloads/sgfdevs/infra-vm-workloads"

  ssm_eso_access_key_id_path     = "/homelab/sgfdevs-vms/eso-ssm-access-key-id"
  ssm_eso_secret_access_key_path = "/homelab/sgfdevs-vms/eso-ssm-secret-access-key"

  k3s_vms = {
    sgfdevs-k3s-01 = {
      node_name    = "x86-node-01"
      ipv4_address = "10.20.4.10"
      role         = "server"
      memory_mb    = 30 * 1024
      cpu_cores    = 8
      cpu_type     = "x86-64-v3"
    }
    sgfdevs-k3s-02 = {
      node_name    = "x86-node-02"
      ipv4_address = "10.20.4.11"
      role         = "server"
      memory_mb    = 14 * 1024
      cpu_cores    = 6
      cpu_type     = "x86-64-v3"
    }
    sgfdevs-k3s-03 = {
      node_name    = "x86-node-01"
      ipv4_address = "10.20.4.12"
      role         = "server"
      memory_mb    = 30 * 1024
      cpu_cores    = 8
      cpu_type     = "x86-64-v2-AES"
    }
  }
}
