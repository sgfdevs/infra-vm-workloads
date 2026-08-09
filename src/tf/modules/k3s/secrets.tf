module "ssh_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = "infra-vm-workloads"
  key_version          = 1
  ssm_private_key_path = "${local.ssm_key_prefix}/ssh-private-key"
}

module "git_deploy_key" {
  source               = "git::https://github.com/glitchedmob/infra-shared.git//src/tf/modules/ssh-key?ref=main"
  name                 = "infra-vm-workloads"
  key_version          = 1
  ssm_private_key_path = "${local.ssm_key_prefix}/git-deploy-private-key"
  ssm_public_key_path  = "${local.ssm_key_prefix}/git-deploy-public-key"
}

ephemeral "random_bytes" "openbao_unseal" { length = 32 }
resource "aws_ssm_parameter" "openbao_unseal_key" {
  name             = "${local.ssm_key_prefix}/openbao-unseal-key"
  type             = "SecureString"
  value_wo         = ephemeral.random_bytes.openbao_unseal.base64
  value_wo_version = 1
  lifecycle { prevent_destroy = true }
}

resource "aws_ssm_parameter" "dex_github_oauth_client_secret" {
  name             = "${local.ssm_key_prefix}/dex-github-oauth-client-secret"
  type             = "SecureString"
  value_wo         = "CHANGEME"
  value_wo_version = 1

  lifecycle { prevent_destroy = true }
}

moved {
  from = aws_ssm_parameter.github_oauth_client_secret["dex"]
  to   = aws_ssm_parameter.dex_github_oauth_client_secret
}

ephemeral "random_password" "dex_client" {
  for_each = toset(["argocd", "grafana", "oauth2-proxy", "openbao"])
  length   = 40
  special  = false
}

resource "aws_ssm_parameter" "dex_client_secret" {
  for_each = toset(["argocd", "grafana", "oauth2-proxy", "openbao"])

  name             = "${local.ssm_key_prefix}/dex-${each.key}-client-secret"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.dex_client[each.key].result
  value_wo_version = 1
  lifecycle { prevent_destroy = true }
}

ephemeral "random_password" "argo_workflows_client" {
  length  = 40
  special = false
}

resource "aws_ssm_parameter" "argo_workflows_client_secret" {
  name             = "${local.ssm_key_prefix}/dex-argo-workflows-client-secret"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.argo_workflows_client.result
  value_wo_version = 1
  lifecycle { prevent_destroy = true }
}

ephemeral "random_password" "oauth2_proxy_cookie" {
  length  = 32
  special = false
}
resource "aws_ssm_parameter" "oauth2_proxy_cookie_secret" {
  name             = "${local.ssm_key_prefix}/oauth2-proxy-cookie-secret"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.oauth2_proxy_cookie.result
  value_wo_version = 1
  lifecycle { prevent_destroy = true }
}

ephemeral "random_password" "seaweedfs_secret_key" {
  for_each = toset(["admin", "observability"])
  length   = 40
  special  = false
}

resource "aws_ssm_parameter" "seaweedfs_access_key" {
  for_each = toset(["admin", "observability"])
  name     = "${local.ssm_key_prefix}/seaweedfs-s3-${each.key}-access-key"
  type     = "SecureString"
  value    = "seaweedfs-${each.key}"
}

resource "aws_ssm_parameter" "seaweedfs_secret_key" {
  for_each         = toset(["admin", "observability"])
  name             = "${local.ssm_key_prefix}/seaweedfs-s3-${each.key}-secret-key"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.seaweedfs_secret_key[each.key].result
  value_wo_version = 1
  lifecycle { prevent_destroy = true }
}
