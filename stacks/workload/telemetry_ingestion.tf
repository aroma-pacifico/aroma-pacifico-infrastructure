# Telemetry ingestion (box D09, B09b). One call to the pattern module, pinned by
# SemVer tag (PC-IAC-015): the IoT Core data endpoint with its TLS policy, the
# device policy, the topic rule, the telemetry table, the rule error queue and
# the IoT Core log group. The roles and keys come from stacks/security as
# variables; the threshold queue comes from the inference functions.
module "telemetry_ingestion" {
  source = "git::https://github.com/aroma-pacifico/aroma-pacifico-terraform-modules.git//modules/telemetry-ingestion?ref=v0.4.0"

  # The module consumes the aws.project alias (PC-IAC-005).
  providers = { aws.project = aws }

  client          = local.client
  project         = local.project
  environment     = var.environment
  name_prefix     = local.name_prefix
  additional_tags = local.common_tags

  # The module needs the telemetry and logs classes of the key map.
  kms_key_arns     = var.kms_key_arns
  rule_role_arn    = var.iot_rule_role_arn
  logging_role_arn = var.iot_logging_role_arn

  # The topic rule sends each reading to the threshold queue (ASM-161). The
  # inference functions take topic_rule_arn in return, which the module builds
  # from the rule name, so the two calls form no cycle.
  threshold_queue_url = module.inference_functions.queue_urls["thresh"]

  topic_namespace     = var.telemetry_topic_namespace
  tls_security_policy = var.telemetry_tls_security_policy
  retention_days      = local.telemetry_retention_days
  log_retention_days  = local.log_retention_days
}
