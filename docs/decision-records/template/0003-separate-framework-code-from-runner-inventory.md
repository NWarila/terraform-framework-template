# ADR-template/0003: Separate Framework Code From Runner Inventory

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

Framework repositories own Terraform code, reusable deploy workflows, CI helper tooling, generated Terraform docs, and template-tier framework ADRs. Runner repositories own inventory data and call a framework by immutable `framework_ref`. Runners may overlay their data into a checked-out framework workspace for validation or deploy, but they do not own or mutate the framework source.

## Context and Problem Statement

The portfolio has two Terraform repository shapes:

- **Frameworks** contain `terraform/`, tests, docs, policy, and the reusable workflow that can plan or apply the framework.
- **Runners** contain environment or repository inventory and invoke a pinned framework.

Before this decision is explicit, it is easy for the boundary to blur. A runner can look like it owns Terraform because it triggers deploys. A framework can look like it owns runner data because integration tests assemble an overlay workspace. Template-tier ADRs can drift into the wrong repository, leaving a downstream reader unsure which repo is the canonical source for which pattern.

This ADR names the ownership boundary so changes land in the repo that owns the decision.

## Decision Drivers

1. **Clear source of truth.** Framework patterns should be authored where the framework code and reusable deploy workflow live.
2. **Small runner blast radius.** Runner repos should change inventory and pins, not shared Terraform implementation.
3. **Reviewability.** A framework code change should be reviewed once in the framework repo, then consumed by SHA.
4. **Drift control.** Template-tier baseline manifests should mirror stable framework scaffolding into derivative frameworks.
5. **Overlay safety.** Runtime composition must be explicit and constrained.

## Considered Options

1. Separate framework code from runner inventory.
2. Put Terraform code and inventory in every runner.
3. Put runner inventory in the framework template.
4. Use a shared package or submodule for the framework instead of template repositories.

## Decision Outcome

Chosen option: **Option 1, separate framework code from runner inventory.**

Framework repositories derived from this template own:

- `terraform/` implementation, tests, generated Terraform docs, and provider pins.
- Reusable framework workflows such as `reusable-terraform-deploy.yaml`.
- Framework CI helpers under `tools/ci/`.
- OPA policy and documentation that govern framework behavior.
- Framework-template ADRs under `docs/decision-records/template/`.
- `baseline-manifest.json` entries for stable scaffold files derivative frameworks should mirror.

Runner repositories own:

- Inventory data such as `repos/public/` and `repos/private/`.
- Workflow callers that pin a framework `framework_ref`.
- Environment-specific backend configuration, deploy inputs, and approvals.
- Runner-specific ADRs that explain local inventory or deployment exceptions.

Overlay composition is allowed only as an execution mechanism: a runner checks out a framework at a pinned ref and copies approved data paths into the framework workspace before validation or deploy. The overlay does not make the runner the owner of framework code.

## Pros and Cons of the Options

### Option 1: Separate framework code from runner inventory

- **Good, because** shared Terraform behavior is fixed once and consumed by SHA.
- **Good, because** runner changes are small, data-oriented, and easy to review.
- **Good, because** template-tier ADR ownership matches the code ownership boundary.
- **Bad, because** changes that need both framework and runner updates require coordinated PRs.

### Option 2: Put Terraform code and inventory in every runner

- **Good, because** each runner is self-contained.
- **Bad, because** shared Terraform logic drifts across repositories.
- **Bad, because** security and provider updates must be repeated in every runner.

### Option 3: Put runner inventory in the framework template

- **Good, because** there is one repo to inspect.
- **Bad, because** unrelated environments become coupled to one shared framework history.
- **Bad, because** a framework template cannot be reused cleanly by multiple inventories.

### Option 4: Use a shared package or submodule

- **Good, because** it is another way to centralize framework code.
- **Bad, because** it adds Git/submodule workflow complexity without solving the ADR ownership problem better than pinned template refs.

## Confirmation

1. Framework repositories MUST contain `terraform/`; runner repositories MUST NOT rely on local framework source as their source of truth.
2. Runner workflow callers MUST pin framework references to immutable SHAs.
3. Overlay tooling MUST use explicit source-to-destination mappings, not broad workspace copies.
4. Template-tier framework ADRs MUST be authored in this repository and mirrored to derivative frameworks through `baseline-manifest.json`.
5. Runner-specific exceptions MUST live in the runner repository's `docs/decision-records/repo/` scope.

## Consequences

### Positive

- The architecture is easier to explain: frameworks build the machine, runners feed it data.
- Framework fixes and security updates flow through SHA bumps instead of copy-paste edits.
- Template-tier ADRs now live beside the framework decisions they document.

### Negative

- A framework interface change can require synchronized runner updates.
- Overlay tooling must be kept boring and well-tested, because it is the join point between the two shapes.

### Neutral

- A repository can still intentionally combine shapes, but it must document that exception and pass explicit type checks.

## Assumptions

1. Runner repositories remain data-first deployers.
2. Framework repositories remain the right unit for Terraform module and reusable deploy workflow ownership.
3. Git SHA pins remain the deployment boundary between runner and framework.

## Supersedes

None.

## Superseded by

None (current).

## Implementing PRs

Pending.

## Related ADRs

- [ADR-template/0001](0001-pin-terraform-and-provider-versions-exactly.md) establishes the framework toolchain pinning policy.
- [ADR-template/0002](0002-keep-reference-framework-credential-free.md) explains why this template's own framework implementation stays synthetic.

## Compliance Notes

- NIST SP 800-53 Rev. 5 CM-3: separating framework code changes from runner inventory changes improves configuration change traceability.
- NIST SP 800-218 SSDF PO.3: clear ownership boundaries make it easier to define review responsibilities for reusable infrastructure code.
