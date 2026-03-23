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

## Required Terraform Variables

- `TF_VAR_proxmox_endpoint`
- `TF_VAR_proxmox_api_token`
- `TF_VAR_vm_template_file_id`
- `TF_VAR_vm_user_ssh_public_key`

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
- `TF_VAR_vm_template_file_id`
- `TF_VAR_vm_user_ssh_public_key`
- `ANSIBLE_SSH_KEY`
