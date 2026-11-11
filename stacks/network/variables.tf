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

# Used only by its own validation until the stack is wired to modules.
# tflint-ignore: terraform_unused_declarations
variable "environment" {
  type        = string
  description = "Environment code: dev, qa or pdn."

  validation {
    condition     = contains(["dev", "qa", "pdn"], var.environment)
    error_message = "environment must be one of dev, qa or pdn."
  }
}

# Network inputs (B04b), alphabetical among themselves. They follow the
# governance variables shared by every stack.

variable "collection_center_summary_cidr_block" {
  type        = string
  description = "Single CIDR block that summarizes every present and future collection center, routed through the transit gateway (10.40.0.0/13 in the addressing plan)."

  validation {
    condition     = can(cidrhost(var.collection_center_summary_cidr_block, 0))
    error_message = "collection_center_summary_cidr_block must be a valid IPv4 CIDR block."
  }
}

variable "collection_centers" {
  type = map(object({
    cidr_block                = string
    firewall_cidr_block       = string
    ground_station_cidr_block = string
  }))
  description = "Collection centers keyed by name. The CIDR block is the reserved /16 of the center; the firewall and ground station are /32 hosts inside it. Must include the three blocks reserved by the case statement (10.41.0.0/16, 10.42.0.0/16 and 10.43.0.0/16)."

  validation {
    condition     = length(setsubtract(toset(local.reserved_center_cidr_blocks), toset([for center in values(var.collection_centers) : center.cidr_block]))) == 0
    error_message = "collection_centers must include the reserved blocks 10.41.0.0/16, 10.42.0.0/16 and 10.43.0.0/16."
  }
}

variable "data_store_ports" {
  type        = list(number)
  description = "TCP ports of the data store that the application tier may reach (CL-DAT-02). The port is selected by the data design (A13); an empty list leaves the data tier denying everything."
}

variable "flow_logs" {
  type = object({
    destination_arn = string
    iam_role_arn    = string
  })
  description = "CloudWatch Logs destination and IAM role of the flow log of rejected traffic, supplied by the security stack (B06b). Null disables flow logs."
  default     = null
}

variable "interface_endpoints" {
  type = map(object({
    service = string
    tier    = string
  }))
  description = "Interface endpoints keyed by a short name (at most 6 characters). Each names the service suffix and the tier that hosts it: application, object_storage or administration."
}

variable "organization_id" {
  type        = string
  description = "AWS Organizations ID admitted by the gateway endpoint policies. Not kept in any variable file: supply it as TF_VAR_organization_id from the environment."
}

variable "subnets" {
  type        = map(map(string))
  description = "Subnet CIDR blocks keyed by tier and Availability Zone slot (az1 to az3), from section 4.3 of the addressing plan."
}

variable "transit_gateway_id" {
  type        = string
  description = "Transit gateway of the network account. Null creates no route to the collection centers."
  default     = null
}

variable "vpc_cidr_block" {
  type        = string
  description = "Primary IPv4 CIDR block of the environment VPC. Distinct per environment and never overlapping the collection center blocks (case statement point 3)."

  validation {
    condition = can(cidrhost(var.vpc_cidr_block, 0)) && try(alltrue([
      for range in local.reserved_ranges :
      sum([for index, octet in split(".", cidrhost(var.vpc_cidr_block, 0)) : tonumber(octet) * pow(256, 3 - index)]) + pow(2, 32 - tonumber(split("/", var.vpc_cidr_block)[1])) - 1 < range.first
      || range.last < sum([for index, octet in split(".", cidrhost(var.vpc_cidr_block, 0)) : tonumber(octet) * pow(256, 3 - index)])
    ]), false)
    error_message = "vpc_cidr_block must not overlap 10.41.0.0/16, 10.42.0.0/16 or 10.43.0.0/16."
  }
}
