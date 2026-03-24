# infra-vm-workloads

OpenTofu + Ansible automation for sgfdevs workload VMs on Proxmox.

## Layout

```text
.
├── .github/workflows/
├── src/tf/
├── src/ansible/
├── Makefile
└── .envrc.example
```

## Quickstart

```bash
cp .envrc.example .envrc
make tf-init
make tf-plan
```

## Notes

- `src/tf/connectivity.tf` includes a provider connectivity check that reads Proxmox node inventory.
- `src/tf/k3s.tf` contains all Terraform resources for the workload K3s cluster, including VM definitions, SSH key material, and Terraform Ansible inventory resources.
- `src/ansible/inventory.yml` uses the Terraform inventory plugin (`cloud.terraform.terraform_provider`).
- `src/ansible/group_vars/all.yml` resolves `ssm_private_key_path` from AWS SSM at runtime.
- `src/ansible/playbooks/apply.yml` bootstraps Flux and GitHub notifications for `sgfdevs/infra-k8s-apps`.
- VM provisioning uses the shared `infra-shared` `proxmox-vm` module with `os_id = "debian13"` in `src/tf/k3s.tf`.

## Required Terraform Variables

- `TF_VAR_proxmox_endpoint`
- `TF_VAR_proxmox_api_token`

## GitHub Workflows

- `tf-plan.yml`: PR validation for Terraform.
- `tf-plan-apply.yml`: apply on `main` and optional manual plan-only runs.
- `ansible-lint.yml`: lint `src/ansible`.
- `ansible-manual.yml`: manual playbook execution.

## Required GitHub Secrets

- `AWS_ROLE_ARN`
- `OUTPUT_ENCRYPTION_KEY`
- `TF_VAR_proxmox_endpoint`
- `TF_VAR_proxmox_api_token`

## Flux Bootstrap Notes

- Run `bootstrap.yml` first to install K3s, then run `apply.yml` to bootstrap Flux.
- After Terraform apply, add `flux_git_public_key` output to `sgfdevs/infra-k8s-apps` as a read-only deploy key.
- Update SSM parameter at `flux_github_status_token_ssm_path` with a valid GitHub token so Flux notifications can post status updates.
