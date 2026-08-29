output "workload_vm_ids" {
  value = module.sgfdevs_k3s_cluster.workload_vm_ids
}

output "git_deploy_public_key" {
  value = module.sgfdevs_k3s_cluster.git_deploy_public_key
}

output "ssm_paths" {
  value = merge(module.sgfdevs_k3s_cluster.ssm_paths, {
    cloudflare_sgfdevs_tunnel_token = aws_ssm_parameter.cloudflare_sgfdevs_tunnel_token.name
    cloudflare_opensgf_tunnel_token = aws_ssm_parameter.cloudflare_opensgf_tunnel_token.name
  })
}

output "cloudflare_tunnel_targets" {
  description = "DNS targets for public hostnames routed through the workload cluster tunnels"
  value = {
    sgfdevs = "${cloudflare_zero_trust_tunnel_cloudflared.sgfdevs_k3s.id}.cfargotunnel.com"
    opensgf = "${cloudflare_zero_trust_tunnel_cloudflared.opensgf_k3s.id}.cfargotunnel.com"
  }
}
