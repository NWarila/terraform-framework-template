locals {

  #region ------ [ Data-Source-Derived Lookup Tables ] ----------------------------------- #

  # Parsed tier-defaults JSON. In a real framework this would be
  # data.<provider>_<resource>.<name>... — here it's a local fixture
  # demonstrating the same injection pattern (see data.tf).
  tier_defaults = jsondecode(data.local_file.tier_defaults.content)["tiers"]

  # Common decorations applied to every synthetic resource. The
  # global_tag + environment_prefix pair lets tests deterministically
  # verify which apply produced a given resource.
  framework_decorations = {
    environment_prefix = var.environment_prefix
    global_tag         = var.global_tag
    framework_source   = "NWarila/terraform-framework-template"
  }

  #endregion --- [ Data-Source-Derived Lookup Tables ] ----------------------------------- #

  #region ------ [ Environment Expansion (var.all_environments → keyed map) ] ------------ #

  # The expansion comprehension. Pure mechanical merge: per-environment
  # values from var.all_environments override tier defaults from the
  # JSON fixture; the result is a single map keyed by environment name
  # that resources.tf consumes via for_each. resources.tf does no
  # computation — every value it references is finalized HERE.
  synthetic_environments = {
    for env in var.all_environments : env.name => {

      /* Required Parameters */
      name  = env.name
      owner = env.owner
      tier  = env.tier

      /* Optional Parameters */
      enabled = env.enabled
      # retention_days defaults via tier lookup if the consumer omitted it.
      # try() preserves the consumer's explicit override (including 0) — only
      # null falls through to the tier default.
      retention_days = coalesce(
        env.retention_days,
        local.tier_defaults[env.tier]["retention_days"]
      )
      description = env.description
      tags        = env.tags

      /* Decorative resources (one each per environment) */
      pet = {
        length    = coalesce(try(env.pet.length, null), local.tier_defaults[env.tier]["default_pet_length"])
        separator = try(env.pet.separator, "-")
        prefix    = try(env.pet.prefix, null)
      }

      random_string_length = local.tier_defaults[env.tier]["default_random_string_length"]

      /* Iterative resources */
      manifests       = env.manifests
      lifecycle_hooks = env.lifecycle_hooks

      /* Single-optional resources (splat-on-optional in resources.tf) */
      rotation = env.rotation == null ? null : {
        rotation_days = coalesce(
          env.rotation.rotation_days,
          local.tier_defaults[env.tier]["default_rotation_days"]
        )
        rotation_hours = env.rotation.rotation_hours
        # triggers injected here so resources.tf stays a dumb pass-through —
        # rotation block in resources.tf doesn't compute anything itself.
        triggers = merge(
          local.framework_decorations,
          { environment = env.name, tier = env.tier },
          { for t in env.tags : t => "true" }
        )
      }

      # certificate expands so resources.tf stays a dumb pass-through. The
      # subject sub-block is left as-is when present (resources.tf uses the
      # splat-on-optional dynamic pattern on each.value["certificate"]["subject"]).
      certificate = env.certificate == null ? null : {
        validity_period_hours = env.certificate.validity_period_hours
        early_renewal_hours   = env.certificate.early_renewal_hours
        is_ca_certificate     = env.certificate.is_ca_certificate
        set_subject_key_id    = env.certificate.set_subject_key_id
        allowed_uses          = env.certificate.allowed_uses
        subject               = env.certificate.subject
      }

      /* Common decorations injected per-environment */
      common_triggers = merge(
        local.framework_decorations,
        {
          environment = env.name
          owner       = env.owner
          tier        = env.tier
        }
      )
    }
  }

  #endregion --- [ Environment Expansion (var.all_environments → keyed map) ] ------------ #

  #region ------ [ Flattened Iterative Children (manifests, lifecycle_hooks) ] ----------- #

  # Terraform's `for_each` works on maps/sets, not nested lists. To
  # produce one local_file per (environment × manifest) pair, the nested
  # lists are flattened into composite-keyed maps HERE — resources.tf
  # then iterates those flat maps without doing any flattening itself.
  manifests_flat = {
    for pair in flatten([
      for env_key, env in local.synthetic_environments : [
        for idx, manifest in coalesce(env.manifests, []) : {
          composite_key    = "${env_key}__${manifest.filename}"
          environment      = env_key
          manifest_idx     = idx
          filename         = manifest.filename
          content          = manifest.content
          permissions      = manifest.permissions
          directory_create = manifest.directory_create
        }
      ]
    ]) : pair.composite_key => pair
  }

  lifecycle_hooks_flat = {
    for pair in flatten([
      for env_key, env in local.synthetic_environments : [
        for idx, hook in coalesce(env.lifecycle_hooks, []) : {
          composite_key = "${env_key}__${hook.name}"
          environment   = env_key
          hook_idx      = idx
          name          = hook.name
          triggers = merge(
            env.common_triggers,
            { hook = hook.name },
            hook.triggers
          )
        }
      ]
    ]) : pair.composite_key => pair
  }

  #endregion --- [ Flattened Iterative Children (manifests, lifecycle_hooks) ] ----------- #

}
