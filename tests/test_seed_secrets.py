"""Execute the seed task state machine with Jinja and fake modules.

This is not an Ansible integration test. No Ansible, kubectl, AWS or network
operation is executed. It exercises the repository task definitions, not a
second implementation of the missing-only algorithm.
"""
import base64
import importlib.util
import json
from pathlib import Path
import re
import unittest

from jinja2 import Environment, StrictUndefined
import yaml

ROOT = Path(__file__).resolve().parents[1]
ROLE = ROOT / "src/ansible/roles/bootstrap_argocd"
spec = importlib.util.spec_from_file_location("bootstrap_secrets", ROLE / "filter_plugins/bootstrap_secrets.py")
filters = importlib.util.module_from_spec(spec)
spec.loader.exec_module(filters)
SENSITIVE = "synthetic-secret-never-log"
TEMP = {"access_key": "temporary-access", "secret_key": "temporary-secret", "session_token": "temporary-token"}


class SafeFailure(Exception):
    pass


class SeedRunner:
    def __init__(self, seed, responses, lookup_error=None, values=None):
        self.context = {"bootstrap_argocd_seed": seed, "bootstrap_argocd_lz_aws_account_id": "111122223333"}
        self.responses = list(responses)
        self.lookup_error = lookup_error
        self.values = values or {}
        self.lookups, self.writes, self.assumptions = [], [], []
        self.env = Environment(undefined=StrictUndefined)
        self.env.filters.update(filters.FilterModule().filters())
        self.env.filters.update(combine=lambda a, b: a | b,
                                dict2items=lambda d: [{"key": k, "value": v} for k, v in d.items()],
                                to_json=json.dumps)
        self.env.globals["lookup"] = self.lookup

    def lookup(self, name, path, **kwargs):
        self.lookups.append((name, path, kwargs))
        if self.lookup_error:
            raise RuntimeError(self.lookup_error)
        return self.values.get(path, SENSITIVE)

    def expression(self, expr):
        return self.env.compile_expression(expr)(**self.context)

    def render(self, value):
        if isinstance(value, str):
            match = re.fullmatch(r"\s*{{\s*([\s\S]*?)\s*}}\s*", value)
            return self.expression(match[1]) if match else self.env.from_string(value).render(**self.context)
        if isinstance(value, dict):
            return {k: self.render(v) for k, v in value.items()}
        if isinstance(value, list):
            return [self.render(v) for v in value]
        return value

    def file(self, name):
        self.tasks(yaml.safe_load((ROLE / "tasks" / name).read_text()))

    def tasks(self, tasks):
        for task in tasks:
            if "loop" in task:
                loop_var = task.get("loop_control", {}).get("loop_var", "item")
                for item in self.render(task["loop"]):
                    self.context[loop_var] = item
                    self.tasks([{k: v for k, v in task.items() if k != "loop"}])
                self.context.pop(loop_var, None)
                continue
            if "when" in task and not self.expression(task["when"]):
                continue
            if "block" in task:
                try:
                    self.tasks(task["block"])
                except Exception:
                    if "rescue" not in task:
                        raise
                    self.tasks(task["rescue"])
                finally:
                    self.tasks(task.get("always", []))
                continue
            if "ansible.builtin.include_tasks" in task:
                extra = self.render(task.get("vars", {}))
                old = {key: self.context.get(key) for key in extra}
                self.context.update(extra)
                try:
                    include = task["ansible.builtin.include_tasks"]
                    self.file(include["file"] if isinstance(include, dict) else include)
                finally:
                    for key, value in old.items():
                        if value is None:
                            self.context.pop(key, None)
                        else:
                            self.context[key] = value
            elif "ansible.builtin.set_fact" in task:
                self.context.update(self.render(task["ansible.builtin.set_fact"]))
            elif "ansible.builtin.command" in task:
                command = self.render(task["ansible.builtin.command"])
                if "stdin" in command:
                    self.writes.append(json.loads(command["stdin"]))
                result = self.responses.pop(0)
                self.context[task["register"]] = result
                if result["rc"] and task.get("failed_when") is not False:
                    raise RuntimeError("raw-command-error-" + SENSITIVE)
            elif "amazon.aws.sts_assume_role" in task:
                self.assumptions.append(self.render(task["amazon.aws.sts_assume_role"]))
                self.context[task["register"]] = {"sts_creds": TEMP}
            elif "ansible.builtin.assert" in task:
                conditions = task["ansible.builtin.assert"]["that"]
                if isinstance(conditions, str):
                    conditions = [conditions]
                if not all(self.expression(expr) for expr in conditions):
                    raise RuntimeError("assert failed")
            elif "ansible.builtin.fail" in task:
                raise SafeFailure(self.render(task["ansible.builtin.fail"]["msg"]))
            else:
                raise AssertionError("Unmocked task: " + task["name"])

    def run(self):
        self.file("seed-secret.yml")


