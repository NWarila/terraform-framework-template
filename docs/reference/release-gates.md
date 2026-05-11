# Release Gates

PRs to `main` on this template must pass:

- `terraform verify` (`python tools/verify.py verify`, including Terraform gates, source-aware OPA, plan-aware OPA, docs, manifest, and integration)
- `actionlint` (workflow syntax)
- `yamllint` (workflow YAML)
- `ruff` (Python tools)
- `markdownlint` (docs)
- `org-baseline / verify` (drift-gate against `nwarila-platform/.github` at pinned source-ref)
- `Trivy (filesystem & secrets)`, `Gitleaks (secret scan)`, `zizmor (Actions security)` (security)
- `CodeQL` (`security.yaml`)
- `OpenSSF Scorecard` (`security.yaml`)

The framework deploy reusable is exercised by runner repositories that call it with a pinned `framework_ref`. This repo's `python tools/verify.py integration` covers the local framework assembly path.

Release evidence, when `release.yaml` is enabled, uploads the evidence bundle
and SPDX SBOM as release assets and emits GitHub artifact attestations for
bundle provenance and SBOM binding.
