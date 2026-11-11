# Input variables, alphabetical (PC-IAC-002). Values live in the per-environment
# variable files, never as defaults here. Role inputs are names, never ARNs:
# the account identifier is read from the caller identity at plan time, so no
# account identifier is committed (PC-IAC-016).

variable "aws_region" {
  type        = string
  description = "AWS Region where this stack manages resources."
}

variable "break_glass_role_patterns" {
  type        = list(string)
  description = "Role path and name patterns after role/ of the break-glass roles, the only principals allowed to schedule deletion of the state key or disable it. Wildcards are allowed because Identity Center role names carry a generated suffix."
}

variable "common_tags" {
  type        = map(string)
  description = "Cross-cutting governance tags applied to every resource through provider default_tags. Must include Client, Project, Environment, Owner and CostCenter."

  validation {
    condition     = alltrue([for key in ["Client", "Project", "Environment", "Owner", "CostCenter"] : contains(keys(var.common_tags), key)])
    error_message = "common_tags must include the keys Client, Project, Environment, Owner and CostCenter."
  }
}

variable "configuration_reader_role_names" {
  type        = set(string)
  description = "Names of the IAM roles that may inspect the state key configuration for plan and review, without changing its policy or decrypting state. They must differ from the key administrators."
}

variable "domain_access" {
  type = map(object({
    plan_role_names  = set(string)
    write_role_names = optional(set(string), [])
  }))
  description = "Per-domain IAM role names. Plan roles read state and write locks only; write roles are the apply roles of the domain. B06 owns the actual identities; the examples carry placeholder names."

  validation {
    condition     = toset(keys(var.domain_access)) == toset(["network", "security", "workload", "state-backend"])
    error_message = "domain_access must cover exactly the four approved state domains: network, security, workload and state-backend."
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

variable "key_administrator_role_names" {
  type        = set(string)
  description = "Names of the IAM roles approved to administer the state key. An apply role may administer the key; no plan role may."
}
