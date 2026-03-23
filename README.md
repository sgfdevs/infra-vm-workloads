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
- `src/tf/workload_vms.tf` provisions two workload VMs pinned one-per-node by default.
- `src/tf/ssh_key_inventory.tf` generates an SSH key, stores its private key in SSM, and publishes hosts via the Terraform Ansible provider.
- `src/ansible/inventory.yml` uses the Terraform inventory plugin (`cloud.terraform.terraform_provider`).
- `src/ansible/group_vars/all.yml` resolves `ssm_private_key_path` from AWS SSM at runtime.
- VM provisioning uses a repository-defined Debian 13 cloud image ID in `src/tf/workload_vms.tf`.

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
