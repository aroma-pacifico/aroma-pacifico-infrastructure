# Farms (box D08, B08b). One call to the reference module per enrolled farm,
# pinned by SemVer tag (PC-IAC-015). Each farm gets the IoT things and
# certificates of its crop and drying nodes; the endpoint and the device policy
# come from the telemetry ingestion contract.
module "farm" {
  source   = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/farm?ref=v0.4.0"
  for_each = var.farms

  # The module consumes the aws.project alias (PC-IAC-005).
  providers = { aws.project = aws }

  client      = local.client
  project     = local.project
  environment = var.environment

  name_prefix     = "${local.name_prefix}-${each.key}"
  additional_tags = merge(local.common_tags, { CostCenter = "farms", FarmId = each.value.farm_id })

  farm_id   = each.value.farm_id
  nodes     = local.farm_nodes[each.key]
  ingestion = local.farm_ingestion
}
