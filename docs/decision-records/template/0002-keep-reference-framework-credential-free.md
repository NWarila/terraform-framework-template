# ADR-template/0002: Keep the Reference Framework Credential-Free

| Field          | Value                                   |
| -------------- | --------------------------------------- |
| Status         | Accepted                                |
| Date           | 2026-05-11                              |
| Authors        | Nick Warila (@NWarila)                  |
| Decision-maker | Nick Warila (sole portfolio maintainer) |
| Consulted      | None.                                   |
| Informed       | None.                                   |
| Reversibility  | Medium                                  |
| Review-by      | N/A (Accepted)                          |

## TL;DR

`terraform-framework-template` is a reference framework, not a production deployment. Its own Terraform module MUST stay credential-free and cost-free: local backend, no cloud accounts, no secrets, and only synthetic or local providers. Derivative frameworks replace the synthetic resources with real providers and own the provider-specific threat model, backend policy, and credential path in their repository tier.

## Context and Problem Statement

This repository has two jobs that pull in opposite directions:

1. It must be a realistic enough Terraform framework to prove the pattern end to end.
2. It must be safe for anyone to clone, run in CI, and use as a template without provisioning external infrastructure.

If the reference framework used AWS, GCP, Azure, Proxmox, or another real API, every validation run would require accounts, credentials, quota, cleanup, and a cost model. That would make the template harder to trust and harder to contribute to. If the reference framework were only static HCL with no apply path, it would fail to prove the lifecycle runner repositories depend on.

The chosen middle is a synthetic framework that still performs real Terraform work: it expands input data, creates local artifacts, produces state, runs `terraform test`, generates docs, and exercises the reusable deploy workflow shape without contacting external services.

## Decision Drivers

1. **Clone-and-run safety.** A new contributor should be able to run the framework checks without secrets or accounts.
2. **No surprise cost.** Template CI must never create billable external resources.
3. **Pattern fidelity.** The reference still needs real state, outputs, tests, generated docs, and dynamic Terraform constructs.
4. **Derivative clarity.** Real frameworks should make their provider-specific choices explicitly instead of inheriting sample cloud resources.
5. **Security hygiene.** The reference template should not normalize long-lived secrets or overbroad cloud roles.

## Considered Options

1. Credential-free synthetic reference framework.
2. AWS-backed reference framework.
3. Multi-cloud reference framework.
4. Static HCL skeleton with no real apply path.

## Decision Outcome

Chosen option: **Option 1, credential-free synthetic reference framework.**

This repository's own Terraform module MUST:

- Use a local backend so tests and integration run without remote state.
- Avoid any provider that requires external credentials or accounts.
- Avoid repository secrets for self-validation.
- Exercise realistic Terraform patterns with synthetic providers and local artifacts.
- Keep production backend and provider decisions out of this template unless a future ADR supersedes this one.

Derivative frameworks MUST replace the synthetic implementation details with their real provider, backend, tests, and threat-model addenda. They SHOULD keep the same command surface (`make ci`, `make integration`, generated docs, OPA policy, and reusable workflow contracts) unless they record a superseding ADR.

## Pros and Cons of the Options

### Option 1: Credential-free synthetic reference framework

- **Good, because** it is safe to run in forks, local workstations, and CI without secrets.
- **Good, because** all template validation remains deterministic and cheap.
- **Good, because** real frameworks are forced to document their own provider and backend risks.
- **Bad, because** the reference cannot prove cloud-specific IAM, quota, or API behavior.

### Option 2: AWS-backed reference framework

- **Good, because** it would demonstrate a common production backend and provider path.
- **Bad, because** it would require credentials and account setup before the template can validate.
- **Bad, because** it would make AWS look mandatory for every derivative framework.

### Option 3: Multi-cloud reference framework

- **Good, because** it would show provider diversity.
- **Bad, because** it would multiply credentials, cost, cleanup, and documentation burden.

### Option 4: Static HCL skeleton with no real apply path

- **Good, because** it is simple.
- **Bad, because** it does not prove state, tests, outputs, docs, or runner lifecycle behavior.

## Confirmation

1. The reference `terraform/versions.tf` provider set MUST remain limited to providers that work without external service credentials.
2. `ci.yaml` MUST NOT require repository secrets to run the framework validation path.
3. `make verify` MUST continue to exercise a real Terraform lifecycle without external services.
4. Production provider or backend adoption in this template MUST be recorded as a superseding ADR.

## Consequences

### Positive

- The template stays safe and cheap to validate on every PR.
- Contributors can reason about framework mechanics without learning a cloud API first.
- Derivative frameworks get a clean starting pattern instead of a partially opinionated production stack.

### Negative

- Provider-specific IAM, rate-limit, quota, and backend behavior are not proven here.
- Some production concerns are documented as patterns rather than executed by this repository.

### Neutral

- Real frameworks are expected to diverge in `terraform/` while retaining the validation and workflow interface.

## Assumptions

1. Synthetic providers remain sufficient to exercise the Terraform language and lifecycle patterns this template demonstrates.
2. Derivative frameworks will add provider-specific tests and threat-model notes when they introduce real services.
3. The local backend remains acceptable for the reference template because the state is disposable.

## Supersedes

None.

## Superseded by

None (current).

## Implementing PRs

Pending.

## Related ADRs

- [ADR-template/0001](0001-pin-terraform-and-provider-versions-exactly.md) pins the Terraform and provider versions used by the synthetic reference.

## Compliance Notes

- NIST SP 800-53 Rev. 5 SA-11: a credential-free reference makes the template validation path repeatable in untrusted forks.
- NIST SP 800-218 SSDF PO.5: avoiding secrets in template CI reduces development-environment exposure.
