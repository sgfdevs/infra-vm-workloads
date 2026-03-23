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
  }))

  default = {
    vm-workload-01 = {
      node_name    = "x86-node-01"
      vm_id        = 4201
      ipv4_address = "10.20.4.10"
    }
    vm-workload-02 = {
      node_name    = "x86-node-02"
      vm_id        = 4202
      ipv4_address = "10.20.4.11"
    }
  }

  validation {
    condition     = length(var.workload_vms) == 2
    error_message = "Exactly two workload VMs must be defined."
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

variable "vm_user_ssh_public_key" {
  description = "SSH public key for cloud-init user"
  type        = string
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

variable "vm_template_file_id" {
  description = "Proxmox file identifier for cloud image/template"
  type        = string
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
