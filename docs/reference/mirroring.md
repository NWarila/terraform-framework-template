# Mirroring And Consumer Baseline

This template is intentionally split into three layers so derivative frameworks
can stay easy to use without losing the deeper platform controls.

## Required Shared Baseline

Derivative frameworks should mirror the files listed in
[`baseline-manifest.json`](../../baseline-manifest.json). That set is the stable
scaffold: repository hygiene, docs layout checks, drift manifest validation,
security callers, OPA policy, reusable deploy validation, and the Python
verification entrypoint.

## Framework-Owned Layer

The `terraform/` implementation, examples, provider choices, and framework ADRs
are allowed to diverge. This reference uses synthetic providers so the pattern is
visible without cloud accounts; real frameworks replace that Terraform code with
provider-specific resources while preserving the same validation interface.

## Optional Release Layer

`release.yaml`, release-please config, release evidence, and trusted-bot
auto-merge are supported by this template, but downstream frameworks do not have
to mirror them byte-for-byte. Keep that layer when the repo publishes versioned
releases. Drop it when the repo is only a private implementation detail.

## New Framework Checklist

1. Rewrite `README.md` for the real framework.
2. Replace the synthetic Terraform under `terraform/`.
3. Update examples and generated Terraform docs.
4. Decide whether to keep the optional release layer.
5. Run `python tools/verify.py verify`.
