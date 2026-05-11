#!/usr/bin/env python3
"""Cross-platform verification entrypoint for the framework template."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PYTHON = sys.executable
YAMLLINT_CONFIG = (
    "{ extends: relaxed, rules: { line-length: disable, document-start: disable, "
    "comments: disable, truthy: {check-keys: false} } }"
)


Step = Callable[[], None]


def run(args: list[str], *, input_text: str | None = None) -> None:
    print("+ " + " ".join(args), flush=True)
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            input=input_text,
            text=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"missing executable: {args[0]}") from exc
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def capture(args: list[str], *, input_text: str | None = None) -> str:
    print("+ " + " ".join(args), flush=True)
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            capture_output=True,
            input=input_text,
            text=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"missing executable: {args[0]}") from exc
    if completed.returncode != 0:
        sys.stdout.write(completed.stdout)
        sys.stderr.write(completed.stderr)
        raise SystemExit(completed.returncode)
    return completed.stdout


def install(package: str) -> None:
    if os.environ.get("CI", "").lower() != "true":
        print(f"local run: not installing {package}; expecting it to be available", flush=True)
        return
    run([PYTHON, "-m", "pip", "install", "--no-cache-dir", package])


def opa_policy() -> None:
    install("pyyaml==6.0.3")
    opa_input = capture([PYTHON, "tools/build_opa_input.py"])
    run(
        [
            "opa",
            "eval",
            "--fail-defined",
            "--format",
            "pretty",
            "--stdin-input",
            "--data",
            "policies/opa",
            "data.repo_hygiene.deny[_]",
        ],
        input_text=opa_input,
    )


def opa_plan() -> None:
    plan_dir = ROOT / ".tmp" / "opa-plan"
    plan_dir.mkdir(parents=True, exist_ok=True)
    plan_path = "../.tmp/opa-plan/framework-plan.tfplan"

    run(["terraform", "-chdir=terraform", "init", "-backend=false", "-input=false"])
    run(
        [
            "terraform",
            "-chdir=terraform",
            "plan",
            "-input=false",
            "-out",
            plan_path,
            "-var-file=../examples/multi-environment/terraform.tfvars.example",
        ]
    )
    plan_json = capture(["terraform", "-chdir=terraform", "show", "-json", plan_path])
    opa_input = capture([PYTHON, "tools/build_plan_input.py"], input_text=plan_json)
    for query in ("data.synthetic_framework_plan.deny[_]", "data.terraform_plan.deny[_]"):
        run(
            [
                "opa",
                "eval",
                "--fail-defined",
                "--format",
                "pretty",
                "--stdin-input",
                "--data",
                "policies/opa",
                query,
            ],
            input_text=opa_input,
        )


def build_steps(case: str) -> dict[str, Step]:
    shell_helpers = sorted(
        path.relative_to(ROOT).as_posix() for path in (ROOT / "tools" / "ci").glob("*.sh")
    )
    bats_tests = sorted(
        path.relative_to(ROOT).as_posix() for path in (ROOT / "tests" / "ci").glob("*.bats")
    )
    return {
        "fmt": lambda: run(["terraform", "-chdir=terraform", "fmt", "-recursive"]),
        "fmt-check": lambda: run(
            ["terraform", "-chdir=terraform", "fmt", "-check", "-recursive"]
        ),
        "init": lambda: run(
            ["terraform", "-chdir=terraform", "init", "-backend=false", "-input=false"]
        ),
        "validate": lambda: run(["terraform", "-chdir=terraform", "validate"]),
        "tflint": lambda: (
            run(["tflint", "--init", "--config", str(ROOT / ".tflint.hcl")]),
            run(["tflint", "--config", str(ROOT / ".tflint.hcl"), "--chdir", "terraform"]),
        ),
        "ruff": lambda: (
            install("ruff==0.13.0"),
            run([PYTHON, "-m", "ruff", "check", "tools/"]),
        ),
        "yamllint": lambda: (
            install("yamllint==1.35.1"),
            run([PYTHON, "-m", "yamllint", "-d", YAMLLINT_CONFIG, ".github/workflows/"]),
        ),
        "test": lambda: run(["terraform", "-chdir=terraform", "test"]),
        "workflow-helper-tests": lambda: (
            run(["shellcheck", *shell_helpers]),
            run([PYTHON, "tools/ci/check_workflow_run_inputs.py", ".github/workflows"]),
            run(["bats", *bats_tests]),
        ),
        "opa-test": lambda: run(["opa", "test", "policies/opa"]),
        "opa-policy": opa_policy,
        "opa-plan": opa_plan,
        "manifest-check": lambda: (
            run([PYTHON, "tools/check_baseline_manifest.py"]),
            run([PYTHON, "tools/check_baseline_self_consistency.py"]),
        ),
        "docs": lambda: run(["terraform-docs", "--config", ".terraform-docs.yml", "terraform"]),
        "docs-diff": lambda: run(
            [
                "terraform-docs",
                "--config",
                ".terraform-docs.yml",
                "--output-check",
                "terraform",
            ]
        ),
        "docs-layout": lambda: run([PYTHON, "tools/check_docs_layout.py"]),
        "adr-schema": lambda: run([PYTHON, "tools/check_adr_schema.py"]),
        "integration": lambda: run(
            [PYTHON, "tools/ci/run_integration.py", "--case", case]
        ),
    }


TARGETS: dict[str, tuple[str, ...]] = {
    "lint": ("fmt-check", "init", "validate", "tflint", "ruff", "yamllint"),
    "policy": ("opa-test", "opa-policy", "opa-plan"),
    "docs-check": ("docs-diff", "docs-layout", "adr-schema"),
    "ci": ("lint", "test", "policy", "docs-check", "manifest-check"),
    "verify": ("ci", "integration"),
}


def execute(name: str, steps: dict[str, Step]) -> None:
    if name in TARGETS:
        for child in TARGETS[name]:
            execute(child, steps)
        return
    steps[name]()


def main() -> int:
    choices = sorted(set(TARGETS) | set(build_steps("basic")))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", nargs="?", default="verify", choices=choices)
    parser.add_argument("--case", default="basic", help="Integration case to run.")
    args = parser.parse_args()

    execute(args.target, build_steps(args.case))
    return 0


if __name__ == "__main__":
    sys.exit(main())
