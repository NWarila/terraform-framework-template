# framework_plan - Terraform plan-aware policy for the reference framework.
#
# This package consumes normalized `terraform show -json tfplan` output from
# tools/build_plan_input.py. repo_hygiene checks source/workflow posture;
# framework_plan checks planned Terraform resources.

package framework_plan

import rego.v1

framework_source := "NWarila/terraform-framework-template"

metadata_required_types := {
	"null_resource",
	"random_pet",
	"random_string",
	"time_rotating",
	"time_static",
}

metadata_fields := {"keepers", "tags", "triggers"}

safe_file_permission(permission) if {
	regex.match(`^0?([0-5][0-7][0-7]|6[0-3][0-7]|64[0-4])$`, permission)
}

has_framework_source(resource) if {
	field := metadata_fields[_]
	metadata := object.get(resource.values, field, {})
	object.get(metadata, "framework_source", "") == framework_source
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "tls_self_signed_cert"
	validity := object.get(resource.values, "validity_period_hours", null)
	not is_number(validity)
	msg := sprintf("%s must set numeric validity_period_hours", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "tls_self_signed_cert"
	validity := object.get(resource.values, "validity_period_hours", null)
	is_number(validity)
	validity > 8760
	msg := sprintf("%s validity_period_hours must be <= 8760, got %v", [resource.address, validity])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "tls_private_key"
	algorithm := object.get(resource.values, "algorithm", "")
	algorithm != "ECDSA"
	msg := sprintf("%s algorithm must be ECDSA, got %q", [resource.address, algorithm])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "local_file"
	permission := object.get(resource.values, "file_permission", "")
	msg := sprintf("%s file_permission must be <= 0644, got %q", [resource.address, permission])
	not safe_file_permission(permission)
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "random_string"
	length := object.get(resource.values, "length", null)
	not is_number(length)
	msg := sprintf("%s length must be numeric", [resource.address])
}

deny contains msg if {
	resource := input.resources[_]
	resource.type == "random_string"
	length := object.get(resource.values, "length", null)
	is_number(length)
	length < 16
	msg := sprintf("%s length must be >= 16, got %v", [resource.address, length])
}

deny contains msg if {
	resource := input.resources[_]
	metadata_required_types[resource.type]
	not has_framework_source(resource)
	msg := sprintf("%s must carry framework_source in tags, triggers, or keepers", [resource.address])
}
