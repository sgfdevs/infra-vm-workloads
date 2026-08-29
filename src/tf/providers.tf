provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}

provider "aws" {
  region = var.aws_region
}

provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}

provider "cloudflare" {
  alias     = "sgfdevs"
  api_token = var.cloudflare_sgfdevs_api_token
}

provider "cloudflare" {
  alias     = "opensgf"
  api_token = var.cloudflare_opensgf_api_token
}
