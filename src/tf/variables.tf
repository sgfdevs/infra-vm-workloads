variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL (for example https://x86-node-01:8006/)"
  type        = string

  validation {
    condition = (
      startswith(var.proxmox_endpoint, "https://") &&
      !can(regex("/api2/json/?$", var.proxmox_endpoint))
    )
    error_message = "proxmox_endpoint must be an https URL without /api2/json, for example https://x86-node-01:8006/"
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token in form user@realm!token=secret"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region for SSM parameters"
  type        = string
  default     = "us-east-2"
}
