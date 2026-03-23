output "workload_vm_ids" {
  description = "Proxmox VM IDs for workload instances"
  value = {
    for name, vm in proxmox_virtual_environment_vm.workload :
    name => vm.vm_id
  }
}

output "workload_vm_ipv4" {
  description = "Declared IPv4 addresses for workload VMs"
  value = {
    for name, spec in var.workload_vms :
    name => spec.ipv4_address
  }
}

output "ansible_hosts" {
  description = "Host map for Ansible inventory generation"
  value = {
    for name, spec in var.workload_vms :
    name => {
      ansible_host         = spec.ipv4_address
      ansible_user         = var.vm_user
      node_name            = spec.node_name
      vm_id                = spec.vm_id
      role                 = spec.role
      ssm_private_key_path = module.ssh_key.ssm_path
    }
  }
}

output "ssh_private_key_ssm_path" {
  description = "SSM path for generated workload SSH private key"
  value       = module.ssh_key.ssm_path
}
