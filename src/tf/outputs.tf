output "proxmox_available_node_names" {
  description = "Node names returned by Proxmox API"
  value       = data.proxmox_virtual_environment_nodes.available.names
}

output "proxmox_connectivity_check" {
  description = "Connectivity check payload"
  value       = terraform_data.proxmox_connectivity_check.output
  sensitive   = true
}
