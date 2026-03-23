variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL (for example https://x86-node-01:8006/)"
  type        = string
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
