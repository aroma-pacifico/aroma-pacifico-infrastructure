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

variable "environment" {
  description = "Permanent center-link target; only pdn is permitted by ASM-121 and CL-LNK-01 to 05."
  type        = string
  nullable    = false

  validation {
    condition     = var.environment == "pdn"
    error_message = "Permanent center associations target pdn only; dev is isolated and temporary qa acceptance wiring is outside this contract."
  }
}
