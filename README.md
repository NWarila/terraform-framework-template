# terraform-framework-template

The **do-nothing reference framework** for the NWarila portfolio. GitHub-flagged as a template — derivative frameworks seed from this and replace the synthetic providers with their real ones. Showcases every Terraform-framework pattern (modules, variables, outputs, validation, tests, terraform-docs, OPA, plan/apply lifecycle, drift detection, sensitive output handling) using **synthetic providers only** (`null`, `random`, `local`, `time`, `tls`). Generates real `terraform.tfstate`, `terraform apply` runs end-to-end, `terraform test` exercises real assertions — all without external services, accounts, secrets, or recurring cost.

## What this is, and what it isn't

| | This repo | A real framework |
| --- | --- | --- |
| Demonstrates the framework pattern | ✅ | ✅ |
| Manages real cloud / SaaS infrastructure | ❌ — by design | ✅ |
| Used as the canonical reference for derivative frameworks | ✅ | — |
| Suitable for "consume me to deploy something" | ❌ | ✅ |

If you want to deploy real infrastructure, use a real framework like [`nwarila-platform/proxmox-terraform-framework`](https://github.com/nwarila-platform/proxmox-terraform-framework). **This repo's job is to teach the pattern**, not to do work.

## The packer-aligned style

This framework follows the "packer-aligned" style established in [`nwarila-platform/proxmox-terraform-framework`](https://github.com/nwarila-platform/proxmox-terraform-framework):

| File | Role |
| --- | --- |
| [`terraform/versions.tf`](terraform/versions.tf) | `required_version` + `required_providers` (exact pins per template-tier ADR) |
| [`terraform/providers.tf`](terraform/providers.tf) | Provider blocks. Reference variables directly, no logic. |
| [`terraform/backend.tf`](terraform/backend.tf) | Backend config. Local for this showcase; commented S3/GCS/azurerm/HCP variants for real frameworks. |
| [`terraform/data.tf`](terraform/data.tf) | Data sources. Demonstrates the data-source-injection pattern. |
| [`terraform/variables.tf`](terraform/variables.tf) | **The big file.** Provider-level flat vars + one mega-object per managed resource type with `optional(<type>, <default>)` baked in. |
| [`terraform/locals.tf`](terraform/locals.tf) | Single `locals { }` block with region sections. Expands variables into a keyed map; injects data-source values; flattens nested lists into composite-keyed for_each maps. |
| [`terraform/main.tf`](terraform/main.tf) | **The dumb file.** Pure `each.value["key"]` lookups + dynamic blocks. No computation. |
| [`terraform/outputs.tf`](terraform/outputs.tf) | Per-env composed outputs + sensitive output handling demo. |
| [`terraform/tests/*.tftest.hcl`](terraform/tests/) | `terraform test` runs that actually `apply` against synthetic providers and assert on outputs. |

## Patterns demonstrated

| Pattern | Where to look |
| --- | --- |
| Required + optional scalar variables with `optional(<type>, <default>)` | [`variables.tf`](terraform/variables.tf) inside `all_environments` |
| Custom validation rules (`condition`/`error_message`) | [`variables.tf`](terraform/variables.tf), 4 validations on `all_environments` |
| Sensitive variables with operational-context descriptions | `variable "secret_seed"` in [`variables.tf`](terraform/variables.tf) |
| List-of-objects mega-variable with nested optionals | `manifests`, `lifecycle_hooks` in [`variables.tf`](terraform/variables.tf) |
| Single-optional sub-object (becomes splat-on-optional dynamic block in main.tf) | `rotation`, `certificate`, `pet` in [`variables.tf`](terraform/variables.tf) |
| `<! Note: ... !>` inline comments documenting omitted/computed fields | throughout |
| Data-source-injection pattern | [`data.tf`](terraform/data.tf) → [`locals.tf`](terraform/locals.tf) → [`main.tf`](terraform/main.tf) |
| Tier-based defaults (per-env override falls through to data-source default) | [`locals.tf`](terraform/locals.tf), see `retention_days` / `pet.length` |
| Flat composite-keyed for_each map (nested list-of-objects → iterable resource expansion) | [`locals.tf`](terraform/locals.tf), `manifests_flat`, `lifecycle_hooks_flat` |
| Iterative-children resources via for_each on flattened map | `local_file.manifest`, `null_resource.lifecycle_hook` in [`main.tf`](terraform/main.tf) |
| Filtered for_each for conditional resource creation (0..1 per env) | `time_rotating.environment_rotation`, `tls_self_signed_cert.environment` in [`main.tf`](terraform/main.tf) |
| Splat-on-optional dynamic block (`each.value["foo"][*]`) | `dynamic "subject"` block in [`main.tf`](terraform/main.tf) |
| Sensitive output handling | `environment_secrets`, `environment_certificates` in [`outputs.tf`](terraform/outputs.tf) |
| Aggregate roll-up outputs | `framework_summary` in [`outputs.tf`](terraform/outputs.tf) |
| `terraform test` with real `apply` + output assertions | [`tests/synthetic_environments.tftest.hcl`](terraform/tests/synthetic_environments.tftest.hcl) |
| Validation-rejection tests using `expect_failures` | same file, runs 5+ |

## Quickstart

```sh
# Repo-local quality gate.
make ci

# Exercise the quickstart input in an ephemeral workspace.
make integration
```

`make ci` runs Terraform formatting, init, validate, TFLint, tests, OPA policy checks, and terraform-docs drift checks. It does not read a local `terraform/terraform.tfvars`; its Terraform coverage comes from the committed tests under [`terraform/tests/`](terraform/tests/).

`make integration` builds an ephemeral workspace under `.tmp/ci/integration/` from `terraform/`, copies [`examples/single-environment/terraform.tfvars.example`](examples/single-environment/terraform.tfvars.example) into that workspace, and runs the Terraform-facing gates against the assembled module. `make verify` runs both layers.

State produced by `terraform test` lives inside the test sandbox and is torn down on completion.

## Normalized repo interface

This repo uses the same validation command surface as the Terraform runner template:

| Command | Purpose |
| --- | --- |
| `make lint` | Repo-local static checks: fmt, init, validate, TFLint, Python tools, workflow YAML. |
| `make policy` | OPA policy tests plus policy evaluation against real repo files. |
| `make docs-check` | terraform-docs drift check plus Diataxis/ADR documentation layout. |
| `make ci` | Repo-local quality gate. |
| `make integration` | Ephemeral framework workspace assembled from `terraform/` and `examples/`. |
| `make verify` | Full local verification: `ci` plus `integration`. |

To see the framework apply against richer input:

```sh
cp examples/multi-environment/terraform.tfvars.example terraform/terraform.tfvars
( cd terraform && terraform init && terraform apply )
# Inspect produced state:
( cd terraform && terraform state list )
# Real per-env files appear under terraform/.synthetic-output/
ls -la terraform/.synthetic-output/*/
```

## State backend

This showcase uses the **local backend** so the example always works without external setup. Production frameworks should use a remote backend with native state locking. See the commented variants in [`terraform/backend.tf`](terraform/backend.tf) for canonical S3, GCS, azurerm, and HCP Terraform configurations.

## Folding markers (`#region` / `#endregion`)

The HCL files use `#region ------ [ Title ] ----...---- #` / `#endregion --- [ Title ] ----...---- #` markers throughout. These are recognized by the [Explicit Folding](https://marketplace.visualstudio.com/items?itemName=zokugun.explicit-folding) VS Code extension for navigation in long files. The exact regex format is required for the folding rule to match.

## Why "do-nothing"

A do-nothing framework is the strongest possible pattern showcase because it has **zero confounding details**. Every line of HCL is about Terraform itself — module structure, variable shape, locals composition, resource expansion, dynamic block patterns — not about understanding what an AWS S3 bucket means or how the Proxmox API behaves. Real frameworks layer provider semantics on top of this foundation; the foundation has to be right before the provider semantics matter.

The synthetic providers (`null`, `random`, `local`, `time`, `tls`) were chosen because:

- All five are official HashiCorp providers with dead-stable APIs (~zero breaking changes per year)
- All five are free, all five work offline, all five generate real `terraform.tfstate`
- Together they cover every dynamic-block pattern (iterative blocks, single-optional blocks, splat-on-optional, filtered for_each), sensitive-data handling (private keys), and time-driven resource lifecycles (rotation)

## License

MIT — see [LICENSE](LICENSE).
