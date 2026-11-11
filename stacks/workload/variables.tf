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

variable "telemetry_references" {
  type = object({
    table_arn      = string
    topic_rule_arn = string
  })
  description = "Telemetry table read by the threshold function and topic rule allowed to send to its queue. These are the telemetry_table_arn and topic_rule_arn outputs of modules/telemetry-ingestion; B09b replaces this variable with them (see README)."
}
