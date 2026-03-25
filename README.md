# infra-vm-workloads

Provisions SGF Devs workload VMs on Proxmox and bootstraps the k3s cluster and Flux baseline used to deploy Kubernetes manifests.

## Scope
- Owns: OpenTofu resources for workload VMs, SSH/Flux key material, and SSM parameters used by cluster automation.
- Owns: Ansible bootstrap and apply flow for k3s installation and Flux baseline manifests.

## Structure
- `src/tf/`: Provisions Proxmox VMs and emits Terraform-backed Ansible inventory data.
- `src/ansible/`: Installs k3s (`bootstrap.yml`) and applies Flux/bootstrap manifests (`apply.yml`).
- `.github/workflows/`: Terraform plan/apply and Ansible lint/manual execution workflows.

## Run
```bash
make help
make tf-init
make tf-plan
make tf-apply
make ansible-install
make ansible PLAYBOOK=bootstrap.yml
make ansible PLAYBOOK=apply.yml
```

## Operational order
- Apply Terraform first to create VMs and write required SSM parameter paths.
- Run `bootstrap.yml` before `apply.yml` so k3s is present before Flux/bootstrap manifests are applied.
- Add `flux_git_public_key` output as a read-only deploy key in [`sgfdevs/infra-k8s-apps`](https://github.com/sgfdevs/infra-k8s-apps).
- Update the SSM parameter at `flux_github_status_token_ssm_path` with a valid GitHub token for Flux notification status updates.

## Operating constraints
- This repo mixes infrastructure provisioning and cluster bootstrap; run Terraform and Ansible steps intentionally and in order.
