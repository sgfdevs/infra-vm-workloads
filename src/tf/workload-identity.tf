data "aws_caller_identity" "current" {}

locals {
  sgfdevs_k3s_oidc_issuer           = "k8s-oidc.sgf.dev"
  sgfdevs_k3s_external_secrets_role = "sgfdevs-k3s-external-secrets"
  sgfdevs_k3s_openbao_role          = "sgfdevs-k3s-openbao"

  sgfdevs_k3s_oidc_provider_arn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.sgfdevs_k3s_oidc_issuer}"
  sgfdevs_k3s_workload_boundary_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/sgfdevs-k3s/SGFDevsK3sKubernetesWorkloadBoundary"
  external_secrets_ssm_parameter_arn   = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/vm-workloads/sgfdevs/infra-vm-workloads/*"
  external_secrets_subject             = "system:serviceaccount:external-secrets:external-secrets"
  openbao_subject                      = "system:serviceaccount:openbao:openbao"
  openbao_unseal_key_ssm_parameter_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/vm-workloads/sgfdevs/infra-vm-workloads/openbao-unseal-key"
}

resource "aws_iam_role" "external_secrets" {
  name                 = local.sgfdevs_k3s_external_secrets_role
  path                 = "/sgfdevs-k3s/"
  permissions_boundary = local.sgfdevs_k3s_workload_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.sgfdevs_k3s_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.sgfdevs_k3s_oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.sgfdevs_k3s_oidc_issuer}:sub" = local.external_secrets_subject
          }
        }
      }
    ]
  })

  tags = {
    KubernetesNamespace      = "external-secrets"
    KubernetesServiceAccount = "external-secrets"
    ManagedBy                = "OpenTofu"
    Repository               = "sgfdevs/infra-vm-workloads"
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "ReadVMWorkloadParameters"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = local.external_secrets_ssm_parameter_arn
      },
    ]
  })
}

resource "aws_iam_role" "openbao" {
  name                 = local.sgfdevs_k3s_openbao_role
  path                 = "/sgfdevs-k3s/"
  permissions_boundary = local.sgfdevs_k3s_workload_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.sgfdevs_k3s_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.sgfdevs_k3s_oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.sgfdevs_k3s_oidc_issuer}:sub" = local.openbao_subject
          }
        }
      }
    ]
  })

  tags = {
    KubernetesNamespace      = "openbao"
    KubernetesServiceAccount = "openbao"
    ManagedBy                = "OpenTofu"
    Repository               = "sgfdevs/infra-vm-workloads"
  }
}

resource "aws_iam_role_policy" "openbao" {
  name = "ReadVMWorkloadParameters"
  role = aws_iam_role.openbao.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = local.openbao_unseal_key_ssm_parameter_arn
      },
    ]
  })
}
