# Box D05: association of the pdn environment with exactly one collection center.
# The reusable logic lives in the public modules repository and is consumed by
# git tag (PC-IAC-015); this root only injects the approved center, the B04
# network contract and the hub references. No route, firewall rule or Transit
# Gateway is created here: B07 consumes the routing references below.
module "association" {
  source = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/collection-center-association?ref=feat/25-center-association-module-squashed"

  providers = {
    aws.project = aws.principal
    aws.network = aws.network
  }

  client      = lower(var.common_tags.Client)
  project     = lower(var.common_tags.Project)
  environment = var.environment

  name_prefix     = local.association_name_prefix
  additional_tags = var.common_tags

  center = {
    key        = var.collection_center.key
    cidr_block = local.collection_centers[var.collection_center.key].cidr_block
  }
  network = var.network
  hub     = var.hub
}
