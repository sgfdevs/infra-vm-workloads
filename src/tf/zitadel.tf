locals {
  zitadel_ssm_prefix = "/vm-workloads/sgfdevs/infra-vm-workloads/zitadel"
}

ephemeral "random_password" "zitadel_initial_admin_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*+-=?@^_"
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
}

resource "aws_ssm_parameter" "zitadel_initial_admin_password" {
  name             = "${local.zitadel_ssm_prefix}/initial-admin-password"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.zitadel_initial_admin_password.result
  value_wo_version = 1
}

ephemeral "random_password" "zitadel_master_key" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "zitadel_master_key" {
  name             = "${local.zitadel_ssm_prefix}/master-key"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.zitadel_master_key.result
  value_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}
