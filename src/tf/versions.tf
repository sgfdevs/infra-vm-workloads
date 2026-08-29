terraform {
  required_version = ">= 1.12"

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.58"
    }
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.13"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.23"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    writeonly = {
      source  = "glitchedmob/writeonly"
      version = "~> 1.0"
    }
  }
}
