locals {
  vm_ssh_key_name             = "infra-vm-workloads"
  vm_ssh_key_version          = 1
  vm_ssh_private_key_ssm_path = "/vm-workloads/sgfdevs/infra-vm-workloads/ssh-private-key"
}

module "ssh_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = local.vm_ssh_key_name
  key_version          = local.vm_ssh_key_version
  ssm_private_key_path = local.vm_ssh_private_key_ssm_path
}

resource "ansible_group" "k3s_servers" {
  name = "k3s_servers"
}

resource "ansible_group" "k3s_agents" {
  name = "k3s_agents"
}

resource "ansible_group" "k3s_cluster" {
  name     = "k3s_cluster"
  children = [ansible_group.k3s_servers.name, ansible_group.k3s_agents.name]
}

resource "ansible_host" "workload" {
  for_each = local.k3s_nodes

  name = each.key
  groups = [
    "k3s_cluster",
    each.value.role == "server" ? "k3s_servers" : "k3s_agents",
  ]

  variables = {
    ansible_host              = each.value.ipv4_address
    ansible_user              = local.vm_user
    node_name                 = each.value.node_name
    ssm_private_key_path      = module.ssh_key.ssm_path
    proxmox_vm_role           = each.value.role
    ansible_ssh_use_ssh_agent = "false"
  }
}
