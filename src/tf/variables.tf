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

variable "dex_github_oauth_client_id" {
  description = "GitHub OAuth App client ID used by Dex"
  type        = string

  validation {
    condition     = trimspace(var.dex_github_oauth_client_id) != "" && upper(trimspace(var.dex_github_oauth_client_id)) != "CHANGEME"
    error_message = "dex_github_oauth_client_id must be a real GitHub OAuth App client ID."
  }
}

variable "b2_application_key_id" {
  description = "Backblaze B2 application key ID for Terraform bucket management"
  type        = string
  sensitive   = true
}

variable "b2_application_key" {
  description = "Backblaze B2 application key for Terraform bucket management"
  type        = string
  sensitive   = true
}
