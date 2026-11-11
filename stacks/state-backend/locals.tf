locals {
  account_id      = data.aws_caller_identity.current.account_id
  partition       = "aws"
  role_arn_prefix = "arn:${local.partition}:iam::${local.account_id}:role/"

  # The module validates that the tags agree with these values and that the
  # name starts with client-project-environment-.
  client      = var.common_tags["Client"]
  project     = var.common_tags["Project"]
  name_prefix = "${local.client}-${local.project}-${var.environment}-state"

  key_administrators    = [for name in var.key_administrator_role_names : "${local.role_arn_prefix}${name}"]
  configuration_readers = [for name in var.configuration_reader_role_names : "${local.role_arn_prefix}${name}"]
  break_glass_patterns  = [for pattern in var.break_glass_role_patterns : "${local.role_arn_prefix}${pattern}"]

  domain_access = {
    for domain, access in var.domain_access : domain => {
      plan_role_arns  = [for name in access.plan_role_names : "${local.role_arn_prefix}${name}"]
      write_role_arns = [for name in access.write_role_names : "${local.role_arn_prefix}${name}"]
    }
  }
}
