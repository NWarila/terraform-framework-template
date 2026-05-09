PYTHON ?= python3

# Mutating: rewrites HCL in place. Use locally before committing.
fmt:
	terraform -chdir=terraform fmt -recursive

# Non-mutating: fails if any file would change. Use in CI.
fmt-check:
	terraform -chdir=terraform fmt -check -recursive

init:
	terraform -chdir=terraform init -backend=false -input=false

validate:
	terraform -chdir=terraform validate

# Real apply against synthetic resources via `terraform test`.
# Generates a real terraform.tfstate inside the test sandbox,
# asserts on outputs, and tears down cleanly. Demonstrates that
# this framework's full lifecycle works end-to-end without external
# providers.
test:
	terraform -chdir=terraform test

# OPA policy tests. Exercises every deny rule in
# policies/opa/golden_terraform.rego against pass + fail fixtures.
opa-test:
	opa test policies/opa

# Mutating: regenerates the BEGIN_TF_DOCS / END_TF_DOCS block in
# docs/reference/terraform.md from the HCL in terraform/.
docs:
	terraform-docs --config .terraform-docs.yml terraform

# Non-mutating: fails if docs/reference/terraform.md is out of sync.
# Run by CI to enforce that committed terraform-docs output matches
# what the current HCL would produce.
docs-diff:
	terraform-docs --config .terraform-docs.yml --output-check terraform

ci:
	$(MAKE) fmt-check
	$(MAKE) init
	$(MAKE) validate
	$(MAKE) test
	$(MAKE) opa-test
	$(MAKE) docs-diff
