# Testing Strategy

## What the tests cover

This template repo's `self-ci.yaml` exercises the framework pattern and its support tooling:

| Layer | Job or target | What it proves |
| --- | --- | --- |
| Terraform module | `make verify` | `fmt`, `init`, `validate`, TFLint, `terraform test`, docs drift, policy, and integration all pass. |
| Workflow YAML | `actionlint` | Workflow files parse and follow GitHub Actions semantics. |
| Workflow security | `zizmor` | Workflow code avoids known dangerous Actions patterns. |
| YAML data | `yamllint` | Workflow YAML is valid and consistently shaped. |
| Python tools | `ruff` | CI helper scripts lint clean. |
| Template manifest | `manifest-check` | The template-tier scaffold manifest loads and every source path exists. |
| Markdown | `markdownlint` | Documentation lints clean. |
| Documentation layout | `docs-layout` | Markdown stays inside the Diataxis and ADR directory structure. |

Derivative frameworks exercise this template by retaining the same `make` interface and replacing only the Terraform implementation details.

## What the tests do not cover

- Real provider credentials and external services; this reference framework uses synthetic providers only.
- Repository ruleset enforcement, branch protection, and required status checks; those live in GitHub settings.
- A production remote backend; the reference keeps local state so the template is runnable without setup.
