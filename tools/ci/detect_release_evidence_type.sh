#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-.}"

is_template=false
if [[ -f "${repo_root}/contract/runner-template-contract.yaml" ]] \
  && [[ -f "${repo_root}/tools/check_template_contract.py" ]] \
  && [[ -f "${repo_root}/.github/workflows/reusable-terraform-validation.yaml" ]]; then
  is_template=true
fi

has_framework=false
if [[ -f "${repo_root}/terraform/versions.tf" ]]; then
  has_framework=true
fi

has_runner=false
if [[ -d "${repo_root}/repos/public" ]] || [[ -d "${repo_root}/repos/private" ]]; then
  has_runner=true
fi

if [[ "${is_template}" == true && "${has_framework}" == true ]]; then
  echo "::error::ambiguous release-evidence repo type: template and framework signals are both present" >&2
  exit 1
fi
if [[ "${is_template}" == true ]]; then
  echo "template"
elif [[ "${has_framework}" == true && "${has_runner}" == true ]]; then
  echo "::error::ambiguous release-evidence repo type: framework and runner signals are both present" >&2
  exit 1
elif [[ "${has_framework}" == true ]]; then
  echo "framework"
elif [[ "${has_runner}" == true ]]; then
  echo "runner"
else
  echo "::error::cannot determine repo type (no template tooling, terraform/versions.tf, or repos/*)" >&2
  exit 1
fi
