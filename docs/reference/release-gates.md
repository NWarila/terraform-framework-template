# Release Gates

PRs to `main` on this template must pass:

- `terraform verify` (`make verify`, including Terraform gates, policy, docs, manifest, and integration)
- `actionlint` (workflow syntax)
- `yamllint` (workflow YAML)
- `ruff` (Python tools)
- `markdownlint` (docs)
- `zizmor` (workflow security)
- `org-baseline / verify` (drift-gate against `nwarila-platform/.github` at pinned source-ref)
- `Trivy (filesystem & secrets)`, `Gitleaks (secret scan)`, `zizmor (Actions security)` (security)
- `analyze` (CodeQL)
- `analysis` (Scorecard)

The framework deploy reusable is exercised by runner repositories that call it with a pinned `framework_ref`. This repo's `make integration` covers the local framework assembly path.
