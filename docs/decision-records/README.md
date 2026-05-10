# Architecture Decision Records

This directory holds the Architecture Decision Records (ADRs) governing this framework. Per [org ADR-0001](org/0001-use-architecture-decision-records.md), ADRs are organized into three scopes:

- `org/` — byte-identical mirrors of org-baseline ADRs from [`nwarila-platform/.github`](https://github.com/nwarila-platform/.github). Apply to every repo in the org regardless of stack. Drift-gated by [`.github/workflows/drift-gate.yaml`](../../.github/workflows/drift-gate.yaml), alongside the org-owned top-level policy files.
- `template/` — byte-identical mirrors of template-tier ADRs (none yet for this framework-example, since it doesn't derive from a type-template).
- `repo/` — repository-specific ADRs (none yet).

This framework-example is a do-nothing reference framework. It mirrors the org baseline, including community-health policy files, so it participates in the same quality-gate fleet as every other repo in the portfolio, but doesn't author its own template-tier or repo-tier decisions.

The `.gitkeep` placeholders in `template/` and `repo/` keep the directory skeleton complete per ADR-0001's Layout-skeleton check, even when those scopes are empty.
