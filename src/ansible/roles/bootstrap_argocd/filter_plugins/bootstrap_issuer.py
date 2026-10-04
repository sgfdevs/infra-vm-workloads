"""Require the input-bound PostSync Job result, not a repository Git revision."""


def bootstrap_issuer_hook_ready(application, operation_annotation):
    annotations = application.get("metadata", {}).get("annotations", {})
    if annotations.get(operation_annotation) != "true":
        return True
    fingerprint = annotations.get(operation_annotation.rsplit("/", 1)[0] + "/issuer-input-fingerprint")
    status = application.get("status", {})
    operation = status.get("operationState", {})
    if (not isinstance(fingerprint, str) or len(fingerprint) != 40
            or application.get("operation") is not None
            or operation.get("phase") != "Succeeded"
            or status.get("sync", {}).get("status") != "Synced"
            or status.get("health", {}).get("status") != "Healthy"):
        return False
    return any(
        resource.get("group") == "batch"
        and resource.get("kind") == "Job"
        and resource.get("namespace") == "k8s-oidc"
        and resource.get("name") == "oidc-public-readiness-" + fingerprint
        and resource.get("hookType") == "PostSync"
        and resource.get("hookPhase") == "Succeeded"
        for resource in operation.get("syncResult", {}).get("resources", [])
    )


class FilterModule:
    def filters(self):
        return {"bootstrap_issuer_hook_ready": bootstrap_issuer_hook_ready}
