# Architecture Decision Records

This directory holds the Architecture Decision Records (ADRs) governing this framework. Per [org ADR-0001](org/0001-use-architecture-decision-records.md), ADRs are organized into three scopes:

- `org/` - byte-identical mirrors of org-baseline ADRs from [`nwarila-platform/.github`](https://github.com/nwarila-platform/.github). These apply to every repo in the org regardless of stack.
- `template/` - framework-template ADRs owned by this repository. Derivative frameworks mirror these files byte-for-byte through `baseline-manifest.json`.
- `repo/` - repository-specific ADRs for this repository only. This scope is currently empty.

`terraform-framework-template` is itself a type-template: it owns the canonical framework command surface, Terraform module shape, validation tooling, reusable deploy workflow, and framework-tier decisions that derivative framework repositories inherit.

## Template ADRs

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-template/0001](template/0001-pin-terraform-and-provider-versions-exactly.md) | Accepted | Pin the Terraform CLI and every provider to exact versions. |
| [ADR-template/0002](template/0002-keep-reference-framework-credential-free.md) | Accepted | Keep this reference framework credential-free, cost-free, and synthetic. |
| [ADR-template/0003](template/0003-separate-framework-code-from-runner-inventory.md) | Accepted | Separate framework-owned Terraform code from runner-owned inventory data. |
| [ADR-template/0004](template/0004-isolate-pull-request-target-triggers.md) | Accepted | Keep `pull_request_target` isolated to trusted-bot auto-merge, never release publishing. |

## Org ADRs

The `org/` scope is mirrored from `nwarila-platform/.github` and enforced by the org drift gate.

| ADR | Status | Decision |
| --- | --- | --- |
| [ADR-0001](org/0001-use-architecture-decision-records.md) | Accepted | Use ADRs to document design rationale. |
| [ADR-0002](org/0002-adopt-diataxis-documentation-framework.md) | Accepted | Use Diataxis for non-ADR documentation. |
| [ADR-0003](org/0003-use-deny-all-gitignore-strategy.md) | Accepted | Use deny-all `.gitignore` allowlists. |
| [ADR-0004](org/0004-use-renovate-for-dependency-updates.md) | Accepted | Use Renovate for dependency updates. |

The `.gitkeep` placeholder in `repo/` keeps the directory skeleton complete until this repository has a repo-specific ADR.
