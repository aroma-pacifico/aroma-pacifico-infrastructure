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

# Firewall rules inputs (B07b), alphabetical among themselves. The network
# identifiers mirror outputs of stacks/network and arrive as variables, never
# through terraform_remote_state (PC-IAC-019). Values live in the per-environment
# variable files; none has a default.

variable "application_subnet_cidr_blocks" {
  type        = map(string)
  description = "CIDR blocks of the application tier subnets keyed by Availability Zone slot (az1 to az3). Mirrors subnet_cidr_blocks[\"application\"] of stacks/network. They are the only sources of the data store security group (CL-DAT-02)."

  validation {
    condition     = length(var.application_subnet_cidr_blocks) > 0 && alltrue([for cidr_block in values(var.application_subnet_cidr_blocks) : can(cidrhost(cidr_block, 0)) && can(regex("/(1[6-9]|2[0-9]|3[0-2])$", cidr_block))])
    error_message = "Provide valid subnet CIDR blocks with a prefix of at least /16; the whole internet is never an admitted source."
  }
}

# Same name, type and value as the network stack: the centers are one set for the
# environment and both stacks read the same variable file. Every other zone
# address of a center derives from its block (see firewall_rules.tf).
variable "collection_centers" {
  type = map(object({
    cidr_block                = string
    firewall_cidr_block       = string
    ground_station_cidr_block = string
  }))
  description = "Collection centers keyed by name, as in stacks/network: the reserved /16 of the center, and the firewall and ground station /32 hosts inside it. The staff, logistics, device management and guest blocks derive from the /16 (A11 section 3.1)."

  validation {
    condition     = length(var.collection_centers) > 0 && alltrue([for center in values(var.collection_centers) : can(regex("^10\\.4[0-7]\\.0\\.0/16$", center.cidr_block)) && can(regex("/32$", center.firewall_cidr_block)) && can(regex("/32$", center.ground_station_cidr_block))])
    error_message = "Each center needs a /16 block inside 10.40.0.0/13, and /32 hosts for the firewall and the ground station."
  }
}

# Same name and value as the network stack (CL-DAT-02).
variable "data_store_ports" {
  type        = list(number)
  description = "TCP ports of the data store that the application tier may reach (CL-DAT-02), as in stacks/network. The port is selected by the data design (A13); an empty list leaves the data store group without ingress."
}

variable "drone_object_bucket_name" {
  type        = string
  description = "Name of the drone object bucket whose writes the S3 interface endpoint policy admits (CL-DRN-02). Another stack creates the bucket; this stack builds its ARN, so no ARN is stored."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.drone_object_bucket_name))
    error_message = "Provide a bucket name, not an ARN."
  }
}

variable "interface_endpoint_ids" {
  type        = map(string)
  description = "Interface endpoint IDs keyed by the short name of interface_endpoints. Mirrors the interface_endpoint_ids output of stacks/network. The keys exapi (execute-api, CL-APP-02) and s3 (object_storage tier, CL-DRN-02) must be present."

  validation {
    condition     = alltrue([for key in ["exapi", "s3"] : contains(keys(var.interface_endpoint_ids), key)]) && alltrue([for id in values(var.interface_endpoint_ids) : can(regex("^vpce-[0-9a-f]{8,17}$", id))])
    error_message = "interface_endpoint_ids must include exapi and s3, and every value must look like vpce-0123456789abcdef0."
  }
}

variable "platform_api_ids" {
  type        = list(string)
  description = "IDs of the platform's private REST APIs that the execute-api endpoint policy admits (CL-APP-02). This stack builds their ARNs in the caller account and Region, so no account is stored."

  validation {
    condition     = length(var.platform_api_ids) > 0 && alltrue([for id in var.platform_api_ids : can(regex("^[a-z0-9]{10}$", id))])
    error_message = "Provide at least one REST API ID of 10 lowercase letters and digits."
  }
}

variable "vpc_id" {
  type        = string
  description = "ID of the environment VPC. Mirrors the vpc_id output of stacks/network."

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must look like vpc-0123456789abcdef0."
  }
}
