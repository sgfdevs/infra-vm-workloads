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

variable "proxmox_pool_id" {
  description = "Proxmox pool for workload VMs"
  type        = string
  default     = "sgfdevs"
}

variable "workload_vms" {
  description = "Workload VMs to provision"
  type = map(object({
    node_name    = string
    vm_id        = number
    ipv4_address = string
    role         = string
  }))

  default = {
    vm-workload-01 = {
      node_name    = "x86-node-01"
      vm_id        = 4201
      ipv4_address = "10.20.4.10"
      role         = "server"
    }
    vm-workload-02 = {
      node_name    = "x86-node-02"
      vm_id        = 4202
      ipv4_address = "10.20.4.11"
      role         = "agent"
    }
  }

  validation {
    condition     = length(var.workload_vms) == 2
    error_message = "Exactly two workload VMs must be defined."
  }

  validation {
    condition = alltrue([
      for vm in values(var.workload_vms) : contains(["server", "agent"], vm.role)
    ])
    error_message = "Each workload VM role must be either 'server' or 'agent'."
  }
}

variable "sgfdevs_cidr" {
  description = "CIDR for sgfdevs workload network"
  type        = string
  default     = "10.20.4.0/22"
}

variable "vm_user" {
  description = "Primary cloud-init username"
  type        = string
  default     = "ubuntu"
}

variable "vm_additional_ssh_public_keys" {
  description = "Optional additional SSH public keys for cloud-init user"
  type        = list(string)
  default     = []
}

variable "vm_ssh_key_name" {
  description = "Identifier for generated workload SSH key"
  type        = string
  default     = "infra-vm-workloads"
}

variable "vm_cpu_cores" {
  description = "CPU cores per workload VM"
  type        = number
  default     = 4
}

variable "vm_cpu_type" {
  description = "CPU model for workload VMs"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_memory_mb" {
  description = "Memory in MB per workload VM"
  type        = number
  default     = 8192
}

variable "vm_disk_size_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 80
}

variable "vm_datastore_id" {
  description = "Proxmox datastore for root disks"
  type        = string
  default     = "vm-data"
}

variable "vm_cloud_init_datastore_id" {
  description = "Datastore for cloud-init disk"
  type        = string
  default     = "vm-data"
}

variable "vm_network_bridge" {
  description = "Bridge for VM network interface"
  type        = string
  default     = "vmbr0"
}

variable "vm_vlan_id" {
  description = "VLAN ID for workload VM network"
  type        = number
  default     = 13
}
