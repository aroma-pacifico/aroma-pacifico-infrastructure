# Input variables, alphabetical (PC-IAC-002). Values live in the per-environment
# variable files, never as defaults here.

variable "aws_region" {
  type        = string
  description = "AWS Region where this stack manages resources."
}

variable "common_tags" {
  type        = map(string)
  description = "Cross-cutting governance tags applied to every resource through provider default_tags. Must include Client, Project, Environment, Owner and CostCenter."

  validation {
    condition     = alltrue([for key in ["Client", "Project", "Environment", "Owner", "CostCenter"] : contains(keys(var.common_tags), key)])
    error_message = "common_tags must include the keys Client, Project, Environment, Owner and CostCenter."
  }
}

variable "environment" {
  type        = string
  description = "Environment code: dev, qa or pdn."

  validation {
    condition     = contains(["dev", "qa", "pdn"], var.environment)
    error_message = "environment must be one of dev, qa or pdn."
  }
}

# Inference function inputs (B10b), alphabetical among themselves. They follow
# the governance variables shared by every stack. Cross-stack values arrive here
# as variables (ASM-420), so the plan needs no remote state.

variable "inference_function_packages" {
  type = map(object({
    filename         = string
    source_code_hash = optional(string)
  }))
  description = "Deployment package of each inference function, keyed by function key (confrm, verify, estim, thresh): a path relative to this stack and an optional SHA-256 digest. The examples point to placeholders until the release pipeline of ASM-171 publishes the real packages (ASM-421)."

  validation {
    condition     = toset(keys(var.inference_function_packages)) == toset(["confrm", "verify", "estim", "thresh"])
    error_message = "inference_function_packages needs exactly the keys confrm, verify, estim and thresh."
  }
}

variable "inference_model_id" {
  type        = string
  description = "Foundation model identifier that every inference function invokes on demand (ASM-160, ASM-179): Amazon Nova Pro in us-east-1. Never an inference profile."
}

variable "inference_targets" {
  type = object({
    alert_table_arn              = string
    alert_topic_arn              = string
    drone_event_rule_arn_pattern = string
    drone_object_arn_pattern     = string
    mission_table_arn            = string
    thresholds_table_arn         = string
  })
  description = "ARNs that the inference functions read, write or accept events from, owned by data and drone resources that no stack creates yet (ASM-420): the alert table and topic of the threshold function, the drone service rule pattern that sends to the drone queues, the drone object pattern, the mission table and the threshold table."
}

variable "kms_key_arns" {
  type        = map(string)
  description = "Customer-managed key ARNs keyed by data class, the kms_key_arns output of stacks/security (B06b). The functions use the telemetry, objects, records and logs classes."

  validation {
    condition     = alltrue([for class in ["telemetry", "objects", "records", "logs"] : can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", lookup(var.kms_key_arns, class, "")))])
    error_message = "kms_key_arns must contain the telemetry, objects, records and logs classes as KMS key ARNs."
  }
}

variable "permissions_boundary_arn" {
  type        = string
  description = "Permissions boundary attached to every inference function role, when stacks/security (B06b) provides one. Null attaches none."
  default     = null
}

# Telemetry ingestion inputs (B09b), alphabetical among themselves. The roles are
# outputs of stacks/security and reach this stack as variables (ASM-420). The
# design fixes neither the topic scheme nor the TLS policy name (PD-100), so
# they have no default; the examples hold synthetic fixtures.

variable "iot_logging_role_arn" {
  type        = string
  description = "Role that AWS IoT Core assumes to write its logs, the iot_logging_role_arn output of stacks/security (B06b)."

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.iot_logging_role_arn))
    error_message = "iot_logging_role_arn must be an IAM role ARN."
  }
}

variable "iot_rule_role_arn" {
  type        = string
  description = "Role that the telemetry topic rule assumes, the iot_rule_role_arn output of stacks/security (B06b)."

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.iot_rule_role_arn))
    error_message = "iot_rule_role_arn must be an IAM role ARN."
  }
}

variable "telemetry_tls_security_policy" {
  type        = string
  description = "Predefined AWS IoT Core security policy of the data endpoint, with a minimum of TLS 1.2 (CL-TEL-01, PD-100). The design names IoTSecurityPolicy_TLS13_1_2_2022_10 only as an example, so the choice is an input."
}

variable "telemetry_topic_namespace" {
  type        = string
  description = "Topic levels above the thing name: a node publishes only to <namespace>/<thing name>. One to six levels of letters, digits, underscores and hyphens. The design does not fix the scheme, so the choice is an input."
}

# Farm inputs (B08b), alphabetical among themselves.

variable "farms" {
  type = map(object({
    farm_id        = string
    node_csr_paths = map(string)
  }))
  description = "Enrolled farms keyed by a short key of 1 to 4 lowercase alphanumeric characters (it ends up in the node names). Each farm has its opaque platform identifier and the paths, relative to this stack, of the public CSRs of its crop and drying nodes. The examples hold one synthetic farm (ASM-422)."

  validation {
    condition     = alltrue([for key in keys(var.farms) : can(regex("^[a-z0-9]{1,4}$", key))])
    error_message = "Each farm key must be 1 to 4 lowercase alphanumeric characters, so that the farm name prefix stays within 21 characters."
  }

  validation {
    condition     = alltrue([for farm in values(var.farms) : toset(keys(farm.node_csr_paths)) == toset(["crop", "drying"])])
    error_message = "Each farm needs exactly the crop and drying node CSR paths."
  }
}
