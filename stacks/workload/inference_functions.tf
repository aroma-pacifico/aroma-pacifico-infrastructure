# Inference functions (box D10, B10b). One call to the reference module, pinned
# by SemVer tag (PC-IAC-015). The event-driven pattern (queue, dead-letter
# queue, event source mapping, role per function, log group) stays in the
# module; this stack supplies the functions, the keys and the provider.
module "inference_functions" {
  source = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/inference-functions?ref=v0.4.0"

  # The module consumes the aws.project alias (PC-IAC-005).
  providers = { aws.project = aws }

  client          = local.client
  project         = local.project
  environment     = var.environment
  name_prefix     = local.name_prefix
  additional_tags = local.common_tags

  functions                = local.inference_functions
  kms_key_arns             = var.kms_key_arns
  permissions_boundary_arn = var.permissions_boundary_arn
  log_retention_days       = local.log_retention_days
}
