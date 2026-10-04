# Argo CD bootstrap

## Credentials and prerequisites

Run GitHub workflow bootstrap from main with `initialize-terraform=true`. The pinned reusable workflow configures short-lived AWS credentials only on that path; the caller rejects other bootstrap inputs rather than pretending the role is available. Other playbooks retain their existing input behavior. Repository changes do not deploy IAM or Kubernetes configuration.

AWS-core permissions must be deployed separately. The LZ workflow role reads only the two LZ Headscale parameters beyond its existing workload prefix. SGF assumes `arn:aws:iam::<LZ_ACCOUNT_ID>:role/SGFDevsBootstrapTailnetParameterReader` only for an absent SGF tailnet Secret, using the independently fetched `ssm_lz_aws_account_id_path` account ID and a controller-side 900-second session. The runtime `SGFDevsTailnetParameterReader` cluster-OIDC trust is unchanged. No permanent credentials are stored. Source IAM permissions are main-only. Core inputs `TF_VAR_sgfdevs_aws_account_id` in LZ and `TF_VAR_lz_aws_account_id` in SGF must be operator-verified, not guessed. Headscale source declares default SecureString encryption; no extra CMK policy is needed from that source contract. No live encryption check has been performed.

Do not use controller verbosity 4 or higher or ANSIBLE_DEBUG. The existing amazon.aws lookup can print returned values at verbosity 4 outside task no_log. The role rejects those settings and remote module-file retention before lookups. Every sensitive seed task disables logs and diff. Seed operations enable Ansible pipelining so stdin manifests are not persisted inside remote module argument files. Do not override pipelining for these tasks. No secret manifest is written to disk or passed as an argument.

Working Headscale, reusable keys, storage, networking, DNS, AWS permissions, tunnel tokens and certificate issuance remain prerequisites. Presence of a Secret does not prove the credential is valid.

## Missing-only seeds

All ingress seeds are Opaque Secrets in kube-system. The exact namespace/name/key/path map is in `defaults/main.yml` under `bootstrap_argocd_ingress_seeds`. Each lookup reads one parameter with explicit us-east-2 and decryption. SGF seeds both cloudflared-sgfdevs-token/token and cloudflared-opensgf-token/token, traefik-tailnet-auth/authkey and crowdsec-bouncer-key/BOUNCER_KEY_traefik. Both connector tokens are mandatory because both containers share Traefik readiness. Only tailnet auth comes from LZ.

A complete existing Secret causes no SSM lookup, AssumeRole, annotation, ownership change, value comparison or write for that seed. Nonempty decoded required data keys are sufficient; extra keys and existing ownership remain untouched. A partial, empty or malformed existing Secret fails without repair. Deliberately repair it before rerunning. Failures report only the namespace/name and missing key names or a safe failure category.

Only an absent Secret is fetched and created through kubectl stdin. An AlreadyExists race rereads and accepts a complete winner without updating it. Other read, SSM, decryption or create failures stop. Transient values, command results and temporary credentials are cleared in an always block, including failure paths; facts are not cached.

SeaweedFS uses the same helper for seaweedfs/seaweedfs-s3-admin with access_key and secret_key, seaweedfs/seaweedfs-s3-observability with the same key names, and observability/seaweedfs-s3-observability with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. Source parameters remain the existing admin/observability paths. Labels and original templates are preserved; eager prepare-time retrieval and repeated apply are removed.

The Git deploy Secret is still an Ansible-managed access resource. Its lookup and cross-account identifier lookups are separate from missing-only ESO seeds.

## Ordering and GitOps takeover

Prepare namespaces and aws-runtime, then install the mirrored native admission policy and binding before operators create annotated ServiceAccounts. Admission does not retroactively mutate old ServiceAccounts. An existing malformed templated annotation requires deliberate repair, not a bootstrap rotation policy. GitOps keeps the same admission resource owner and identity. Mirrors and seed maps are checked against the companion GitOps contract.

Seeds precede operator and platform reconciliation. Final platform waits proceed through foundation, issuer and AWS configuration, followed by explicit Ready conditions for each store and ExternalSecret before enabling apps. The issuer Application uses one bounded public PostSync check. Ansible waits on that input-bound hook rather than making a second public probe.

