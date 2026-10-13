"""Role-local Secret validation and in-memory rendering. Never performs I/O."""
import base64
import binascii
import json


def bootstrap_secret_missing_keys(raw, required_keys):
    try:
        secret = json.loads(raw)
        data = secret.get("data") or {}
        if not isinstance(data, dict):
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        raise ValueError("Secret response could not be validated") from None
    missing = []
    for key in required_keys:
        value = data.get(key)
        try:
            complete = isinstance(value, str) and bool(base64.b64decode(value, validate=True))
        except (ValueError, binascii.Error):
            complete = False
        if not complete:
            missing.append(key)
    return sorted(missing)


def bootstrap_secret_manifest(seed, values):
    if set(values) != set(seed["parameters"]) or any(
            not isinstance(value, str) or not value for value in values.values()):
        raise ValueError("Parameter value is missing or empty")
    metadata = {"namespace": seed["namespace"], "name": seed["name"]}
    if seed.get("labels"):
        metadata["labels"] = seed["labels"]
    return {"apiVersion": "v1", "kind": "Secret", "metadata": metadata, "type": "Opaque",
            "data": {key: base64.b64encode(value.encode()).decode() for key, value in values.items()}}


def bootstrap_aws_credentials_patch(raw, desired):
    try:
        secret = json.loads(raw)
        metadata = secret["metadata"]
        if (metadata["namespace"] != "kube-system"
                or metadata["name"] != "bootstrap-aws-credentials"
                or not metadata["uid"] or not metadata["resourceVersion"]
                or set(desired["data"]) != {"access-key-id", "secret-access-key"}):
            raise ValueError()
        current = secret.get("data") or {}
        if not isinstance(current, dict):
            raise ValueError()
        if all(current.get(key) == value for key, value in desired["data"].items()):
            return {}
        # UID rejects a deleted/recreated target; resourceVersion rejects concurrent edits.
        return {"metadata": {key: metadata[key] for key in ("uid", "resourceVersion")},
                "data": desired["data"]}
    except (ValueError, TypeError, KeyError, AttributeError):
        raise ValueError("AWS credential Secret response could not be reconciled") from None


class FilterModule:
    def filters(self):
        return {"bootstrap_secret_missing_keys": bootstrap_secret_missing_keys,
                "bootstrap_secret_manifest": bootstrap_secret_manifest,
                "bootstrap_aws_credentials_patch": bootstrap_aws_credentials_patch}
