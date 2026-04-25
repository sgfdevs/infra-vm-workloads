terraform {
  required_version = ">= 1.11.0"

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.33"
    }
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.12"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.97"
    }
    writeonly = {
      source  = "glitchedmob/writeonly"
      version = "~> 1.0"
    }
  }
}
