resource "aws_iam_user" "bootstrap_reader" {
  name                 = "sgfdevs-k3s-bootstrap-reader"
  path                 = "/vm-workloads/sgfdevs/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/vm-workloads/sgfdevs/VMWorkloadsParameterReaderBoundary"

  tags = {
    ManagedBy  = "OpenTofu"
    Repository = "sgfdevs/infra-vm-workloads"
  }
}

resource "aws_iam_user_policy" "bootstrap_reader" {
  name = "ReadBootstrapIngressParameters"
  user = aws_iam_user.bootstrap_reader.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "ssm:GetParameter"
      Resource = [
        "arn:aws:ssm:us-east-2:${data.aws_caller_identity.current.account_id}:parameter/vm-workloads/sgfdevs/infra-vm-workloads/cloudflare-sgfdevs-tunnel-token",
        "arn:aws:ssm:us-east-2:${data.aws_caller_identity.current.account_id}:parameter/vm-workloads/sgfdevs/infra-vm-workloads/cloudflare-opensgf-tunnel-token",
        "arn:aws:ssm:us-east-2:${data.aws_caller_identity.current.account_id}:parameter/vm-workloads/sgfdevs/infra-vm-workloads/crowdsec-traefik-bouncer-key",
      ]
    }]
  })
}

resource "aws_iam_access_key" "bootstrap_reader" {
  user = aws_iam_user.bootstrap_reader.name
}

resource "aws_ssm_parameter" "bootstrap_aws_credentials" {
  name = "/vm-workloads/sgfdevs/infra-vm-workloads/bootstrap-aws/credentials"
  type = "SecureString"
  # Publish both fields together so readers cannot mix access-key generations.
  value = jsonencode({
    access-key-id     = aws_iam_access_key.bootstrap_reader.id
    secret-access-key = aws_iam_access_key.bootstrap_reader.secret
  })
}
