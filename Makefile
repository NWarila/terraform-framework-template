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

ci:
	$(MAKE) fmt-check
	$(MAKE) init
	$(MAKE) validate
	$(MAKE) test
	$(MAKE) opa-test
