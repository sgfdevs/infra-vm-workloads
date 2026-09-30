ephemeral "random_password" "crowdsec_traefik_bouncer_key" {
  length  = 40
  special = false
}

resource "aws_ssm_parameter" "crowdsec_traefik_bouncer_key" {
  name             = "/vm-workloads/sgfdevs/infra-vm-workloads/crowdsec-traefik-bouncer-key"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.crowdsec_traefik_bouncer_key.result
  value_wo_version = 1

  lifecycle {
    prevent_destroy = true
  }
}