def result(stdout="", rc=0, stderr=""):
    return {"rc": rc, "stdout": stdout, "stderr": stderr}


def existing(seed, empty=None):
    data = {key: base64.b64encode(SENSITIVE.encode()).decode() for key in seed["parameters"]}
    if empty:
        data[empty] = ""
    return json.dumps({"metadata": {"uid": "winner-uid", "annotations": {"unrelated": "keep"}},
                       "data": data})


class SeedContract(unittest.TestCase):
    def seeds(self):
        return yaml.safe_load((ROLE / "defaults/main.yml").read_text())["bootstrap_argocd_ingress_seeds"]

    def assert_cleared(self, runner):
        for key in ["values", "sts", "read", "create", "winner"]:
            self.assertEqual(runner.context["_bootstrap_argocd_seed_" + key], {})
        self.assertNotIn(SENSITIVE, json.dumps(runner.context))
        self.assertNotIn(TEMP["session_token"], json.dumps(runner.context))

    def test_complete_existing_skips_every_lookup_and_write(self):
        for seed in self.seeds():
            runner = SeedRunner(seed, [result(existing(seed))])
            runner.run()
            self.assertFalse(runner.lookups)
            self.assertFalse(runner.writes)
            self.assertFalse(runner.assumptions)
            self.assert_cleared(runner)

    def test_missing_creates_exact_map_without_tracking_or_owner(self):
        for seed in self.seeds():
            runner = SeedRunner(seed, [result(), result()])
            runner.run()
            self.assertEqual(len(runner.writes), 1)
            manifest = runner.writes[0]
            self.assertEqual(manifest["metadata"], {"namespace": seed["namespace"], "name": seed["name"]})
            self.assertEqual(manifest["type"], "Opaque")
            self.assertEqual(set(manifest["data"]), set(seed["parameters"]))
            self.assertEqual({base64.b64decode(v).decode() for v in manifest["data"].values()}, {SENSITIVE})
            self.assertEqual([call[1] for call in runner.lookups], list(seed["parameters"].values()))
            for _, _, options in runner.lookups:
                self.assertEqual(options["region"], "us-east-2")
                self.assertTrue(options["decrypt"])
                self.assertEqual(options["on_denied"], "error")
                self.assertEqual(options["on_missing"], "error")
                if seed.get("cross_account"):
                    self.assertEqual(options["session_token"], TEMP["session_token"])
                else:
                    self.assertNotIn("access_key", options)
            self.assertEqual(bool(runner.assumptions), bool(seed.get("cross_account")))
            if runner.assumptions:
                self.assertEqual(runner.assumptions[0]["role_arn"],
                                 "arn:aws:iam::111122223333:role/SGFDevsBootstrapTailnetParameterReader")
                self.assertEqual(runner.assumptions[0]["duration_seconds"], 900)
            self.assert_cleared(runner)

    def test_partial_or_empty_existing_is_sanitized_without_writes(self):
        seed = self.seeds()[0]
        key = next(iter(seed["parameters"]))
        for raw in [existing(seed, empty=key), '{"data":{}}',
                    json.dumps({"data": {key: "not-base64"}}), "malformed-" + SENSITIVE]:
            runner = SeedRunner(seed, [result(raw)])
            with self.assertRaises(SafeFailure) as error:
                runner.run()
            self.assertNotIn(SENSITIVE, str(error.exception))
            self.assertIn(seed["name"], str(error.exception))
            self.assertFalse(runner.lookups)
            self.assertFalse(runner.writes)
            self.assert_cleared(runner)

    def test_already_exists_race_accepts_complete_winner(self):
        seed = self.seeds()[0]
        runner = SeedRunner(seed, [result(), result(rc=1, stderr="AlreadyExists"), result(existing(seed))])
        runner.run()
        self.assertEqual(len(runner.writes), 1, "Only the create attempt, never an update")
        self.assertFalse(runner.responses)
        self.assert_cleared(runner)

    def test_raced_partial_winner_fails_without_repair(self):
        seed = self.seeds()[0]
        key = next(iter(seed["parameters"]))
        runner = SeedRunner(seed, [result(), result(rc=1, stderr="AlreadyExists"), result(existing(seed, key))])
        with self.assertRaisesRegex(SafeFailure, "Missing or empty keys: " + key):
            runner.run()
        self.assertEqual(len(runner.writes), 1)
        self.assert_cleared(runner)

    def test_lookup_and_creation_failures_do_not_leak_or_continue(self):
        seed = self.seeds()[0]
        for category in ["AccessDenied", "ParameterNotFound", "DecryptionFailure"]:
            runner = SeedRunner(seed, [result()], lookup_error=category + "-" + SENSITIVE)
            with self.assertRaises(SafeFailure) as error:
                runner.run()
            self.assertNotIn(SENSITIVE, str(error.exception))
            self.assertFalse(runner.writes)
            self.assert_cleared(runner)
        runner = SeedRunner(seed, [result(), result(rc=1, stderr="Denied-" + SENSITIVE)])
        with self.assertRaises(SafeFailure) as error:
            runner.run()
        self.assertNotIn(SENSITIVE, str(error.exception))
        self.assertEqual(len(runner.writes), 1)
        self.assert_cleared(runner)
        runner = SeedRunner(seed, [result(rc=1, stderr=SENSITIVE)])
        with self.assertRaises(SafeFailure):
            runner.run()
        self.assertFalse(runner.lookups)
        self.assert_cleared(runner)

    def test_empty_parameter_stops_before_create(self):
        seed = self.seeds()[0]
        path = next(iter(seed["parameters"].values()))
        runner = SeedRunner(seed, [result()], values={path: ""})
        with self.assertRaises(SafeFailure):
            runner.run()
        self.assertFalse(runner.writes)
        self.assert_cleared(runner)

    def test_multi_key_storage_preserves_labels_and_skips_complete(self):
        seed = {"namespace": "seaweedfs", "name": "seaweedfs-s3-admin",
                "labels": {"app.kubernetes.io/part-of": "seaweedfs"},
                "parameters": {"access_key": "/synthetic/access", "secret_key": "/synthetic/secret"}}
        runner = SeedRunner(seed, [result(existing(seed))])
        runner.run()
        self.assertFalse(runner.lookups)
        runner = SeedRunner(seed, [result(), result()])
        runner.run()
        self.assertEqual(runner.writes[0]["metadata"]["labels"], seed["labels"])
        self.assertEqual(len(runner.lookups), 2)
        runner = SeedRunner(seed, [result(existing(seed, "secret_key"))])
        with self.assertRaisesRegex(SafeFailure, "secret_key"):
            runner.run()
        self.assertFalse(runner.writes)

    def test_task_security_contract(self):
        task = yaml.safe_load((ROLE / "tasks/seed-secret.yml").read_text())[0]
        self.assertTrue(task["no_log"])
        self.assertFalse(task["diff"])
        self.assertTrue(task["run_once"])
        self.assertFalse(task["rescue"][0]["no_log"], "Only sanitized failure is visible")
        source = (ROLE / "tasks/seed-secret.yml").read_text()
        self.assertNotIn("cacheable: true", source)
        self.assertNotIn("shell:", source)
        self.assertNotIn("kubectl apply", source)
        self.assertNotIn("ansible.builtin.copy", source)
        self.assertNotIn("ansible.builtin.template", source)


if __name__ == "__main__":
    unittest.main()
