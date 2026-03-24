locals {
  vm_ssh_key_name             = "infra-vm-workloads"
  vm_ssh_key_version          = 1
  vm_ssh_private_key_ssm_path = "/vm-workloads/sgfdevs/infra-vm-workloads/ssh-private-key"
  flux_key_name               = "flux-infra-vm-workloads"
  flux_key_version            = 1
  flux_git_private_key_path   = "/vm-workloads/sgfdevs/infra-vm-workloads/flux-git-private-key"
  flux_git_public_key_path    = "/vm-workloads/sgfdevs/infra-vm-workloads/flux-git-public-key"
  github_status_token_path    = "/vm-workloads/sgfdevs/infra-vm-workloads/flux-github-status-token"
}

module "ssh_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = local.vm_ssh_key_name
  key_version          = local.vm_ssh_key_version
  ssm_private_key_path = local.vm_ssh_private_key_ssm_path
}

module "flux_deploy_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = local.flux_key_name
  key_version          = local.flux_key_version
  ssm_private_key_path = local.flux_git_private_key_path
  ssm_public_key_path  = local.flux_git_public_key_path
}

resource "aws_ssm_parameter" "github_status_token" {
  name             = local.github_status_token_path
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
  for_each = local.k3s_nodes

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
