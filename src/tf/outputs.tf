output "workload_vm_ids" {
  description = "Proxmox VM IDs for workload instances"
  value = {
    for name, vm in module.k3s_vm :
    name => vm.vm_id
  }
}

output "ssh_private_key_ssm_path" {
  description = "SSM path for generated workload SSH private key"
  value       = module.ssh_key.ssm_path
}

output "flux_git_private_key_ssm_path" {
  description = "SSM path for Flux Git deploy private key"
  value       = module.flux_deploy_key.ssm_path
}

output "flux_git_public_key" {
  description = "Flux Git deploy public key to add as repository deploy key"
  value       = module.flux_deploy_key.public_key
}

output "flux_git_public_key_ssm_path" {
  description = "SSM path for Flux Git deploy public key"
  value       = module.flux_deploy_key.ssm_public_key_path
}

output "flux_github_status_token_ssm_path" {
  description = "SSM path for Flux GitHub status token"
  value       = aws_ssm_parameter.github_status_token.name
}
