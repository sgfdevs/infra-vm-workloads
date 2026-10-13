# Argo CD bootstrap

## Credentials and prerequisites

Run `cluster-bootstrap.yml`, `argocd-bootstrap.yml` or the seed-only `bootstrap-aws-credentials.yml` through the GitHub manual workflow from main with `initialize-terraform=true`. The pinned reusable workflow configures short-lived AWS credentials only on that path; the caller rejects other bootstrap inputs rather than pretending the role is available. Other playbooks retain their existing input behavior. Repository changes do not deploy IAM or Kubernetes configuration.

Apply the companion AWS-core change separately. It creates sgfdevs-k3s-bootstrap-reader with only ssm:GetParameter on the exact sgfdevs Cloudflare connector and Traefik bouncer paths. The operator provisions its IAM access key outside Terraform and stores the pair as SecureString parameters at /vm-workloads/sgfdevs/infra-vm-workloads/bootstrap-aws/access-key-id and /vm-workloads/sgfdevs/infra-vm-workloads/bootstrap-aws/secret-access-key. Keep key material out of state, Git, outputs and logs. The workflow's existing workload-prefix permissions retrieve this pair. No bootstrap STS session, cross-account role, Headscale access or new account-ID input is required. Runtime roles and OIDC trust remain unchanged.

Do not use controller verbosity 4 or higher or ANSIBLE_DEBUG. The existing amazon.aws lookup can print returned values at verbosity 4 outside task no_log. The role rejects those settings and remote module-file retention before lookups. Every sensitive seed task disables logs and diff. Seed operations enable Ansible pipelining so stdin manifests are not persisted inside remote module argument files. Do not override pipelining for these tasks. No secret manifest is written to disk or passed as an argument.

AWS credential validity, connector tokens, storage, networking, public DNS and certificate issuance remain prerequisites. Headscale keys are reconciled later through JWT-authenticated stores. Tailnet and LZ private DNS gateway readiness must not block public issuer bootstrap. Presence of a Secret does not prove the credential is valid.

## Missing-only seeds

Ansible seeds only kube-system/bootstrap-aws-credentials for ingress bootstrap, with access-key-id and secret-access-key. The exact mapping is in defaults/main.yml under bootstrap_argocd_aws_credential_seeds. Each lookup reads one parameter in us-east-2 with explicit decryption. Ansible no longer fetches or seeds Cloudflare application tokens, bouncer keys, tailnet keys or DNS gateway keys.

The namespace-local kube-system/bootstrap-aws-ssm SecretStore uses these two keys through auth.secretRef with ParameterStore in us-east-2. It stays static after bootstrap. Never put the credential pair through ESO or the normal SSM cache. All other stores remain JWT authenticated. The early ingress Application owns only this store and the Cloudflare and bouncer ExternalSecrets.

Its readable application parameters are /vm-workloads/sgfdevs/infra-vm-workloads/cloudflare-sgfdevs-tunnel-token, /vm-workloads/sgfdevs/infra-vm-workloads/cloudflare-opensgf-tunnel-token and /vm-workloads/sgfdevs/infra-vm-workloads/crowdsec-traefik-bouncer-key. Keep existing ExternalSecret names, data keys and target Secret identities. Both Cloudflare connectors must report Ready before foundation. This is an ESO condition gate, not whole-pod readiness.

A complete existing Secret causes no SSM lookup, annotation, ownership change, value comparison or write for that seed. Nonempty decoded required data keys are sufficient; extra keys and existing ownership remain untouched. A partial, empty or malformed existing Secret fails without repair. Deliberately repair it before rerunning. Failures report only the namespace/name and missing key names or a safe failure category.

Only an absent Secret is fetched and created through kubectl stdin. An AlreadyExists race rereads and accepts a complete winner without updating it. Other read, SSM, decryption or create failures stop. Transient values and command results are cleared in an always block, including failure paths; facts are not cached.

SeaweedFS retains three separate missing-only seeds through the same helper. They are seaweedfs/seaweedfs-s3-admin and seaweedfs/seaweedfs-s3-observability with access_key and secret_key, plus observability/seaweedfs-s3-observability with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. Existing admin/observability parameters, labels and templates are unchanged. Storage seeds do not use the bootstrap ingress SecretStore.

