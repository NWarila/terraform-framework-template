# terraform test — exercises the framework end-to-end with real
# apply against the synthetic providers. Generates real tfstate inside
# the sandbox, asserts on outputs, then tears down. No external
# services involved.

# region ------ [ Run 1: single environment, minimum required inputs ] -------------------- #

run "single_environment_minimum" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-single-env-min"

    all_environments = [
      {
        name  = "minimal"
        owner = "test-suite"
        tier  = "dev"
      }
    ]
  }

  # The framework always produces these per environment.
  assert {
    condition     = output.framework_summary.environments_total == 1
    error_message = "Expected exactly 1 environment in framework_summary; got ${output.framework_summary.environments_total}."
  }

  assert {
    condition     = output.framework_summary.environments_with_cert == 0
    error_message = "Expected 0 environments with cert when no certificate input was provided; got ${output.framework_summary.environments_with_cert}."
  }

  assert {
    condition     = output.framework_summary.environments_rotating == 0
    error_message = "Expected 0 environments with rotation when no rotation input was provided; got ${output.framework_summary.environments_rotating}."
  }

  assert {
    condition     = output.framework_summary.manifests_total == 0
    error_message = "Expected 0 manifests when none were declared; got ${output.framework_summary.manifests_total}."
  }

  assert {
    condition     = output.framework_summary.lifecycle_hooks_total == 0
    error_message = "Expected 0 lifecycle hooks when none were declared; got ${output.framework_summary.lifecycle_hooks_total}."
  }

  # Tier defaults injected from the JSON fixture (data-source-injection
  # pattern). The "dev" tier sets retention_days=7 in fixtures/tier_defaults.json.
  assert {
    condition     = output.environments["minimal"].retention_days == 7
    error_message = "Expected retention_days=7 (dev tier default from data fixture); got ${output.environments["minimal"].retention_days}."
  }

  # Pet name is generated and non-empty.
  assert {
    condition     = length(output.environments["minimal"].pet_name) > 0
    error_message = "Expected non-empty pet_name; got empty string."
  }

  # Created-at timestamp is a non-empty RFC3339 string.
  assert {
    condition     = length(output.environments["minimal"].created_at) > 0
    error_message = "Expected non-empty created_at; got empty string."
  }
}

# endregion --- [ Run 1: single environment, minimum required inputs ] -------------------- #

# region ------ [ Run 2: multi-environment with manifests + hooks ] ----------------------- #

run "multi_environment_with_iterative_children" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-multi-env-iter"

    all_environments = [
      {
        name  = "alpha"
        owner = "team-a"
        tier  = "dev"
        manifests = [
          { filename = "alpha-manifest-1.yaml", content = "alpha-content-1" },
          { filename = "alpha-manifest-2.yaml", content = "alpha-content-2" },
        ]
        lifecycle_hooks = [
          { name = "alpha-pre-deploy" },
        ]
      },
      {
        name  = "beta"
        owner = "team-b"
        tier  = "staging"
        manifests = [
          { filename = "beta-config.yaml", content = "beta-content" },
        ]
        lifecycle_hooks = [
          { name = "beta-pre-deploy" },
          { name = "beta-post-deploy", triggers = { phase = "post" } },
        ]
      },
    ]
  }

  assert {
    condition     = output.framework_summary.environments_total == 2
    error_message = "Expected 2 environments; got ${output.framework_summary.environments_total}."
  }

  # Iterative-children expansion: manifests across 2 envs = 2 + 1 = 3.
  assert {
    condition     = output.framework_summary.manifests_total == 3
    error_message = "Expected 3 manifests across both environments (2 alpha + 1 beta); got ${output.framework_summary.manifests_total}."
  }

  # Hooks: 1 alpha + 2 beta = 3.
  assert {
    condition     = output.framework_summary.lifecycle_hooks_total == 3
    error_message = "Expected 3 lifecycle hooks; got ${output.framework_summary.lifecycle_hooks_total}."
  }

  # Tier defaults differ per env: dev=7, staging=30.
  assert {
    condition     = output.environments["alpha"].retention_days == 7
    error_message = "Expected alpha (dev) retention_days=7; got ${output.environments["alpha"].retention_days}."
  }

  assert {
    condition     = output.environments["beta"].retention_days == 30
    error_message = "Expected beta (staging) retention_days=30; got ${output.environments["beta"].retention_days}."
  }
}

# endregion --- [ Run 2: multi-environment with manifests + hooks ] ----------------------- #

# region ------ [ Run 3: certificate (single-optional dynamic block) ] -------------------- #

run "environment_with_certificate" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-cert"

    all_environments = [
      {
        name  = "secured"
        owner = "team-sec"
        tier  = "prod"
        certificate = {
          validity_period_hours = 168 # 7 days
          subject = {
            common_name  = "synthetic.example.invalid"
            organization = "Framework Example"
            country      = "US"
          }
        }
      }
    ]
  }

  assert {
    condition     = output.framework_summary.environments_with_cert == 1
    error_message = "Expected 1 environment with certificate; got ${output.framework_summary.environments_with_cert}."
  }

  assert {
    condition     = output.environments["secured"].certificate_enabled == true
    error_message = "Expected secured.certificate_enabled=true; got false."
  }

  # The cert is real: validity dates are populated in state.
  assert {
    condition     = length(tls_self_signed_cert.environment["secured"].cert_pem) > 0
    error_message = "Expected non-empty cert_pem; got empty."
  }
}

# endregion --- [ Run 3: certificate (single-optional dynamic block) ] -------------------- #

# region ------ [ Run 4: rotation (filtered for_each) ] ----------------------------------- #

run "environment_with_rotation" {

  command = apply

  variables {
    environment_prefix = "demo"
    global_tag         = "test-rotation"

    all_environments = [
      {
        name  = "rotating"
        owner = "team-ops"
        tier  = "prod"
        rotation = {
          rotation_days = 30
        }
      }
    ]
  }

  assert {
    condition     = output.framework_summary.environments_rotating == 1
    error_message = "Expected 1 environment with rotation; got ${output.framework_summary.environments_rotating}."
  }

  assert {
    condition     = output.environments["rotating"].rotation_enabled == true
    error_message = "Expected rotating.rotation_enabled=true; got false."
  }
}

# endregion --- [ Run 4: rotation (filtered for_each) ] ----------------------------------- #

# region ------ [ Run 5: validation rules reject bad input ] ------------------------------ #

run "tier_validation_rejects_unknown_tier" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      {
        name  = "bad-tier"
        owner = "test"
        tier  = "production" # invalid — must be dev/staging/prod
      }
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

run "name_validation_rejects_uppercase" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      {
        name  = "BadCase" # invalid — must be lowercase
        owner = "test"
        tier  = "dev"
      }
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

run "duplicate_names_rejected" {

  command = plan

  variables {
    environment_prefix = "demo"
    global_tag         = "test-validation"

    all_environments = [
      { name = "duplicate", owner = "team-a", tier = "dev" },
      { name = "duplicate", owner = "team-b", tier = "staging" },
    ]
  }

  expect_failures = [
    var.all_environments,
  ]
}

# endregion --- [ Run 5: validation rules reject bad input ] ------------------------------ #
