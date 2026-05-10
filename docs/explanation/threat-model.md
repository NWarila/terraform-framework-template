# Threat Model

This document is a STRIDE-style threat model for `NWarila/terraform-framework-template` and, by extension, the framework pattern this template demonstrates. It exists to make the security posture of derivative frameworks legible: a real framework managing real cloud resources inherits the same trust boundaries and the same threat surface the pattern itself has, plus whatever its specific provider adds.

## Scope

What this document covers:

- The framework template repository's own threats (supply chain, CI compromise, contributor account compromise).
- Threats inherent to the framework PATTERN (state file leakage, `terraform plan` output leakage, drift between code and reality).
- Threats inherent to the derivative-consumer pattern (a runner's overlay tree composed at validation time, the SHA-pin chain from runner to framework to drift-gate to canonical).

What this document does NOT cover:

- Threats specific to the synthetic providers (`null`, `random`, `local`, `time`, `tls`). These are stack-internal Terraform features with no external attack surface; their threat model is the Terraform Core threat model, which lives upstream.
- Threats specific to derivative frameworks' real providers (AWS, GCP, Azure, etc.). Each derivative framework owns its own threat model addendum. This document gives them a starting structure.
- Operational runbooks. Incident response procedures live in each consumer's `docs/how-to/`, not here.

## Trust boundaries

Six boundaries cross the framework pattern, each one a candidate for compromise or accidental disclosure:

1. **Author → Repository.** The framework author commits HCL into the repo. Trust depends on the author's GitHub credentials, their commit signing posture, and branch protection on `main`.
2. **Repository → CI runner.** Self-CI checks out the repo onto a GitHub-hosted runner. Trust depends on GitHub's runner-image integrity and GitHub Actions' permission model.
3. **CI runner → Provider registry.** `terraform init` downloads provider plugins from `registry.terraform.io`. Trust depends on the registry, the provider's signing cert (HashiCorp signs official providers), and Terraform Core's verification logic.
4. **CI runner → State backend.** `terraform apply` writes state. For the do-nothing reference framework, state is local in the test sandbox and never leaves the runner. For a derivative framework, state goes to the configured remote backend (S3 per template-tier ADR-template/0002 in the runner-template). Trust depends on the backend service, the encryption configuration, and the IAM/auth path used to reach it.
5. **CI runner → Cloud APIs.** A real framework's `terraform apply` calls the cloud provider's API to create resources. Trust depends on the API's authentication path (OIDC for the cloud per the same ADR-template/0002), the temporary credentials' scope, and the API itself.
6. **Framework → Consumer (template-tier composition).** A runner consumer overlays its `repos/` data onto this framework's `terraform/` tree at validation time. The overlay can change what the framework sees on disk. Trust depends on the runner's contribution discipline (it controls the data) and the overlay mechanism (it controls how data lands in the framework tree).

## Threats by category

### Spoofing

- **Compromised commit on the framework template repo.** An attacker with author credentials commits malicious HCL or workflow YAML to `main`. Mitigation: branch protection requires signed commits, code-owner review, and passing CI. The drift-gate workflow blocks PRs that drift from canonical org-baseline files. The OPA `golden_terraform` policy rejects unsigned `uses:` references and tag-pinned actions.
- **Compromised SHA-pin in a downstream consumer.** A derivative framework's `uses:` line references a forked/squatted repo at a SHA that looks legitimate. Mitigation: the OPA policy requires `uses:` references to be either SHA-pinned, local `./...`, or digest-pinned docker. SHA collisions on Git's SHA-1 are computationally expensive but not impossible; full SHA-256 transitions in Git would close this further. Practically, the SHA-pin discipline is the strongest mitigation available today.
- **Provider registry MITM.** An attacker intercepts the `registry.terraform.io` connection during `terraform init` and serves a malicious provider plugin. Mitigation: Terraform verifies provider plugins against the registry's signing certificate (HashiCorp official providers are signed). `.terraform.lock.hcl` records the H1: hash of every plugin and verifies on subsequent inits. Out of scope: this template doesn't currently commit `.terraform.lock.hcl` because the lockfile is environment-dependent (Linux runners pull different artifacts than Windows or macOS). Derivative frameworks that target a single OS SHOULD commit the lockfile.

### Tampering

- **State file mutation between apply and read.** An attacker modifies `terraform.tfstate` in S3 to change Terraform's view of reality. Mitigation: S3 native locking (template-tier ADR-template/0002) prevents concurrent writes during a transaction. S3 versioning makes prior states recoverable. SSE-KMS encryption on the bucket prevents read-only attackers without KMS access from understanding the state contents (resource ARNs, IAM relationships, sensitive outputs).
- **Overlay path injection.** A runner consumer's `repos/public/` data is overlaid onto the framework's `terraform/` tree at validation time. A malicious entry in the overlay could write to `terraform/versions.tf` or `terraform/providers.tf` and silently change pinned versions. Mitigation: the runner-template's `reusable-terraform-validation.yaml` validates `framework_ref` is a 40-char SHA before checkout. After overlay, the OPA policy re-runs against the assembled tree and rejects modified `versions.tf` / `providers.tf` content (tag/range pins, missing exact-version, etc.). The framework's own files at `framework_ref` stay byte-stable; only the runner's intentional data paths can land via overlay.
- **Cached state-tampering on a CI runner.** A persistent runner reused across jobs could have stale `terraform.tfstate` or `.terraform/` cached from a prior tenant. Mitigation: GitHub-hosted runners are ephemeral by default — each job gets a fresh image. Self-hosted runners that persist between jobs MUST clean working directories between tenants. Out of scope: this template only targets GitHub-hosted runners.

### Repudiation

- **An author denies committing a malicious change.** Mitigation: the org's signed-commits requirement (org ADR-0001 §"required_signatures") makes authorship cryptographically verifiable on every commit. Denying authorship requires denying control of the signing key, which is a separate (much higher-bar) compromise scenario.
- **A consumer denies running an apply that broke production.** Mitigation: every apply executed via the framework's `reusable-terraform-deploy.yaml` runs in GitHub Actions, producing a tamper-evident workflow run record (run ID, actor, commit SHA, timestamp). The plan + state artifacts uploaded by the workflow form the immutable evidence trail. AWS-side: CloudTrail records every API call the apply made.

### Information Disclosure

- **State file contains sensitive resource attributes.** `terraform.tfstate` records every attribute of every resource Terraform manages, including provisioned secrets, derived ARNs, account IDs, and sensitive variable values. The state file IS sensitive material. Mitigation: SSE-KMS encryption at rest on the S3 bucket; bucket policy restricts read access to specific IAM principals; bucket access logging records every read. The framework itself uses `sensitive = true` on outputs that contain credential material (`environment_secrets`, `environment_certificates` in `outputs.tf`) so the values are redacted in CLI output.
- **`terraform plan` output leaked via PR comments.** A common pattern is posting plan output as a PR comment for review. Plan output includes proposed resource attribute values, including sensitive defaults. Mitigation: this template does NOT post plan output to PR comments by default. Derivative frameworks that adopt that pattern MUST mask sensitive values in the comment-posting step or skip it for sensitive resources. AWS specifically: `aws-actions/configure-aws-credentials` with `mask-aws-account-id: true` masks the account ID across the entire workflow run.
- **CI workflow logs contain provider credentials.** A misconfigured `terraform plan -debug` or a `set -x` in a wrapper script could echo credentials. Mitigation: this template's workflows don't enable Terraform's verbose debug. OPA + `zizmor` (in the IaC security workflow) flag dangerous inputs as code injection into workflow steps. GitHub Actions' built-in secret masking redacts known-secret values from logs but does NOT catch derived values (e.g., a token base64-decoded into a different form).
- **Public repo accidentally tracking secrets.** A future contributor commits a `terraform.tfvars` containing real credentials into `repos/public/`. Mitigation: the template's `.gitignore` denies all paths by default (per org ADR-0003); explicit allowlist entries gate every tracked file. `repos/public/.gitkeep` and the sample `sample-environments.tfvars` are explicitly allowed; arbitrary `.tfvars` files are NOT (no glob allow). Pre-commit hook + `gitleaks` (in iac-security) catch staged secrets that slip past the allowlist.

### Denial of Service

- **Provider registry unavailability.** If `registry.terraform.io` is down during a CI run, `terraform init` fails. Mitigation: this is a hard external dependency. Workarounds (private Terraform registry mirror, vendored providers) are out of scope for this template; consumers that genuinely need air-gapped operation document their own mitigation in a repo-tier ADR.
- **State backend unavailability.** S3 outage during a deploy means state can't be locked or written. Mitigation: AWS region-failover is a real option for high-stakes deploys but adds setup cost; the template-tier ADR doesn't currently mandate it. The default behavior (deploy fails fast on backend unavailability) is the right one for most cases — better to pause than to apply against stale state.
- **drift-gate as a single point of failure.** Every consumer's PR validation runs against `NWarila/drift-gate` as a SHA-pinned composite action. If that repo is deleted or corrupted, every consumer's drift-gate.yaml fails on next run. Mitigation: drift-gate is in a public repo under the maintainer's control; SHA-pinning means an existing pin keeps working even if the canonical repo is later compromised (the immutable Git SHA still resolves). Consumers that want to harden further could fork drift-gate to a non-maintainer-owned org and pin against that fork.

### Elevation of Privilege

- **Privilege escalation via overlay-injected workflow.** If the overlay mechanism allowed writing to `.github/workflows/`, an attacker controlling runner data could inject a workflow that runs with the framework's permissions. Mitigation: the overlay is constrained to `terraform/repos/` and `terraform/tests/` within the framework tree by convention. The runner contract's `overlay_paths` input requires explicit `<src>=><dst>` pairs; there's no glob or recursive copy that would land in `.github/`. Defense-in-depth: workflows run with `permissions: contents: read` by default in this template; even a successful injection couldn't push code or write protected refs without explicit permission grants.
- **OIDC role over-permission.** A derivative framework's IAM role assumed via OIDC could be over-scoped, granting more permissions than the framework needs. Mitigation: OIDC trust policy SHOULD scope to specific repository / branch / environment claims (`token.actions.githubusercontent.com` claims include `sub`, `actor`, `ref`, `event_name`). The role policy SHOULD use least-privilege grants to specific resource ARNs, not wildcards. This is a per-framework concern; this template doesn't have AWS resources to grant against, but the pattern is documented in [docs/how-to/oidc-trust-setup.md](../how-to/oidc-trust-setup.md) (TBD — pending derivative framework adoption).
- **Cross-job credential reuse.** GitHub Actions' OIDC tokens are scoped per-job. A misconfigured workflow that passes credentials between jobs could expand the trust radius. Mitigation: this template's workflows obtain fresh OIDC tokens per job; no cross-job credential passing.

## Out of scope (and why)

- **Terraform Core vulnerabilities.** Bugs in Terraform itself are outside this template's threat model. Mitigation lives at the Terraform version pin level: ADR-template/0001 requires exact `=` pins so a newly-discovered Terraform CVE forces an explicit, reviewable bump rather than silent uptake of a compromised release.
- **Provider plugin vulnerabilities.** Same reasoning — provider versions are exact-pinned per the same ADR. A CVE in `hashicorp/random` (unlikely; it's tiny) or in a real provider (more likely) is detected via vulnerability scanners (Trivy in `reusable-iac-security.yaml`) and forces an explicit upgrade.
- **Compromise of the upstream HashiCorp signing key.** If HashiCorp's provider-signing key were compromised, every Terraform provider distributed by HashiCorp could be malicious. This is a global-Terraform-ecosystem-wide problem. Mitigations live at HashiCorp; consumers can only respond after disclosure.
- **Compromise of a runner's `repos/private/` S3 bucket.** Runners pull private data from S3 at deploy time. If that bucket were compromised, the data would be tainted at the source. Mitigations live in the runner's ops setup (bucket access policies, MFA-delete, etc.). This template's threat model assumes that bucket is correctly configured.

## Cross-references

- [Org ADR-0003](../decision-records/org/0003-use-deny-all-gitignore-strategy.md) — establishes the deny-all gitignore strategy, which is the primary mitigation for accidental secret tracking.
- [Org ADR-0004](../decision-records/org/0004-use-renovate-for-dependency-updates.md) — establishes the per-template Renovate baseline pattern. SHA-pinning + Renovate-driven bumps mean every dependency change is a reviewable PR rather than silent uptake.
- [Template-tier ADR-template/0001 (in `terraform-runner-template`)](https://github.com/NWarila/terraform-runner-template/blob/main/docs/decision-records/template/0001-pin-terraform-and-provider-versions-exactly.md) — establishes exact-pinning of Terraform CLI and provider versions. Direct mitigation for "silent uptake of a compromised release" listed above.
- [Template-tier ADR-template/0002 (in `terraform-runner-template`)](https://github.com/NWarila/terraform-runner-template/blob/main/docs/decision-records/template/0002-mandate-s3-state-backend.md) — establishes S3 + native locking + OIDC-only auth as the mandatory state backend. Direct mitigation for state-file confidentiality, integrity, and availability concerns.
- [`policies/opa/golden_terraform.rego`](../../policies/opa/golden_terraform.rego) — the OPA policy enforcing SHA-pinned `uses:` references and exact `=` version pins. Mechanical enforcement of several of the mitigations referenced above.

## What a derivative framework adds

A real framework (managing AWS, GCP, Azure, etc.) inherits this threat model and adds, at minimum:

- A section enumerating the cloud-specific resources it manages and the threat each one introduces (e.g., an S3 bucket with `acl = public-read` is a different threat than a private bucket).
- An OIDC trust policy + IAM role policy pair, scoped to the specific framework's repository and the specific resources it provisions.
- A backup/recovery posture for the resources under management — Terraform state recovers via S3 versioning, but the resources themselves may need their own backup story.
- An incident-response runbook (`docs/how-to/incident-response.md` typically) with named response procedures, on-call rotation, and rollback steps.

This template doesn't have any of those — it manages no real resources. The structure here is the canonical starting point a derivative framework's threat model fills in.
