data "cloudflare_accounts" "sgfdevs" {
  provider  = cloudflare.sgfdevs
  max_items = 2
}

data "cloudflare_accounts" "opensgf" {
  provider  = cloudflare.opensgf
  max_items = 2
}

locals {
  cloudflare_sgfdevs_account_id = one(data.cloudflare_accounts.sgfdevs.result).id
  cloudflare_opensgf_account_id = one(data.cloudflare_accounts.opensgf.result).id

  cloudflare_tunnel_http_origin  = "http://traefik.kube-system.svc.cluster.local:80"
  cloudflare_tunnel_https_origin = "https://traefik.kube-system.svc.cluster.local:443"

  cloudflare_sgfdevs_tunnel_hostnames = [
    "sgf.dev",
    "*.sgf.dev",
    "methodconf.com",
    "*.methodconf.com",
    "hack4goodsgf.com",
    "*.hack4goodsgf.com",
  ]
  cloudflare_opensgf_tunnel_hostnames = [
    "opensgf.com",
    "*.opensgf.com",
    "opensgf.org",
    "*.opensgf.org",
    "takeshelternow.com",
    "*.takeshelternow.com",
    "takeshelternow.org",
    "*.takeshelternow.org",
  ]

  cloudflare_sgfdevs_tunnel_ingress = concat(
    flatten([
      for hostname in local.cloudflare_sgfdevs_tunnel_hostnames : [
        {
          hostname = hostname
          path     = "^/\\.well-known/acme-challenge/.*"
          service  = local.cloudflare_tunnel_http_origin
        },
        {
          hostname = hostname
          service  = local.cloudflare_tunnel_https_origin
          origin_request = {
            http2_origin      = true
            match_sn_ito_host = true
          }
        },
      ]
    ]),
    [{ service = "http_status:404" }],
  )
  cloudflare_opensgf_tunnel_ingress = concat(
    flatten([
      for hostname in local.cloudflare_opensgf_tunnel_hostnames : [
        {
          hostname = hostname
          path     = "^/\\.well-known/acme-challenge/.*"
          service  = local.cloudflare_tunnel_http_origin
        },
        {
          hostname = hostname
          service  = local.cloudflare_tunnel_https_origin
          origin_request = {
            http2_origin      = true
            match_sn_ito_host = true
          }
        },
      ]
    ]),
    [{ service = "http_status:404" }],
  )

  cloudflare_tunnel_token_ssm_paths = {
    sgfdevs = "/vm-workloads/sgfdevs/infra-vm-workloads/cloudflare-sgfdevs-tunnel-token"
    opensgf = "/vm-workloads/sgfdevs/infra-vm-workloads/cloudflare-opensgf-tunnel-token"
  }
  cloudflare_tunnel_token_ssm_versions = {
    sgfdevs = 1
    opensgf = 1
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "sgfdevs_k3s" {
  provider   = cloudflare.sgfdevs
  account_id = local.cloudflare_sgfdevs_account_id
  name       = "sgfdevs-infra-k8s-apps"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "sgfdevs_k3s" {
  provider   = cloudflare.sgfdevs
  account_id = local.cloudflare_sgfdevs_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.sgfdevs_k3s.id
  source     = "cloudflare"

  config = {
    ingress = local.cloudflare_sgfdevs_tunnel_ingress
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "opensgf_k3s" {
  provider   = cloudflare.opensgf
  account_id = local.cloudflare_opensgf_account_id
  name       = "opensgf-sgfdevs-k8s-apps"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "opensgf_k3s" {
  provider   = cloudflare.opensgf
  account_id = local.cloudflare_opensgf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.opensgf_k3s.id
  source     = "cloudflare"

  config = {
    ingress = local.cloudflare_opensgf_tunnel_ingress
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "sgfdevs_k3s" {
  provider   = cloudflare.sgfdevs
  account_id = local.cloudflare_sgfdevs_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.sgfdevs_k3s.id
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "opensgf_k3s" {
  provider   = cloudflare.opensgf
  account_id = local.cloudflare_opensgf_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.opensgf_k3s.id
}

resource "aws_ssm_parameter" "cloudflare_sgfdevs_tunnel_token" {
  name             = local.cloudflare_tunnel_token_ssm_paths.sgfdevs
  type             = "SecureString"
  value_wo         = data.cloudflare_zero_trust_tunnel_cloudflared_token.sgfdevs_k3s.token
  value_wo_version = local.cloudflare_tunnel_token_ssm_versions.sgfdevs
}

resource "aws_ssm_parameter" "cloudflare_opensgf_tunnel_token" {
  name             = local.cloudflare_tunnel_token_ssm_paths.opensgf
  type             = "SecureString"
  value_wo         = data.cloudflare_zero_trust_tunnel_cloudflared_token.opensgf_k3s.token
  value_wo_version = local.cloudflare_tunnel_token_ssm_versions.opensgf
}
