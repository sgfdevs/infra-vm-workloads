locals {
  proxmox_pool_id   = "sgfdevs"
  sgfdevs_cidr      = "10.20.4.0/22"
  vm_network_bridge = "sgfdevs"
  vm_user           = "admin"

  ssm_key_prefix = "/vm-workloads/sgfdevs/infra-vm-workloads"

  k3s_vms = {
    sgfdevs-k3s-01 = {
      node_name    = "x86-node-01"
      ipv4_address = "10.20.4.10"
      role         = "server"
    }
    sgfdevs-k3s-02 = {
      node_name    = "x86-node-02"
      ipv4_address = "10.20.4.11"
      role         = "server"
    }
  }
}

module "ssh_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = "infra-vm-workloads"
  key_version          = 1
  ssm_private_key_path = "${local.ssm_key_prefix}/ssh-private-key"
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

  cpu_cores      = 4
  memory_mb      = 8192
  disk_size_gb   = 80
  network_bridge = local.vm_network_bridge
  network_cidr   = local.sgfdevs_cidr
  ipv4_address   = each.value.ipv4_address
  vm_user        = local.vm_user

  ssh_public_keys = [trimspace(module.ssh_key.public_key)]

  enable_guest_agent = true
}

module "flux_deploy_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = "flux-infra-vm-workloads"
  key_version          = 1
  ssm_private_key_path = "${local.ssm_key_prefix}/flux-git-private-key"
  ssm_public_key_path  = "${local.ssm_key_prefix}/flux-git-public-key"
}

resource "aws_ssm_parameter" "github_status_token" {
  name             = "${local.ssm_key_prefix}/flux-github-status-token"
  type             = "SecureString"
  value_wo         = "CHANGEME"
  value_wo_version = 1
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
  for_each = local.k3s_vms

  name = each.key
  groups = [
    "k3s_cluster",
    each.value.role == "server" ? "k3s_servers" : "k3s_agents",
  ]

  variables = {
    ansible_host                  = each.value.ipv4_address
    ansible_user                  = local.vm_user
    node_name                     = each.value.node_name
    ssm_private_key_path          = module.ssh_key.ssm_path
    ssm_flux_git_private_key_path = module.flux_deploy_key.ssm_path
    ssm_github_status_token_path  = aws_ssm_parameter.github_status_token.name
    proxmox_vm_role               = each.value.role
    ansible_ssh_use_ssh_agent     = "false"
  }
}
