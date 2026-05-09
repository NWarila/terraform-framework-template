terraform {

  # Specify the required Terraform version. Per template-tier ADR-0001
  # (pin Terraform and provider versions exactly), exact pins only —
  # the `~>` pessimistic operator is rejected by the OPA policy in
  # policies/opa/golden_terraform.rego.
  required_version = "= 1.15.1"

  # Specify the required providers. All four are official HashiCorp
  # providers selected for the do-nothing showcase: each demonstrates a
  # distinct framework pattern (state-only resources, deterministic data
  # generation, real artifact production, time-based lifecycle) without
  # touching any external service or accruing cost.
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "= 3.2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.7.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "= 2.5.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.13.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 4.1.0"
    }
  }

}
