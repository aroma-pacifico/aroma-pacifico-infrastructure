# Governance injection and derived values (AGENTS.md section 5.2). No resource
# is defined in this stack: the security module owns every resource.
locals {
  account_id      = data.aws_caller_identity.current.account_id
  partition       = "aws"
  role_arn_prefix = "arn:${local.partition}:iam::${local.account_id}:role/"

  # Tags passed to the module, aligned with the provider default_tags so that
  # the module and the provider never disagree on Environment.
  common_tags = merge(var.common_tags, { Environment = var.environment })

  # PC-IAC-003 naming inputs. The module caps name_prefix at 16 characters.
  client      = lower(var.common_tags["Client"])
  project     = lower(var.common_tags["Project"])
  name_prefix = "${local.client}-${local.project}-${var.environment}"

  # The module takes ARNs; the stack takes role names so that no account
  # identifier is stored in a variable file (PC-IAC-016).
  key_administrator_arns        = [for name in var.security_apply_role_names : "${local.role_arn_prefix}${name}"]
  break_glass_role_arn_patterns = [for pattern in var.break_glass_role_patterns : "${local.role_arn_prefix}${pattern}"]
  key_user_arns = {
    for class, names in var.key_user_role_names : class => [for name in names : "${local.role_arn_prefix}${name}"]
  }
  protected_bucket_arns = [for name in var.protected_bucket_names : "arn:${local.partition}:s3:::${name}"]
}
