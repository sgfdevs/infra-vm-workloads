"""Repository contracts for prerequisites and GitOps mirror parity."""
import hashlib
import json
import os
import subprocess
from jinja2 import Environment, StrictUndefined
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
ROLE = ROOT / "src/ansible/roles/bootstrap_argocd"
EXPECTED = json.loads((ROOT / "tests/gitops-bootstrap-contract.json").read_text())


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


class BootstrapContract(unittest.TestCase):
    def test_cold_prerequisite_order(self):
        tasks = yaml.safe_load((ROLE / "tasks/main.yml").read_text())
        imports = [task["ansible.builtin.import_tasks"] for task in tasks]
        self.assertLess(imports.index("prepare.yml"), imports.index("seed-bootstrap-secrets.yml"))
        self.assertLess(imports.index("seed-bootstrap-secrets.yml"), imports.index("operators.yml"))
        self.assertLess(imports.index("operators.yml"), imports.index("platform.yml"))
        self.assertLess(imports.index("platform.yml"), imports.index("apps.yml"))
        prepare = yaml.safe_load((ROLE / "tasks/prepare.yml").read_text())
        names = [task["name"] for task in prepare]
        self.assertLess(names.index("Apply AWS runtime ConfigMap"),
                        names.index("Install admission expansion before operator ServiceAccounts are created"))
        self.assertEqual(prepare[0]["name"], "Reject unsafe controller debug logging before fetching parameters")

    def test_gitops_mirror_and_seed_map(self):
        health = yaml.safe_load((ROLE / "files/argocd-application-health.yaml").read_text())["data"]
        self.assertEqual({key: digest(value) for key, value in health.items()}, EXPECTED["health"])
        admission = list(yaml.safe_load_all((ROLE / "files/aws-role-arn-expansion.yaml").read_text()))
        self.assertEqual(digest(admission), EXPECTED["admission"])
        defaults = yaml.safe_load((ROLE / "defaults/main.yml").read_text())
        seeds = defaults["bootstrap_argocd_ingress_seeds"]
        self.assertEqual({seed["namespace"] + "/" + seed["name"]: seed["parameters"] for seed in seeds}, EXPECTED["seeds"])
        self.assertEqual(len(seeds), 4)
        self.assertEqual({item["resource"] + "/" + item.get("namespace", "") for item in defaults["bootstrap_argocd_aws_resources"]},
                         set(EXPECTED["eso"]))
        self.assertFalse(any("secretstore/" in item["resource"] for item in defaults["bootstrap_argocd_foundation_resources"]))

    def test_admission_is_fail_closed_and_supports_serviceaccount_creation(self):
        policy, binding = yaml.safe_load_all((ROLE / "files/aws-role-arn-expansion.yaml").read_text())
        self.assertEqual(policy["spec"]["failurePolicy"], "Fail")
        self.assertEqual(policy["spec"]["reinvocationPolicy"], "IfNeeded")
        rule = policy["spec"]["matchConstraints"]["resourceRules"][0]
        self.assertEqual(rule["resources"], ["serviceaccounts"])
        self.assertEqual(rule["operations"], ["CREATE", "UPDATE"])
        self.assertEqual(binding["spec"]["paramRef"]["parameterNotFoundAction"], "Deny")
        self.assertEqual(binding["spec"]["paramRef"]["namespace"], "kube-system")
        self.assertEqual(binding["spec"]["paramRef"]["name"], "aws-runtime")
        self.assertEqual(binding["spec"]["policyName"], policy["metadata"]["name"])

    def test_stage_waits_and_legacy_opt_in(self):
        tasks = yaml.safe_load((ROLE / "tasks/platform.yml").read_text())
        names = [task["name"] for task in tasks]
        self.assertLess(names.index("Wait for foundation Application"),
                        names.index("Wait for issuer and its current revision public hook when opted in"))
        self.assertLess(names.index("Wait for issuer and its current revision public hook when opted in"),
                        names.index("Wait for AWS configuration Application after the issuer"))
        self.assertEqual(tasks[-1]["name"], "Wait for actual ESO store and ExternalSecret conditions before applications")
        wait = yaml.safe_load((ROLE / "tasks/wait-application.yml").read_text())[0]
        self.assertTrue(wait["run_once"])
        self.assertIn("bootstrap_argocd_issuer_operation_annotation", wait["until"][-1])
        self.assertIn("'Succeeded'", wait["until"][-1])
        self.assertIn("'syncResult'", wait["until"][-1])
        self.assertIn("'operation'", wait["until"][-1])

    def test_actual_wait_expression_and_legacy_compatibility(self):
        task = yaml.safe_load((ROLE / "tasks/wait-application.yml").read_text())[0]
        annotation = yaml.safe_load((ROLE / "defaults/main.yml").read_text())["bootstrap_argocd_issuer_operation_annotation"]
        env = Environment(undefined=StrictUndefined)
        env.filters["from_json"] = json.loads
        for phase, revision, pending, gated, expected in [
            ("Succeeded", "current", False, True, True),
            ("Succeeded", "stale", False, True, False),
            ("Succeeded", "current", True, True, False),
            ("Running", "current", False, True, False),
            ("Failed", "current", False, True, False),
            ("", "", False, True, False),
            ("", "", False, False, True)]:
            app = {"metadata": {"annotations": {annotation: "true"} if gated else {}},
                   "status": {"sync": {"status": "Synced", "revision": "current"},
                              "health": {"status": "Healthy"},
                              "operationState": {"phase": phase, "syncResult": {"revision": revision}}}}
            if pending:
                app["operation"] = {"sync": {}}
            context = {"_bootstrap_argocd_application_read": {"rc": 0, "stdout": json.dumps(app)},
                       "bootstrap_argocd_issuer_operation_annotation": annotation}
            for key, value in task["vars"].items():
                context[key] = env.compile_expression(value.strip()[2:-2].strip())(**context)
            result = all(env.compile_expression(condition)(**context) for condition in task["until"])
            self.assertEqual(result, expected, (phase, revision, pending, gated))

    def test_workflow_bootstrap_credential_guard(self):
        workflow = yaml.safe_load((ROOT / ".github/workflows/ansible-manual.yml").read_text())
        script = workflow["jobs"]["bootstrap-inputs"]["steps"][0]["run"]
        for playbook in ["argocd-bootstrap.yml", "cluster-bootstrap.yml"]:
            for initialize, ref, rc in [("true", "refs/heads/main", 0),
                                        ("false", "refs/heads/main", 1),
                                        ("true", "refs/heads/feature", 1)]:
                result = subprocess.run(["bash", "-c", script], env={**os.environ,
                    "PLAYBOOK": playbook, "INITIALIZE_TERRAFORM": initialize, "GITHUB_REF": ref},
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, rc)
        self.assertEqual(workflow["jobs"]["run"]["needs"], "bootstrap-inputs")

    def test_no_eager_storage_fetches(self):
        prepare = (ROLE / "tasks/prepare.yml").read_text()
        self.assertNotIn("bootstrap_argocd_seaweedfs", prepare)
        source = ROLE / "tasks/seed-secrets.yml"
        if source.exists():
            tasks = yaml.safe_load(source.read_text())
            self.assertEqual(tasks[0]["ansible.builtin.include_tasks"], "seed-secret.yml")
            self.assertEqual(len(tasks[0]["loop"]), 3)
            for seed in tasks[0]["loop"]:
                self.assertEqual(seed["labels"], {"app.kubernetes.io/part-of": "seaweedfs"})
                self.assertEqual(len(seed["parameters"]), 2)


if __name__ == "__main__":
    unittest.main()