When the issuer annotation opts in, both gates require Synced, Healthy, no pending operation and operationState.phase Succeeded. The operation's syncResult.resources must include group batch, kind Job, namespace k8s-oidc, the exact oidc-public-readiness-<issuer-input-fingerprint> name, hookType PostSync and hookPhase Succeeded. Hook resource status is ignored because Argo leaves it empty for hooks. A newer repository Git SHA with unchanged inputs can pass using the prior matching hook. Changed inputs and successful selective syncs without the expected hook cannot pass. Use a full issuer sync after a selective operation; admin selective-sync abilities remain unchanged.

The companion Kubernetes scripts/issuer-fingerprint.py hashes the issuer Application and all issuer source/config/checker/Job inputs. Only generated fingerprint fields and the generated hook name are excluded. Its --update command writes the Application, ordinary Deployment metadata and Job name bindings; CI recomputes them. The ordinary-resource stamp makes changed hook inputs OutOfSync. The exact algorithm and maintenance rules are in the Kubernetes docs/bootstrap-migration.md.

The hook uses public resolvers, normal TLS, exact discovery and JWKS URLs, no redirects, no service-account token, no credentials or RBAC, twelve attempts with eight-second requests and a 300-second Job deadline. It logs categories rather than bodies.

Old platform main lacks the hook and retains the old AWS-before-issuer cycle. An already healthy old cluster remains compatible through an annotation-free wait path and explicit ESO conditions. This path does not establish public readiness or cold bootstrap. Empty-cluster bootstrap requires the staged GitOps split published on main; this VM PR alone cannot fix the old desired graph.

Seeds have no controller ownerReference, Argo tracking or last-applied annotation. Pinned ESO v2.11.0 uses Owner to adopt and update a pre-existing Secret without a conflicting controller owner, and rejects conflicting ownership. Owner rebuilds Secret data, so ESO may remove extra keys after takeover. Ansible does not overwrite a present Secret; ESO remains authoritative after reconciliation. Never change Owner to Merge to hide this distinction.

The source contracts are [ESO ownership](https://github.com/external-secrets/external-secrets/blob/v2.11.0/pkg/controllers/externalsecret/externalsecret_controller.go), [Owner data replacement](https://github.com/external-secrets/external-secrets/blob/v2.11.0/pkg/controllers/externalsecret/externalsecret_controller_template.go), and [the AWS service-account annotation](https://github.com/external-secrets/external-secrets/blob/v2.11.0/providers/v1/aws/auth/auth.go). Source review establishes the expected behavior, not an observed controller adoption.

## Migration checkpoints and recovery

Existing clusters need the companion GitOps three-phase series. First reconcile prune-protected resources under bootstrap-config and the empty bootstrap-aws-config child. Verify every live protection annotation and record resource and target Secret UIDs without reading Secret data. Only then permit transfer of those same protected identities to the new child. Before cleanup, verify unchanged UIDs, actual new Argo tracking, Ready conditions, current issuer hook success and unchanged ingress availability. Finally remove protection from confirmed adopted identities and require both configuration Applications Synced and Healthy. Later phases must not auto-merge.

Stop on any failed checkpoint. Keep protection, repair auth/readiness/tracking, and do not delete/recreate Secrets or ExternalSecrets. Restoring old ownership requires protecting the new owner first, observing that protection, then transferring desired ownership back and confirming UIDs/tracking before removing protection. Detailed identity inventory and recovery procedure live in the Kubernetes repo's `docs/bootstrap-migration.md`.

## Validation limits

`python -m unittest discover -s tests -v` at the repository root exercises actual Lua with synthetic objects and the seed task state machine with Jinja/fake modules. It renders no secret files and sends no AWS or Kubernetes requests. Contract fixtures record the companion GitOps mirror, key map and ESO conditions. These tests do not execute Ansible or prove admission delivery/controller adoption. A later isolated synthetic ESO adoption/conflicting-owner test and genuine empty-cluster bootstrap remain required. No live bootstrap, issuer routing/TLS, credential-validity or UID-preservation claim follows from offline checks.
