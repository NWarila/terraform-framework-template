#!/usr/bin/env bats

setup() {
  repo_root="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  script="${repo_root}/tools/ci/detect_release_evidence_type.sh"
  tmp_root="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
}

touch_file() {
  mkdir -p "$(dirname "$1")"
  : > "$1"
}

make_template_repo() {
  touch_file "$1/contract/runner-template-contract.yaml"
  touch_file "$1/tools/check_template_contract.py"
  touch_file "$1/.github/workflows/reusable-terraform-validation.yaml"
}

@test "detects framework repositories" {
  repo="${tmp_root}/framework"
  touch_file "${repo}/terraform/versions.tf"

  run bash "${script}" "${repo}"

  [ "$status" -eq 0 ]
  [ "$output" = "framework" ]
}

@test "detects runner repositories" {
  repo="${tmp_root}/runner"
  mkdir -p "${repo}/repos/public"

  run bash "${script}" "${repo}"

  [ "$status" -eq 0 ]
  [ "$output" = "runner" ]
}

@test "detects runner-template repositories before generic runner shape" {
  repo="${tmp_root}/template"
  make_template_repo "${repo}"
  mkdir -p "${repo}/repos/public"

  run bash "${script}" "${repo}"

  [ "$status" -eq 0 ]
  [ "$output" = "template" ]
}

@test "rejects framework plus runner ambiguity" {
  repo="${tmp_root}/ambiguous"
  touch_file "${repo}/terraform/versions.tf"
  mkdir -p "${repo}/repos/public"

  run bash "${script}" "${repo}"

  [ "$status" -ne 0 ]
  [[ "$output" == *"ambiguous release-evidence repo type"* ]]
}

@test "rejects unknown layouts" {
  repo="${tmp_root}/unknown"
  mkdir -p "${repo}"

  run bash "${script}" "${repo}"

  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot determine repo type"* ]]
}
