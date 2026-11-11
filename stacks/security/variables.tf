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

# Security inputs (B06b), alphabetical among themselves. They follow the
# governance variables shared by every stack.

# Same name and value as the state-backend stack: the break-glass roles are one
# set for the environment, and both stacks read the same variable file.
variable "break_glass_role_patterns" {
  type        = list(string)
  description = "IAM role paths and name patterns of the break-glass roles, appended to the arn:aws:iam::<account>:role/ prefix. Wildcards are allowed because Identity Center role names carry a generated suffix."

  validation {
    condition     = length(var.break_glass_role_patterns) > 0 && alltrue([for pattern in var.break_glass_role_patterns : pattern != "*" && !startswith(pattern, "arn:")])
    error_message = "Provide at least one break-glass pattern that is not a bare wildcard and does not repeat the ARN prefix."
  }
}

variable "field_sms_configuration" {
  type = object({
    sns_caller_arn = string
    external_id    = string
  })
  description = "SNS role and external ID that let the field user pool send one-time codes by SMS (ASM-272). Null leaves email codes only. The external ID is a secret: supply it as TF_VAR_field_sms_configuration from the environment, never from a file."
  default     = null
  sensitive   = true
}

variable "key_user_role_names" {
  type        = map(list(string))
  description = "Names of the roles allowed to use each key, keyed by data class (telemetry, objects, records, personal, logs, state, public_view, restricted). The roles are created by other stacks and named by convention, so only names are listed here. Keep restricted empty (ASM-165)."
  default     = {}

  validation {
    condition     = alltrue([for names in values(var.key_user_role_names) : alltrue([for name in names : can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", name))])])
    error_message = "Every key user must be a role name of at most 64 characters, without a path or a wildcard."
  }
}

variable "protected_bucket_names" {
  type        = list(string)
  description = "Names of the S3 buckets that must refuse plain HTTP and TLS older than 1.2. The stack renders the policy statements as an output; the bucket owner attaches them. Empty renders nothing."
  default     = []

  validation {
    condition     = alltrue([for name in var.protected_bucket_names : can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", name))])
    error_message = "Every protected bucket must be a bucket name, not an ARN."
  }
}

variable "security_apply_role_names" {
  type        = list(string)
  description = "Names of the roles that apply this stack. They administer every key but get no use of the key material (ASM-270), so the list must include the apply role of the security domain."

  validation {
    condition     = length(var.security_apply_role_names) > 0 && alltrue([for name in var.security_apply_role_names : can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", name))])
    error_message = "Provide at least one role name of at most 64 characters, without a path or a wildcard."
  }
}
