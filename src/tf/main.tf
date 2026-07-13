module "sgfdevs_k3s_cluster" {
  source = "./modules/k3s"
}

moved {
  from = module.ssh_key
  to   = module.sgfdevs_k3s_cluster.module.ssh_key
}

moved {
  from = module.flux_deploy_key
  to   = module.sgfdevs_k3s_cluster.module.git_deploy_key
}

moved {
  from = module.k3s_vm
  to   = module.sgfdevs_k3s_cluster.module.k3s_vm
}

moved {
  from = ansible_group.k3s_servers
  to   = module.sgfdevs_k3s_cluster.ansible_group.k3s_servers
}

moved {
  from = ansible_group.k3s_agents
  to   = module.sgfdevs_k3s_cluster.ansible_group.k3s_agents
}

moved {
  from = ansible_group.k3s_cluster
  to   = module.sgfdevs_k3s_cluster.ansible_group.k3s_cluster
}

moved {
  from = ansible_host.workload
  to   = module.sgfdevs_k3s_cluster.ansible_host.workload
}
