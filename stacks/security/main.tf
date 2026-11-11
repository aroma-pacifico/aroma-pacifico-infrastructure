# Security domain (box D06, B06b). One call to the reference module, pinned by
# SemVer tag (PC-IAC-015). All security logic stays in the module; this stack
# supplies the per-environment values and the provider.
module "security" {
  source = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/security?ref=v0.5.0"

  # The module consumes the aws.project alias (PC-IAC-005).
  providers = { aws.project = aws }

  client          = local.client
  project         = local.project
  environment     = var.environment
  name_prefix     = local.name_prefix
  additional_tags = local.common_tags

  # ASM-270: the apply role of this stack must administer the keys, or the key
  # policy lock-out check refuses them.
  key_administrator_arns        = local.key_administrator_arns
  key_user_arns                 = local.key_user_arns
  break_glass_role_arn_patterns = local.break_glass_role_arn_patterns

  field_sms_configuration = var.field_sms_configuration
  protected_bucket_arns   = local.protected_bucket_arns
}
