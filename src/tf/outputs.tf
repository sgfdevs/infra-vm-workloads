output "workload_vm_ids" {
  description = "Proxmox VM IDs for workload instances"
  value = {
    for name, vm in proxmox_virtual_environment_vm.workload :
    name => vm.vm_id
  }
}

output "ssh_private_key_ssm_path" {
  description = "SSM path for generated workload SSH private key"
  value       = module.ssh_key.ssm_path
}
