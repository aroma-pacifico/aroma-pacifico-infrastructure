# Input variables, alphabetical (PC-IAC-002). Values live in the per-environment
# variable files, never as defaults here.

variable "aws_region" {
  type        = string
  description = "AWS Region where this stack manages resources."

  validation {
    condition     = var.aws_region == "us-east-1" && var.aws_region == var.hub.region
    error_message = "The workload and hub providers must use the approved primary Region, us-east-1 (ADR-001)."
  }
}

variable "collection_center" {
  description = "One A11 center key; optional department and CIDR assertions must match the approved catalog."
  type = object({
    key        = string
    department = optional(string)
    cidr_block = optional(string)
  })
  nullable = false

  validation {
    condition     = contains(keys(local.collection_centers), var.collection_center.key)
    error_message = "Select exactly one center: cauca, huila, or tolima."
  }

  validation {
    condition     = var.collection_center.department == null ? true : try(var.collection_center.department == local.collection_centers[var.collection_center.key].department, false)
    error_message = "The asserted department must match the selected center."
  }

  validation {
    condition     = var.collection_center.cidr_block == null ? true : try(var.collection_center.cidr_block == local.collection_centers[var.collection_center.key].cidr_block, false)
    error_message = "The asserted CIDR must exactly match the selected department's approved /16."
  }
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
  description = "Permanent center-link target; only pdn is permitted by ASM-121 and CL-LNK-01 to 05."
  type        = string
  nullable    = false

  validation {
    condition     = var.environment == "pdn"
    error_message = "Permanent center associations target pdn only; dev is isolated and temporary qa acceptance wiring is outside this contract."
  }
}

variable "hub" {
  description = "Externally owned shared Transit Gateway account, Region and ACM certificate reference (public references only; never a key or PSK)."
  type = object({
    account_id               = string
    region                   = string
    transit_gateway_id       = string
    customer_certificate_arn = string
  })
  nullable = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.hub.account_id)) && can(regex("^tgw-[0-9a-f]{8,17}$", var.hub.transit_gateway_id))
    error_message = "hub needs a 12-digit owner account and a Transit Gateway reference."
  }
}

variable "network" {
  description = "B04 outputs for the VPC that attaches to the hub, plus the explicit environment and owner account."
  type = object({
    environment                   = string
    account_id                    = string
    vpc_id                        = string
    vpc_cidr_block                = string
    transit_attachment_subnet_ids = list(string)
  })
  nullable = false

  validation {
    condition     = var.network.environment == var.environment && can(regex("^[0-9]{12}$", var.network.account_id))
    error_message = "network must describe the selected environment and an explicit 12-digit owner account."
  }
}

variable "network_plan_role_arn" {
  description = "Externally supplied plan role in the hub (network) account; never credentials."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:iam::${var.hub.account_id}:role/[A-Za-z0-9+=,.@_/-]+$", var.network_plan_role_arn))
    error_message = "An explicit plan role in the hub owner account is required."
  }
}

variable "workload_plan_role_arn" {
  description = "Externally supplied plan role in the workload (VPC owner) account; never credentials."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:iam::${var.network.account_id}:role/[A-Za-z0-9+=,.@_/-]+$", var.workload_plan_role_arn))
    error_message = "An explicit plan role in the VPC owner account is required."
  }
}
