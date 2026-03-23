variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, including scheme and port"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in form user@realm!token=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Allow insecure Proxmox TLS"
  type        = bool
  default     = true
}

variable "expected_node_names" {
  description = "Optional list of expected node names for connectivity validation"
  type        = list(string)
  default     = []
}
