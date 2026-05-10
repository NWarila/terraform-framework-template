# Invariants

- **Frameworks own Terraform code.** A framework contains `terraform/` and exposes plan/apply through the framework deploy reusable.
- **Org-owned policy files and ADR mirrors stay byte-identical with `nwarila-platform/.github`.** `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `LICENSE`, org ADRs, and layout sentinels are enforced by the org drift gate.
- **Runners own inventory data.** Runner repos provide `repos/` data and call this framework by SHA; they do not mutate the framework source.
- **Terraform and provider versions are exact pins.** `terraform/versions.tf` uses `= X.Y.Z` for the CLI and every provider.
- **Workflow `uses:` references are SHA-pinned.** Local `./...` reusable calls and digest-pinned docker images are allowed.
- **The reference framework remains credential-free.** Synthetic providers are used so tests and integration run without cloud accounts, secrets, or recurring cost.
- **Generated Terraform docs are checked, not trusted.** `docs/reference/terraform.md` must match `terraform-docs` output.
- **Template-tier baseline entries must resolve on disk.** `baseline-manifest.json` is load-bearing for derivative framework drift gates and covers only stable scaffold files, not framework-specific Terraform implementation details.
