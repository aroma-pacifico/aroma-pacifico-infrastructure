# Minimal outputs for the stacks that build on security (PC-IAC-019 section 3.2):
# firewall rules (B07b), telemetry ingestion (B09b) and the function stack (B10).
# The IoT role outputs are added when the module tag that creates them is adopted.

output "cognito_group_names" {
  description = "Cognito group name of each role, keyed by role."
  value       = module.security.cognito_group_names
}

output "field_user_pool_arn" {
  description = "ARN of the field user pool (farmer, transporter, buyer), for API authorizers."
  value       = module.security.field_user_pool_arn
}

output "field_user_pool_id" {
  description = "ID of the field user pool."
  value       = module.security.field_user_pool_id
}

output "kms_key_arns" {
  description = "ARN of each customer-managed key, keyed by data class. B09b takes telemetry and logs, B10 and B13 take records, objects and logs, B07b takes logs for the web ACL log destination."
  value       = module.security.kms_key_arns
}

output "revocation_role_arn" {
  description = "ARN of the role of the revocation function, for the function that revokes device and user identities."
  value       = module.security.revocation_role_arn
}

output "revocation_role_name" {
  description = "Name of the revocation role, for attaching the basic execution policy of the function."
  value       = module.security.revocation_role_name
}

output "secure_transport_policy_statements_json" {
  description = "Bucket policy with the deny statements for plain HTTP and TLS below 1.2, or null when no bucket is protected. Each bucket owner merges it into its bucket policy."
  value       = module.security.secure_transport_policy_statements_json
}

output "staff_user_pool_arn" {
  description = "ARN of the staff user pool (MFA required), for API authorizers."
  value       = module.security.staff_user_pool_arn
}

output "staff_user_pool_id" {
  description = "ID of the staff user pool."
  value       = module.security.staff_user_pool_id
}
