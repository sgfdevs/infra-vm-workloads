output "workload_vm_ids" { value = { for name, vm in module.k3s_vm : name => vm.vm_id } }
output "git_deploy_public_key" { value = module.git_deploy_key.public_key }
output "ssm_paths" {
  value = {
    ssh_private_key                = module.ssh_key.ssm_path
    git_deploy_private_key         = module.git_deploy_key.ssm_path
    git_deploy_public_key          = module.git_deploy_key.ssm_public_key_path
    openbao_unseal_key             = aws_ssm_parameter.openbao_unseal_key.name
    dex_github_oauth_client_secret = aws_ssm_parameter.dex_github_oauth_client_secret.name
    dex_client_secret_parameters   = { for name, parameter in aws_ssm_parameter.dex_client_secret : name => parameter.name }
    argo_workflows_client_secret   = aws_ssm_parameter.argo_workflows_client_secret.name
    oauth2_proxy_cookie_secret     = aws_ssm_parameter.oauth2_proxy_cookie_secret.name
  }
}
