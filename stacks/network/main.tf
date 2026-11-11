# Network domain (box D04, B04b). One call to the reference module, pinned by
# SemVer tag (PC-IAC-015). All network logic stays in the module; this stack
# supplies the per-environment values and the provider.
module "network" {
  source = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/network?ref=v0.3.0"

  # The module consumes the aws.project alias (PC-IAC-005).
  providers = { aws.project = aws }

  client          = local.client
  project         = local.project
  environment     = var.environment
  name_prefix     = local.name_prefix
  additional_tags = local.common_tags

  vpc_cidr_block = var.vpc_cidr_block
  subnets        = var.subnets

  collection_center_cidr_blocks                = local.collection_center_cidr_blocks
  collection_center_summary_cidr_block         = var.collection_center_summary_cidr_block
  collection_center_firewall_cidr_blocks       = local.collection_center_firewall_cidr_blocks
  collection_center_ground_station_cidr_blocks = local.collection_center_ground_station_cidr_blocks

  transit_gateway_id  = var.transit_gateway_id
  data_store_ports    = var.data_store_ports
  interface_endpoints = var.interface_endpoints
  organization_id     = var.organization_id
  flow_logs           = var.flow_logs
}

# Box D05 (B05): association of the pdn environment with exactly one collection
# center. The reusable logic lives in the public modules repository and is
# consumed by git tag (PC-IAC-015). The VPC comes straight from the network
# module above; no route, firewall rule or Transit Gateway is created here, and
# B07 consumes the routing references. The map has one key, so there is at most
# one association per run.
module "association" {
  source   = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/collection-center-association?ref=v0.4.0"
  for_each = var.center_association == null ? {} : { (var.center_association.collection_center_key) = var.center_association }

  providers = {
    aws.project = aws.principal
    aws.network = aws.network
  }

  client      = local.client
  project     = local.project
  environment = var.environment

  name_prefix     = "${local.name_prefix}-cc"
  additional_tags = local.common_tags

  center = {
    key        = each.key
    cidr_block = var.collection_centers[each.key].cidr_block
  }
  network = {
    environment                   = var.environment
    account_id                    = each.value.workload_account_id
    vpc_id                        = module.network.vpc_id
    vpc_cidr_block                = module.network.vpc_cidr_block
    transit_attachment_subnet_ids = module.network.transit_attachment_subnet_ids
  }
  hub = each.value.hub
}
