# infra-vm-workloads

Provisions SGF Devs workload VMs on Proxmox and bootstraps the k3s cluster and Argo CD baseline used to deploy Kubernetes manifests.

## Scope
- Owns: OpenTofu resources for three workload VMs, persistent data disks, SSH/Git deploy keys, the backup bucket, and SSM parameters used by cluster automation.
- Owns: Ansible node/storage preparation, k3s installation, and Argo CD bootstrap.
- Does not own: public edge connectivity or Proxmox metrics configuration.

## Structure
- `src/tf/`: Provisions Proxmox VMs and emits Terraform-backed Ansible inventory data.
- `src/ansible/`: Rebuilds the cluster (`cluster-bootstrap.yml`) and supports rerunning Argo CD bootstrap (`argocd-bootstrap.yml`).
- `.github/workflows/`: Terraform plan/apply and Ansible lint/manual execution workflows.

## Run
```bash
make help
make tf-init
make tf-plan
make tf-apply
make ansible-install
make ansible PLAYBOOK=cluster-bootstrap.yml
make ansible PLAYBOOK=argocd-bootstrap.yml
```

## Operational order
- Apply Terraform first to create the VMs, 300 GB data disks, backup resources, and SSM parameters.
- Export the Dex GitHub OAuth App client ID before running OpenTofu: `export TF_VAR_dex_github_oauth_client_id=<github-oauth-app-client-id>`. OpenTofu writes it to `/vm-workloads/sgfdevs/infra-vm-workloads/dex-github-oauth-client-id` as a String parameter.
- Add the `git_deploy_public_key` output as a read-only deploy key in [`sgfdevs/infra-k8s-apps`](https://github.com/sgfdevs/infra-k8s-apps).
- After the first apply, manually replace the write-only `CHANGEME` value in `/vm-workloads/sgfdevs/infra-vm-workloads/dex-github-oauth-client-secret` with the Dex GitHub OAuth App client secret. Do not increment `value_wo_version` unless intentionally replacing the manual value.
- Replace `CHANGEME` in `/vm-workloads/sgfdevs/infra-vm-workloads/{argocd,grafana}-github-oauth-client-secret` only if those integrations are enabled with separate GitHub OAuth Apps.
- Replace `CHANGEME` in `/vm-workloads/sgfdevs/infra-vm-workloads/backups/{b2-account-id,b2-account-key}` with credentials scoped only to `sgfdevs-vm-workloads-backups`.
- Create the External Secrets IAM credentials at `/homelab/sgfdevs-vms/eso-ssm-access-key-id` and `/homelab/sgfdevs-vms/eso-ssm-secret-access-key`, scoped to the SGF SSM hierarchy.
- Run `cluster-bootstrap.yml` for a complete rebuild, or `argocd-bootstrap.yml` to reconcile only Argo CD bootstrap resources.

## Operating constraints
- This repo mixes infrastructure provisioning and cluster bootstrap; run Terraform and Ansible steps intentionally and in order.
- Generated OpenBao, Dex client, OAuth2 Proxy cookie, SeaweedFS, and backup secrets use `prevent_destroy`. A full destroy is intentionally blocked until an operator explicitly removes those lifecycle guards after preserving or accepting loss of the values.
- Public ingress and edge routing must be established externally after the cluster is available.
