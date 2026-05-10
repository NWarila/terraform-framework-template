PYTHON ?= python3
TFLINT ?= tflint
INTEGRATION_CASE ?= basic

.PHONY: fmt fmt-check init validate tflint ruff yamllint test opa-test opa-policy manifest-check docs docs-diff docs-layout lint policy docs-check integration ci verify

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

tflint:
	$(TFLINT) --init --config "$(CURDIR)/.tflint.hcl"
	$(TFLINT) --config "$(CURDIR)/.tflint.hcl" --chdir terraform

ruff:
	$(PYTHON) -m pip install --no-cache-dir ruff==0.13.0
	$(PYTHON) -m ruff check tools/

yamllint:
	$(PYTHON) -m pip install --no-cache-dir yamllint==1.35.1
	$(PYTHON) -m yamllint -d "{ extends: relaxed, rules: { line-length: disable, document-start: disable, comments: disable, truthy: {check-keys: false} } }" .github/workflows/

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

# OPA policy enforcement. Evaluates the policy against this repo's
# actual workflows and Terraform version pins.
opa-policy:
	$(PYTHON) tools/build_opa_input.py | opa eval --fail-defined --format pretty --stdin-input --data policies/opa "data.golden_terraform.deny[_]"

# Validates baseline-manifest.json against drift-gate's stdlib
# schema. Derivative frameworks use this manifest to mirror the
# template-tier scaffold byte-for-byte.
manifest-check:
	$(PYTHON) -m pip install --no-cache-dir 'git+https://github.com/NWarila/drift-gate@d835ae411f1e55e25b2b6c079d5891e7345a043c'
	$(PYTHON) -c "from pathlib import Path; from baseline.manifest import load_manifest; m = load_manifest(Path('baseline-manifest.json')); print(f'manifest: version={m.version}, files={len(m.files)}'); missing = [f.source for f in m.files if not Path(f.source).is_file()]; assert not missing, f'sources missing: {missing}'; print('all sources resolve on disk')"

# Mutating: regenerates the BEGIN_TF_DOCS / END_TF_DOCS block in
# docs/reference/terraform.md from the HCL in terraform/.
docs:
	terraform-docs --config .terraform-docs.yml terraform

# Non-mutating: fails if docs/reference/terraform.md is out of sync.
# Run by CI to enforce that committed terraform-docs output matches
# what the current HCL would produce.
docs-diff:
	terraform-docs --config .terraform-docs.yml --output-check terraform

docs-layout:
	$(PYTHON) tools/check_docs_layout.py

lint:
	$(MAKE) fmt-check
	$(MAKE) init
	$(MAKE) validate
	$(MAKE) tflint
	$(MAKE) ruff
	$(MAKE) yamllint

policy:
	$(MAKE) opa-test
	$(MAKE) opa-policy

docs-check:
	$(MAKE) docs-diff
	$(MAKE) docs-layout

integration:
	$(PYTHON) tools/ci/run_integration.py --case $(INTEGRATION_CASE)

ci:
	$(MAKE) lint
	$(MAKE) test
	$(MAKE) policy
	$(MAKE) docs-check
	$(MAKE) manifest-check

verify:
	$(MAKE) ci
	$(MAKE) integration
