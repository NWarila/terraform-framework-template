package synthetic_framework_plan_test

import data.synthetic_framework_plan
import rego.v1

valid_resources := {
	"resources": [
		{
			"address": "random_pet.environment[\"demo-alpha\"]",
			"type": "random_pet",
			"values": {"keepers": {"framework_source": "NWarila/terraform-framework-template"}},
		},
		{
			"address": "random_string.environment_secret[\"demo-alpha\"]",
			"type": "random_string",
			"values": {
				"keepers": {"framework_source": "NWarila/terraform-framework-template"},
				"length": 16,
			},
		},
		{
			"address": "time_static.environment_created[\"demo-alpha\"]",
			"type": "time_static",
			"values": {"triggers": {"framework_source": "NWarila/terraform-framework-template"}},
		},
		{
			"address": "time_rotating.environment_rotation[\"demo-beta\"]",
			"type": "time_rotating",
			"values": {"triggers": {"framework_source": "NWarila/terraform-framework-template"}},
		},
		{
			"address": "null_resource.lifecycle_hook[\"demo-beta__pre\"]",
			"type": "null_resource",
			"values": {"triggers": {"framework_source": "NWarila/terraform-framework-template"}},
		},
		{
			"address": "local_file.manifest[\"demo-alpha__config\"]",
			"type": "local_file",
			"values": {"file_permission": "0644"},
		},
		{
			"address": "tls_private_key.environment[\"demo-gamma\"]",
			"type": "tls_private_key",
			"values": {"algorithm": "ECDSA"},
		},
		{
			"address": "tls_self_signed_cert.environment[\"demo-gamma\"]",
			"type": "tls_self_signed_cert",
			"values": {"validity_period_hours": 8760},
		},
	],
}

test_valid_framework_plan_allowed if {
	count(synthetic_framework_plan.deny) == 0 with input as valid_resources
}

test_certificate_validity_over_one_year_denied if {
	denials := synthetic_framework_plan.deny with input as {
		"resources": [{
			"address": "tls_self_signed_cert.environment[\"bad\"]",
			"type": "tls_self_signed_cert",
			"values": {"validity_period_hours": 8761},
		}],
	}
	count(denials) >= 1
}

test_tls_private_key_algorithm_denied if {
	denials := synthetic_framework_plan.deny with input as {
		"resources": [{
			"address": "tls_private_key.environment[\"bad\"]",
			"type": "tls_private_key",
			"values": {"algorithm": "RSA"},
		}],
	}
	count(denials) >= 1
}

test_local_file_world_writable_denied if {
	denials := synthetic_framework_plan.deny with input as {
		"resources": [{
			"address": "local_file.manifest[\"bad\"]",
			"type": "local_file",
			"values": {"file_permission": "0666"},
		}],
	}
	count(denials) >= 1
}

test_random_string_too_short_denied if {
	denials := synthetic_framework_plan.deny with input as {
		"resources": [{
			"address": "random_string.environment_secret[\"bad\"]",
			"type": "random_string",
			"values": {
				"keepers": {"framework_source": "NWarila/terraform-framework-template"},
				"length": 15,
			},
		}],
	}
	count(denials) >= 1
}

test_metadata_resource_missing_framework_source_denied if {
	denials := synthetic_framework_plan.deny with input as {
		"resources": [{
			"address": "null_resource.lifecycle_hook[\"bad\"]",
			"type": "null_resource",
			"values": {"triggers": {"hook": "pre"}},
		}],
	}
	count(denials) >= 1
}
