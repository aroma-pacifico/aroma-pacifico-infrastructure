# Governance injection and derived values (AGENTS.md section 5.2). No resource
# is defined in this stack: the network module owns every resource.
locals {
  # Tags passed to the module, aligned with the provider default_tags so that
  # the module and the provider never disagree on Environment.
  common_tags = merge(var.common_tags, { Environment = var.environment })

  # PC-IAC-003 naming inputs. The module caps name_prefix at 16 characters.
  client      = lower(var.common_tags["Client"])
  project     = lower(var.common_tags["Project"])
  name_prefix = "${local.client}-${local.project}-${var.environment}"

  # The module takes one map per center attribute; the stack takes one object per center.
  collection_center_cidr_blocks                = { for name, center in var.collection_centers : name => center.cidr_block }
  collection_center_firewall_cidr_blocks       = { for name, center in var.collection_centers : name => center.firewall_cidr_block }
  collection_center_ground_station_cidr_blocks = { for name, center in var.collection_centers : name => center.ground_station_cidr_block }

  # Case statement point 3: the cloud must not overlap these blocks.
  reserved_center_cidr_blocks = ["10.41.0.0/16", "10.42.0.0/16", "10.43.0.0/16"]

  # Terraform 1.15 has no CIDR overlap function, so each block is reduced to its
  # first and last address as integers; two blocks overlap when the ranges intersect.
  # The VPC range is computed inside the validation of vpc_cidr_block, because a
  # variable validation cannot depend on a local that reads the same variable.
  reserved_ranges = [
    for cidr_block in local.reserved_center_cidr_blocks : {
      first = sum([for index, octet in split(".", cidrhost(cidr_block, 0)) : tonumber(octet) * pow(256, 3 - index)])
      last  = sum([for index, octet in split(".", cidrhost(cidr_block, 0)) : tonumber(octet) * pow(256, 3 - index)]) + pow(2, 32 - tonumber(split("/", cidr_block)[1])) - 1
    }
  ]
}
