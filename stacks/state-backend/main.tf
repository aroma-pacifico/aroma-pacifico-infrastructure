# Remote state bucket and key of one environment (B02, box D02). The module is
# consumed by git tag (PC-IAC-015); never point this source at a branch or a path.
module "state_backend" {
  source = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/state-backend?ref=v0.3.0"

  providers = {
    aws.project = aws
  }

  client      = local.client
  project     = local.project
  environment = var.environment

  name_prefix     = local.name_prefix
  additional_tags = var.common_tags

  aws_context = {
    account_id = local.account_id
    partition  = local.partition
    region     = var.aws_region
  }

  key_administrators            = local.key_administrators
  configuration_readers         = local.configuration_readers
  break_glass_role_arn_patterns = local.break_glass_patterns
  domain_access                 = local.domain_access
}