The Git deploy Secret remains an Ansible-managed access resource. Existing cross-account identifier lookups still populate aws-runtime for JWT stores and admission. They do not authorize bootstrap credential retrieval.

## Ordering and GitOps takeover

Prepare namespaces and aws-runtime, then install the mirrored native admission policy and binding before operators create annotated ServiceAccounts. Admission does not retroactively mutate old ServiceAccounts. An existing malformed templated annotation requires deliberate repair, not a bootstrap rotation policy. GitOps keeps the same admission resource owner and identity. Mirrors and seed maps are checked against the companion GitOps contract.

Prepare namespaces, aws-runtime and admission, seed the static credential Secret, install Argo CD and operators, then apply platform. Wait first for bootstrap-ingress-config at wave -4, including actual Ready conditions for bootstrap-aws-ssm and every early Cloudflare and bouncer ExternalSecret. Only then wait for foundation bootstrap-config at -3 and its CA/certificate prerequisites, the matching public issuer hook at -2, and bootstrap-aws-config at -1 with actual JWT store and ExternalSecret conditions. Enable apps last.

Foundation owns HelmChartConfig, not the Traefik Deployment. Neither Ansible nor foundation health may wait for the whole Traefik pod, Tailscale connectivity or the LZ DNS gateway StatefulSet before the issuer. Tailscale probes remain intact and may leave the pod NotReady while Traefik and Cloudflared serve the public issuer through localhost. Do not report tailnet healthy. Cert-manager's public HTTP01 self-check must use public resolvers, not LZ private split DNS. Ansible waits on the input-bound public PostSync hook rather than making another public probe.

When the issuer annotation opts in, both gates require Synced, Healthy, no pending operation and operationState.phase Succeeded. The operation's syncResult.resources must include group batch, kind Job, namespace k8s-oidc, the exact oidc-public-readiness-<issuer-input-fingerprint> name, hookType PostSync and hookPhase Succeeded. Hook resource status is ignored because Argo leaves it empty for hooks. A newer repository Git SHA with unchanged inputs can pass using the prior matching hook. Changed inputs and successful selective syncs without the expected hook cannot pass. Use a full issuer sync after a selective operation; admin selective-sync abilities remain unchanged.

The companion Kubernetes scripts/issuer-fingerprint.py hashes the issuer Application and all issuer source/config/checker/Job inputs. Only generated fingerprint fields and the generated hook name are excluded. Its --update command writes the Application, ordinary Deployment metadata and Job name bindings; CI recomputes them. The ordinary-resource stamp makes changed hook inputs OutOfSync. The exact algorithm and maintenance rules are in the Kubernetes docs/bootstrap-migration.md.

The hook uses public resolvers, normal TLS, exact discovery and JWKS URLs, no redirects, no service-account token, no credentials or RBAC, twelve attempts with eight-second requests and a 300-second Job deadline. It logs categories rather than bodies.

The role selects the static ingress contract only when bootstrap-ingress-config exists and its spec.syncPolicy.automated.allowEmpty is not true. Transfer populates this child; prepare has an empty allowEmpty:true placeholder and no static SecretStore. Static detection does not require k8s-oidc to exist, since the wave -4 gate can prevent Argo from creating that later child on a cold cluster.

Old main and prepare retain the AWS-before-issuer cycle. The role permits their rerun path only when it observes an already Synced and Healthy issuer without the public-hook opt-in. It skips the nonexistent static SecretStore and still checks foundation and all legacy ESO resources before apps. This does not establish public readiness or cold recovery. Prepare is migration-only. Empty-cluster bootstrap requires the populated TRANSFER graph or its cleanup successor published on main, not prepare; this VM change alone cannot fix old desired state.

The static credential Secret has no controller ownerReference, Argo tracking or last-applied annotation and is never adopted by ESO. Ansible remains create-only. Application target Secrets retain creationPolicy Owner. Pinned ESO v2.11.0 uses Owner to adopt and update a pre-existing Secret without a conflicting controller owner, and rejects conflicting ownership. Owner rebuilds Secret data, so ESO may remove extra keys after takeover. ESO remains authoritative for application target Secrets after reconciliation, not for bootstrap-aws-credentials. Never change Owner to Merge to hide this distinction.

