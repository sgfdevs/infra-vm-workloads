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


class FilterModule:
    def filters(self):
        return {"bootstrap_secret_missing_keys": bootstrap_secret_missing_keys,
                "bootstrap_secret_manifest": bootstrap_secret_manifest}