The source contracts are [ESO ownership](https://github.com/external-secrets/external-secrets/blob/v2.11.0/pkg/controllers/externalsecret/externalsecret_controller.go), [Owner data replacement](https://github.com/external-secrets/external-secrets/blob/v2.11.0/pkg/controllers/externalsecret/externalsecret_controller_template.go), and [the AWS service-account annotation](https://github.com/external-secrets/external-secrets/blob/v2.11.0/providers/v1/aws/auth/auth.go). Source review establishes the expected behavior, not an observed controller adoption.

## Migration checkpoints and recovery

Publish and apply in these steps. Do not start an empty-cluster run until the transfer graph is on main.

1. Merge and apply AWS-core to create sgfdevs-k3s-bootstrap-reader and its exact-path policy. Provision the key pair outside Terraform, then securely populate the two SecureString parameters. Never print values or use secret-value command arguments.
2. Merge the VM change. Before Kubernetes transfer, run `make ansible PLAYBOOK=bootstrap-aws-credentials.yml` on the existing cluster, or select that playbook in the manual workflow with main and `initialize-terraform=true`. It imports only the create-only static credential seed tasks on k3s_servers. It rejects unsafe debug/verbosity and retained module files before credential lookups, and does not run Argo, platform, admission or legacy readiness waits. Verify only Secret identity and required-key completeness, never values. This does not make old main cold-recoverable.
3. Merge and reconcile GitOps prepare. Observe prune protection on every moving identity, including LZ DNS gateway resources moving after the issuer. Record resource and target Secret UIDs without reading Secret data. Confirm admission and both empty children with allowEmpty:true. Prepare does not create the static ingress SecretStore and is not a cold-bootstrap graph.
4. Merge and reconcile transfer only after prepare checkpoints pass and the seed-only playbook has succeeded. Keep ExternalSecret identities, targets and creationPolicy Owner unchanged. Verify early static store and ExternalSecrets Ready, unchanged target Secret UIDs, actual new Argo tracking, matching issuer hook success, JWT store readiness and unchanged public ingress availability.
5. Merge and reconcile cleanup only after adoption succeeds. Restore pruning for confirmed adopted identities and require bootstrap-ingress-config, bootstrap-config and bootstrap-aws-config Synced and Healthy. Later phases must not auto-merge. Cold-bootstrap validation follows the completed graph.

Stop on any failed checkpoint. Keep protection, repair auth/readiness/tracking, and do not delete/recreate Secrets or ExternalSecrets. Restoring old ownership requires protecting the new owner first, observing that protection, then transferring desired ownership back and confirming UIDs/tracking before removing protection. Detailed identity inventory and recovery procedure live in the Kubernetes repo's `docs/bootstrap-migration.md`.

## Rotation and partial failures

Ansible does not rotate or repair the static credential Secret. To rotate, provision a replacement key outside Terraform, update the two SecureString parameters through an approved secret-safe channel, then replace both keys in the existing Kubernetes Secret in place through a protected transport. Preserve its UID. Confirm bootstrap-aws-ssm and all early ExternalSecrets Ready before revoking the old key. Do not copy this pair into ESO or cache parameters.

If only one parameter or Secret key updates, stop. Restore a complete known-valid pair securely and rerun readiness checks before revocation. Incomplete existing Secrets fail without repair. For an absent Secret, fix IAM, parameter paths or decryption and rerun; a competing complete creator is accepted without a write. Never delete application Secrets to recover bootstrap. Public ingress may keep running with existing tokens during a static-store failure, but readiness still fails.

## Validation limits

`python -m unittest discover -s tests -v` at the repository root exercises actual Lua with synthetic objects and the seed task state machine with Jinja/fake modules. It renders no secret files and sends no AWS or Kubernetes requests. Contract fixtures record the companion GitOps mirror, static credential map and split early/JWT ESO conditions. Existing assertions use the single static credential seed and its current transient cleanup state; no test cases were added. These tests do not execute Ansible or prove admission delivery/controller adoption. A later isolated synthetic ESO adoption/conflicting-owner test and genuine empty-cluster bootstrap remain required. No live bootstrap, issuer routing/TLS, credential-validity or UID-preservation claim follows from offline checks.
